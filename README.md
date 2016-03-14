# WindowsUpdates

A PowerShell Module for automated Windows Updates Management, which will offer:

   - Updates' retrieval
   - Updates' installation

# How to use WindowsUpdates

```powershell
Import-Module WindowsUpdates

$updates = Get-WindowsUpdate
if ($updates) {
    Install-WindowsUpdate $updates
    if (Get-RebootRequired) {
        Restart-Computer -Force
    }
}
```
# If you want to exclude KBIDs

```powershell
Import-Module WindowsUpdates

$updates = Get-WindowsUpdate -Verbose -ExcludeKBId @("KB2267602")
```

## Compatibility

The WindowsUpdates module is compatible with PowerShell v2 or newer and tested with Windows version >= 6.1(Windows 7/2008R2 or newer).

## How to run tests

You will need pester on your system. It should already be installed on your system if you are running Windows 10. If it is not:

```powershell
Install-Package Pester
```

Running the actual tests:

```powershell
powershell.exe -NonInteractive {Invoke-Pester}
```

This will run all tests without polluting your current shell environment. The -NonInteractive flag will make sure that any test that checks for mandatory parameters will not block the tests if run in an interactive session. This is not needed if you run this in a CI.

