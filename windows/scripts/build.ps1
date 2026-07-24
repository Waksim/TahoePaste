param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root "src\TahoePaste.Windows\TahoePaste.Windows.csproj"
$CliProject = Join-Path $Root "src\TahoePaste.Cli\TahoePaste.Cli.csproj"

dotnet restore $Project -r win-x64
dotnet restore $CliProject -r win-x64
dotnet publish $Project -c $Configuration -r win-x64 --self-contained true
dotnet publish $CliProject -c $Configuration -r win-x64 --self-contained true

$Output = Join-Path $Root "src\TahoePaste.Windows\bin\$Configuration\net10.0-windows10.0.26100.0\win-x64\publish"
$CliOutput = Join-Path $Root "src\TahoePaste.Cli\bin\$Configuration\net10.0-windows10.0.26100.0\win-x64\publish"

if (Test-Path (Join-Path $CliOutput "tahoepaste-cli.exe")) {
    Copy-Item (Join-Path $CliOutput "tahoepaste-cli.exe") -Destination $Output -Force
}

Write-Host ""
Write-Host "TahoePaste Windows build:"
Write-Host "  $Output"
