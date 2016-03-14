# Copyright 2016 Cloudbase Solutions Srl
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
$ErrorActionPreference = "Stop"

$UPDATE_SESSION_COM_CLASS = "Microsoft.Update.Session"
$UPDATE_SYSTEM_INFO_COM_CLASS = "Microsoft.Update.SystemInfo"
$UPDATE_COLL_COM_CLASS = "Microsoft.Update.UpdateColl"
$SERVER_SELECTION_WINDOWS_UPDATE = 2
$UPDATE_DOWNLOAD_STATUS_CODES = @{
    0 = "NotStarted"
    1 = "InProgress"
    2 = "Downloaded"
    3 = "DownloadedWithErrors"
    4 = "Failed"
    5 = "Aborted"
}
$UPDATE_INSTALL_STATUS_CODES = @{
    0 = "NotStarted"
    1 = "InProgress"
    2 = "Installed"
    3 = "InstalledWithErrors"
    4 = "Failed"
    5 = "Aborted"
}

function Write-UpdateInformation {
    Param(
        [Parameter(Mandatory=$true)]
        $Updates
    )
    foreach ($update in $Updates) {
        Write-Host ("Update title: " + $update.Title)
        Write-Host ($update.Categories | Select-Object Name)
        Write-Host ("Update size: " + ([int]($update.MaxDownloadSize/1MB) + 1) + "MB")
        Write-Host ""
    }
}

function Get-UpdateSearcher {
    $updateSession = New-Object -ComObject $UPDATE_SESSION_COM_CLASS
    return $updateSession.CreateUpdateSearcher()
}

function Get-UpdateDownloader {
    $updateSession = New-Object -ComObject $UPDATE_SESSION_COM_CLASS
    return $updateSession.CreateUpdateDownloader()
}

function Get-LocalUpdates {
    Param(
        [Parameter(Mandatory=$true)]
        $UpdateSearcher,
        [Parameter(Mandatory=$true)]
        [string]$SearchCriteria
    )
    try {
        $updatesResult = $updateSearcher.Search($searchCriteria)
    } catch [Exception]{
        Write-Host "Failed to search for updates"
        throw
    }
    return $updatesResult
}

function Add-WindowsUpdateToCollection {
    Param(
        [Parameter(Mandatory=$true)]
        $Collection,
        [Parameter(Mandatory=$true)]
        $Update
    )

    $Collection.Add($Update) | Out-Null
}

function Get-WindowsUpdate {
    <#
    .SYNOPSIS
     Get-WindowsUpdate is a command that will return the applicable updates to
     the Windows operating system.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [array]$ExcludeKBId=@()
    )
    PROCESS {
        $updateSearcher = Get-UpdateSearcher
        # Set the update source server to Windows Update
        $updateSearcher.ServerSelection = $SERVER_SELECTION_WINDOWS_UPDATE
        # Set search criteria
        $searchCriteria = "( IsInstalled = 0 and IsHidden = 0)"
        $updateResult = Get-LocalUpdates -UpdateSearcher $updateSearcher `
            -SearchCriteria $searchCriteria
        if (!$updateResult -or !$updateResult.Updates) {
            return
        }
        $updates = $updateResult.Updates
        $filteredUpdates = New-Object -ComObject $UPDATE_COLL_COM_CLASS

        for ($i=0; $i -lt $updates.Count; $i++) {
            $update = $updates.Item($i)
            $updateKBId = ($update.KBArticleIDs -join ", KB")
            if ($ExcludeKBId -contains ("KB" + $updateKBId)) {
                Write-Verbose ("Exclude update KB{0}" `
                    -f @($updateKBId))
            } else {
                Add-WindowsUpdateToCollection $filteredUpdates $update
            }
        }

        return $filteredUpdates
    }
}

function Get-RegKeyRebootRequired {
    $basePath = "HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\"
    $cbsRebootRequired = Get-Item -Path "${basePath}Component Based Servicing\RebootPending" `
        -ErrorAction SilentlyContinue
    $auRebootRequired = Get-Item -Path "${basePath}\WindowsUpdate\Auto Update\RebootRequired" `
        -ErrorAction SilentlyContinue
    return ($cbsRebootRequired -and $auRebootRequired)
}

function Get-UpdateRebootRequired {
        $systemInfo = New-Object -ComObject $UPDATE_SYSTEM_INFO_COM_CLASS
        return $systemInfo.RebootRequired
}

function Get-RebootRequired {
    <#
    .SYNOPSIS
     Get-RebootRequired is a command that will return the reboot required status
     of a Windows machine. This status check is necessary in order to know
     whether to perform a machine restart in order to continue to install the
     Windows updates.
    #>
    return ((Get-UpdateRebootRequired) -or (Get-RegKeyRebootRequired))
}

function Install-WindowsUpdate {
    <#
    .SYNOPSIS
     Install-WindowsUpdate is a command that will install the updates given as
     a parameter on the Windows operating system.
     .Parameter Updates
     The required value can be obtained by running Get-WindowsUpdate
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true)]
        $Updates
    )
    PROCESS {
        foreach ($update in $Updates) {
            $updateSize = ([int]($update.MaxDownloadSize/1MB) + 1)
            Write-Host ("Installing Update: {0} ({1}MB)" -f @($update.Title, $updateSize))

            if ($update.EulaAccepted -eq 0) {
                Write-Host ("AcceptEula for Update: " + $update.Title)
                $update.AcceptEula()
            }

            $updateSession = New-Object -ComObject $UPDATE_SESSION_COM_CLASS
            $updateColl = New-Object -ComObject $UPDATE_COLL_COM_CLASS
            $updateColl.add($update) | Out-Null

            # DOWNLOAD UPDATE
            $updateDownloader = $updateSession.CreateUpdateDownloader()
            $updateDownloader.Updates = $updateColl
            $maxRetries = 5
            $retries = 0
            while ($retries -lt $maxRetries) {
                $downloadResult = $updateDownloader.Download()
                if ($downloadResult.ResultCode -ne 2) {
                    $retries++
                    Write-Host "Failed to download update. Reason: " + `
                        $UPDATE_DOWNLOAD_STATUS_CODES[$downloadResult.ResultCode]
                } else {
                    Write-Host "Update has been downloaded."
                    break
                }
            }
            if ($retries -eq $maxRetries) {
                write-host "$retries"
                throw "Failed to download update."
            }

            # INSTALL UPDATE
            $updateInstaller = $updateSession.CreateUpdateInstaller()
            $updateInstaller.Updates = $updateColl
            $maxRetries = 5
            $retries = 0
            while ($retries -lt $maxRetries) {
                $installResult = $updateInstaller.Install()
                if ($installResult.ResultCode -ne 2) {
                    $retries++
                    Write-Host "Failed to install update. Reason: " + `
                        $UPDATE_INSTALL_STATUS_CODES[$installResult.ResultCode]
                } else {
                    Write-Host "Update has been installed."
                    break
                }
            }
            if ($retries -eq $maxRetries) {
                write-host "$retries"
                throw "Failed to install update."
            }

            $updateColl.clear()
        }
    }
}

Export-ModuleMember -Function * -Alias *
