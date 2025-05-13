# Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber -Force
# Import-Module Microsoft.Graph.Beta
# Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "Directory.Read.All"

function Get-PrincipalInfo {
    param ($principalId)
    try {
        $user = Get-MgBetaUser -UserId $principalId -ErrorAction Stop
        return @{ Name = $user.UserPrincipalName; Type = "User" }
    } catch {
        try {
            $sp = Get-MgBetaServicePrincipal -ServicePrincipalId $principalId -ErrorAction Stop
            return @{ Name = $sp.AppDisplayName; Type = "Service Principal" }
        } catch {
            return @{ Name = "Unknown ($principalId)"; Type = "Unknown" }
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
        AccountType = $principal.Type
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
        AccountType = $principal.Type
        RoleName    = $role.DisplayName
        Assignment  = "Active"
        Scope       = $entry.ScopeId
    }
}

# Output
$combined | Sort-Object Principal, Assignment | Format-Table -AutoSize
