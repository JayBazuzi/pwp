$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Set-PSDebug -Trace 1
# Register-EngineEvent PowerShell.Exiting -Action { Set-PSDebug -Trace 0 } | Out-Null


$target = [System.IO.Path]::ChangeExtension($PSCommandPath, '.py')

# # TODO: find these
# PYTHON_VERSION="3.8" # Github actions ubuntu
# $pythonMajorMinorVersion = "310" # Windows on my laptop
# $python="$env:LocalAppData/Programs/Python/Python$pythonMajorMinorVersion/python.exe"
$python=(Get-Command python.exe).Source
if ( ! (Test-Path $python) ) { throw "$python not found" }

function CreateAndActivateVenv {
    $venvDirectory = @( New-TemporaryFile ) | ForEach-Object { Remove-Item $_ ; mkdir $_ }
    & $python -m venv $venvDirectory
    if (!$?) { throw "command failed"}
    . "$venvDirectory/Scripts/Activate.ps1"
    if (!$?) { throw "command failed"}
    $python = "$venvDirectory/Scripts/python.exe"
    if ( ! (Test-Path $python) ) { throw "$python not found" }
}

function InstallRequirements {
    $requirementsFile = New-TemporaryFile
    Select-String -AllMatches -CaseSensitive '^## PWP_REQUIRE: (.*)' $target |
        ForEach-Object { $_.Matches[0].Groups[1].Value } |
        Out-File $requirementsFile
    # "$python" -m pip upgrade pip --quiet
    & "$python" -m pip install  --quiet --requirement $requirementsFile
    if (!$?) { throw "command failed"}
}

function Cleanup
{
    $ErrorActionPreference = 'SilentlyContinue'
    deactivate
    Remove-Item $requirementsFile
    Remove-Item -Recurse $venvDirectory
}

CreateAndActivateVenv
try {
    InstallRequirements

    & "$python" $target "$@"
    if (!$?) { throw "command failed"}
}
finally {
    Cleanup
}
