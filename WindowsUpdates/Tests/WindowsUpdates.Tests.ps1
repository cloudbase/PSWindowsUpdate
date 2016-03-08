$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleHome = Split-Path -Parent $here
$moduleRoot = Split-Path -Parent $moduleHome

$modulePath = ${env:PSModulePath}.Split(";")
if (!($moduleRoot -in $modulePath)){
    $env:PSModulePath += ";$moduleRoot"
}
$savedEnv = [System.Environment]::GetEnvironmentVariables()

function Clear-Environment {
    $current = [System.Environment]::GetEnvironmentVariables()
    foreach($i in $savedEnv.GetEnumerator()) {
        [System.Environment]::SetEnvironmentVariable($i.Name, $i.Value, "Process")
    }
    $current = [System.Environment]::GetEnvironmentVariables()
    foreach ($i in $current.GetEnumerator()){
        if(!$savedEnv[$i.Name]){
            [System.Environment]::SetEnvironmentVariable($i.Name, $null, "Process")
        }
    }
}

function Compare-Objects ($first, $last) {
    (Compare-Object $first $last -SyncWindow 0).Length -eq 0
}

function Compare-ScriptBlocks {
    Param(
        [System.Management.Automation.ScriptBlock]$scrBlock1,
        [System.Management.Automation.ScriptBlock]$scrBlock2
    )

    $sb1 = $scrBlock1.ToString()
    $sb2 = $scrBlock2.ToString()

    return ($sb1.CompareTo($sb2) -eq 0)
}

function Add-FakeObjProperty ([ref]$obj, $name, $value) {
    Add-Member -InputObject $obj.value -MemberType NoteProperty `
        -Name $name -Value $value
}

function Add-FakeObjProperties ([ref]$obj, $fakeProperties, $value) {
    foreach ($prop in $fakeProperties) {
        Add-Member -InputObject $obj.value -MemberType NoteProperty `
            -Name $prop -Value $value
    }
}

function Add-FakeObjMethod ([ref]$obj, $name) {
    Add-Member -InputObject $obj.value -MemberType ScriptMethod `
        -Name $name -Value { return 0 }
}

function Add-FakeObjMethods ([ref]$obj, $fakeMethods) {
    foreach ($method in $fakeMethods) {
        Add-Member -InputObject $obj.value -MemberType ScriptMethod `
            -Name $method -Value { return 0 }
    }
}

function Compare-Arrays ($arr1, $arr2) {
    return (((Compare-Object $arr1 $arr2).InputObject).Length -eq 0)
}

function Compare-HashTables ($tab1, $tab2) {
    if ($tab1.Count -ne $tab2.Count) {
        return $false
    }
    foreach ($i in $tab1.Keys) {
        if (($tab2.ContainsKey($i) -eq $false) -or ($tab1[$i] -ne $tab2[$i])) {
            return $false
        }
    }
    return $true
}

Import-Module WindowsUpdates

Describe "Test Get-WindowsUpdate" {
    AfterEach {
        Clear-Environment
    }

    Mock Get-UpdateSearcher -Verifiable -ModuleName WindowsUpdates `
        {
            $updateSearcherMock = New-Object -TypeName PSObject
            Add-Member -InputObject ([ref]$updateSearcherMock).value `
                -MemberType NoteProperty -Name "ServerSelection" -Value -1
            return $updateSearcherMock
        }

    Mock Get-LocalUpdates -Verifiable -ModuleName WindowsUpdates `
        {
            return @{
                "Updates"=@("update");
                "Count"=1
            }
        }

    Mock Add-WindowsUpdateToCollection -Verifiable -ModuleName WindowsUpdates `
        {
            return @{
                "Updates"=@("update");
                "Count"=1
            }
        }

    It "Should return fake updates" {
        Compare-HashTables (Get-WindowsUpdate) @{
                "Updates"=@("update");
                "Count"=1
            } | Should Be $true
    }
}

Describe "Test Get-RebootRequired" {
    AfterEach {
        Clear-Environment
    }

    Context "On reboot true" {
        Mock Get-UpdateRebootRequired -Verifiable -ModuleName WindowsUpdates `
            { return $true }
        Mock Get-RegKeyRebootRequired -Verifiable -ModuleName WindowsUpdates `
            { return $true }

        $rebootStatus = Get-RebootRequired
        It "Should return true" {
            $rebootStatus | Should Be $true
        }
        It "Should verify all methods" {
            Assert-MockCalled Get-UpdateRebootRequired -Exactly 1 `
                -ModuleName WindowsUpdates
            Assert-MockCalled Get-RegKeyRebootRequired -Exactly 0 `
                -ModuleName WindowsUpdates
        }
    }

    Context "On reboot false" {
        Mock Get-UpdateRebootRequired -Verifiable -ModuleName WindowsUpdates `
            { return $false }
        Mock Get-RegKeyRebootRequired -Verifiable -ModuleName WindowsUpdates `
            { return $false }

        $rebootStatus = Get-RebootRequired
        It "Should return false" {
            $rebootStatus | Should Be $false
        }
        It "Should verify all methods" {
            Assert-MockCalled Get-UpdateRebootRequired -Exactly 1 `
                -ModuleName WindowsUpdates
            Assert-MockCalled Get-RegKeyRebootRequired -Exactly 1 `
                -ModuleName WindowsUpdates
        }
    }
}