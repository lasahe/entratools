# Tools for managing Entra ID

## Get-PrivilegedEntraUsers.ps1
**Description:**
- List Privileged Entra users: Active, Eligible, and via Group Memberships. 
- Detects whether the account is a user or service principal
- Displays either the UserPrincipalName or AppDisplayName depending on the object type
- Fallback label: Tries to resolve the principal as a user first, then as a service principal. If neither is found, it shows "ServicePrincipal (\<GUID\>)" so you can investigate further.
### Setup
Install & Import required modules (PowerShell 7)
```
Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber -Force
Import-Module Microsoft.Graph.Beta
```
Connect to Graph with required scopes.
```
Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "Directory.Read.All"
```
Run
```
.\Get-PrivilegedEntraUsers.ps1 
```
