param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root "src\TahoePaste.Windows\TahoePaste.Windows.csproj"

dotnet restore $Project -r win-x64
dotnet publish $Project -c $Configuration -r win-x64 --self-contained true

$Output = Join-Path $Root "src\TahoePaste.Windows\bin\$Configuration\net10.0-windows10.0.26100.0\win-x64\publish"
Write-Host ""
Write-Host "TahoePaste Windows build:"
Write-Host "  $Output"
