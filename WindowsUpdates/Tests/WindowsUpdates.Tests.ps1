$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleHome = Split-Path -Parent $here
$moduleRoot = Split-Path -Parent $moduleHome

$modulePath = ${env:PSModulePath}.Split(";")
if(!($moduleRoot -in $modulePath)){
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

Describe "Test Dummy" {
    AfterEach {
        Clear-Environment
    }
    It "Should equal $false" {
        $false | Should Be $false
    }
}
