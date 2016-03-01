# WindowsUpdates

A PowerShell Module for automated Windows Updates Management, which will offer:

   - Updates' retrieval
   - Updates' installation

# How to use WindowsUpdates

```powershell
Import-Module WindowsUpdates
Get-WindowsUpdate | Install-WindowsUpdate
if (Get-RebootRequired) {
    Restart-Computer -Force
}
```

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

