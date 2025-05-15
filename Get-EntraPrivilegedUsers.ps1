# Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "Directory.Read.All"

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
foreach ($entry in $eligibleRoles) {
    $principal = Get-PrincipalInfo $entry.PrincipalId
    $role = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $entry.RoleDefinitionId
    $combined += [PSCustomObject]@{
        Principal   = $principal.Name
        ObjectType  = $principal.Type
        Id          = $principal.Id
        RoleName    = $role.DisplayName
        Assignment  = "Eligible"
        Scope       = $entry.ScopeId
    }
}

# Active roles
$activeRoles = Get-MgBetaRoleManagementDirectoryRoleAssignmentScheduleInstance -All
foreach ($entry in $activeRoles) {
    $principal = Get-PrincipalInfo $entry.PrincipalId
    $role = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $entry.RoleDefinitionId
    $combined += [PSCustomObject]@{
        Principal   = $principal.Name
        ObjectType  = $principal.Type
        Id          = $principal.Id
        RoleName    = $role.DisplayName
        Assignment  = "Active"
        Scope       = $entry.ScopeId
    }
}

# Output
$combined | Sort-Object Principal, Assignment | Format-Table -AutoSize
