# Tools for managing Entra ID

## Get-PrivilegedEntraUsers.ps1
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
