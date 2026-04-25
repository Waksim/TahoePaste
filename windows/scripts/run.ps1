$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root "src\TahoePaste.Windows\TahoePaste.Windows.csproj"

dotnet run --project $Project -c Debug -r win-x64
