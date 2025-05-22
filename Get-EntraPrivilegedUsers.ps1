# Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "Directory.Read.All"
Write-Host "Investigating Privileged Identities..."

function Get-PrincipalInfo {
    param ($principalId)
    try {
        $user = Get-MgBetaUser -UserId $principalId -ErrorAction Stop
        return @{ Name = $user.UserPrincipalName; Type = "User"; Id = $user.Id }
    } catch {
        try {
            $sp = Get-MgBetaServicePrincipal -ServicePrincipalId $principalId -ErrorAction Stop
            $name = if ($sp.AppDisplayName) {
                $sp.AppDisplayName
            } elseif ($sp.AppId) {
                "ServicePrincipal ($($sp.AppId))"
            } else {
                "ServicePrincipal ($($sp.Id))"
            }
            return @{ Name = $name; Type = "Service Principal"; Id = $sp.Id }
        } catch {
            try {
                $group = Get-MgBetaGroup -GroupId $principalId -ErrorAction Stop
                return @{ Name = $group.DisplayName; Type = "Group"; Id = $group.Id }
            } catch {
                return @{ Name = "Unknown ($principalId)"; Type = "Unknown"; Id = $principalId }
            }
        }
    }
}

$combined = @()

# Eligible roles
$eligibleRoles = Get-MgBetaRoleManagementDirectoryRoleEligibilityScheduleInstance -All
Write-Host "Processing Eligible Roles..."
foreach ($entry in $eligibleRoles) {
    $principal = Get-PrincipalInfo $entry.PrincipalId
    $role = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $entry.RoleDefinitionId
    $combined += [PSCustomObject]@{
        PrincipalName   = $principal.Name
        ObjectType  = $principal.Type
        Id          = $principal.Id
        RoleName    = $role.DisplayName
        Assignment  = "Eligible"
        Scope       = $entry.ScopeId
    }
}

# Active roles
$activeRoles = Get-MgBetaRoleManagementDirectoryRoleAssignmentScheduleInstance -All
Write-Host "Processing Active Roles..."
foreach ($entry in $activeRoles) {
    $principal = Get-PrincipalInfo $entry.PrincipalId
    $role = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $entry.RoleDefinitionId
    $combined += [PSCustomObject]@{
        PrincipalName   = $principal.Name
        ObjectType  = $principal.Type
        Id          = $principal.Id
        RoleName    = $role.DisplayName
        Assignment  = "Active"
        Scope       = $entry.ScopeId
    }
}

# Expand group members
Write-Host "Processing Group Memberships..."
$expanded = @()
foreach ($entry in $combined) {
    if ($entry.ObjectType -eq "Group") {
        try {
            $members = Get-MgBetaGroupMember -GroupId $entry.Id -All
            $groupMemberUPNs = @()
            foreach ($member in $members) {
                $memberType = $member.AdditionalProperties.'@odata.type'
                $memberId = $member.Id
                $userPrincipalName = $null
                $memberName = $null
                $type = "Unknown"
                if ($memberType -eq "#microsoft.graph.user") {
                    $memberName = $member.DisplayName
                    $userPrincipalName = $member.UserPrincipalName
                    $type = "User"
                } elseif ($memberType -eq "#microsoft.graph.servicePrincipal") {
                    $memberName = $member.DisplayName
                    $type = "Service Principal"
                } elseif ($memberType -eq "#microsoft.graph.group") {
                    $memberName = $member.DisplayName
                    $type = "Group"
                }
                # If memberName is still null, resolve it using Get-PrincipalInfo
                if (-not $memberName) {
                    $info = Get-PrincipalInfo $memberId
                    $memberName = $info.Name
                    if ($type -eq "Unknown") { $type = $info.Type }
                    if ($type -eq "User" -and -not $userPrincipalName) { $userPrincipalName = $info.Name }
                }
                # Only add UPNs for users
                if ($userPrincipalName) {
                    $groupMemberUPNs += $userPrincipalName
                }
                $expanded += [PSCustomObject]@{
                    PrincipalName      = $memberName
                    UserPrincipalName  = $userPrincipalName
                    ObjectType         = $type
                    Id                 = $memberId
                    RoleName           = $entry.RoleName
                    Assignment         = $entry.Assignment
                    GroupSource        = $entry.PrincipalName
                    GroupMembers       = $null
                }
            }
            # Add the group itself with its members' UPNs listed in GroupMembers column
            $expanded += [PSCustomObject]@{
                PrincipalName      = $entry.PrincipalName
                UserPrincipalName  = $null
                ObjectType         = $entry.ObjectType
                Id                 = $entry.Id
                RoleName           = $entry.RoleName
                Assignment         = $entry.Assignment
                GroupSource        = $null
                GroupMembers       = ($groupMemberUPNs -join ", ")
            }
        } catch {
            # If group members can't be retrieved, keep the group entry as is
            $expanded += [PSCustomObject]@{
                PrincipalName      = $entry.PrincipalName
                UserPrincipalName  = $null
                ObjectType         = $entry.ObjectType
                Id                 = $entry.Id
                RoleName           = $entry.RoleName
                Assignment         = $entry.Assignment
                GroupSource        = $null
                GroupMembers       = $null
            }
        }
    } else {
        $expanded += [PSCustomObject]@{
            PrincipalName      = $entry.PrincipalName
            UserPrincipalName  = $null
            ObjectType         = $entry.ObjectType
            Id                 = $entry.Id
            RoleName           = $entry.RoleName
            Assignment         = $entry.Assignment
            GroupSource        = $entry.GroupSource
            GroupMembers       = $null
        }
    }
}

# Output
$reportPath = ".\PrivilegedEntraUsers.csv"
$reportBase = [System.IO.Path]::GetFileNameWithoutExtension($reportPath)
$reportExt = [System.IO.Path]::GetExtension($reportPath)
$counter = 1

while (Test-Path $reportPath -PathType Leaf) {
    try {
        $stream = [System.IO.File]::Open($reportPath, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        break
    } catch {
        $reportPath = ".\${reportBase}_$counter$reportExt"
        $counter++
    }
}

$expanded | Sort-Object PrincipalName, Assignment | Format-Table PrincipalName,ObjectType,Id,RoleName,Assignment,GroupSource,GroupMembers -AutoSize
$expanded | Sort-Object PrincipalName, Assignment | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8

Write-Host "INVESTIGATION COMPLETED!"
Write-Host "Report generated: $reportPath"
