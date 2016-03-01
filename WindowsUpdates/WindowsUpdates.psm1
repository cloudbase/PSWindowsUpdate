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
$SERVER_SELECTION_WINDOWS_UPDATE = 2

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
    return $updatesResult.Updates
}

function Get-WindowsUpdate {
    <#
    .SYNOPSIS
     Get-WindowsUpdate is a command that will return the applicable updates to
     the Windows operating system.
    #>
    [CmdletBinding()]
    Param(
    )
    PROCESS {
        $updateSearcher = Get-UpdateSearcher
        # Set the update source server to Windows Update
        $updateSearcher.ServerSelection = $SERVER_SELECTION_WINDOWS_UPDATE
        # Set search criteria
        $searchCriteria = "( IsInstalled = 0 and IsHidden = 0)"
        $updates = Get-LocalUpdates -UpdateSearcher $updateSearcher `
            -SearchCriteria $searchCriteria
        return $updates
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

Export-ModuleMember -Function * -Alias *
