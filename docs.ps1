[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Action = "build"
)

$ErrorActionPreference = 'Stop'

# Go to the directory containing this script
Set-Location -Path $PSScriptRoot

# Configuration
$Python = if ($env:PYTHON) { $env:PYTHON } else { "python" }

switch ($Action.ToLower()) {
    "install" {
        Write-Host "==> Installing/updating dependencies..."
        & $Python -m pip install -r requirements.txt
        Write-Host "==> Done."
    }

    "build" {
        Write-Host "==> Building MkDocs..."
        & $Python -m pip install -r requirements.txt
        & $Python -m mkdocs build

        Write-Host ""
        Write-Host "==> Build successful!"
        Write-Host "Generated site: ./site/"
    }

    "serve" {
        Write-Host "==> Installing/updating dependencies..."
        & $Python -m pip install -r requirements.txt

        Write-Host "==> Starting MkDocs preview..."
        Write-Host "Open http://127.0.0.1:8000 in your browser."
        Write-Host "Press Ctrl+C to stop."

        & $Python -m mkdocs serve --dev-addr=127.0.0.1:8000
    }

    "clean" {
        Write-Host "==> Removing generated site..."
        if (Test-Path -Path "site") {
            Remove-Item -Path "site" -Recurse -Force
        }
        Write-Host "==> Done."
    }

    default {
        Write-Host "Usage:"
        Write-Host "  .\docs.ps1 install    Install dependencies"
        Write-Host "  .\docs.ps1 build      Build and check documentation"
        Write-Host "  .\docs.ps1 serve      Start local preview server"
        Write-Host "  .\docs.ps1 clean      Remove generated site"
        exit 1
    }
}