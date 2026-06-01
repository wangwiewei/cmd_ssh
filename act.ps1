function act {
    $venvPath = ".venv"
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"

    if (Test-Path $activateScript) {
        Write-Host "🚀 Activating virtual environment in $PWD..." -ForegroundColor Green
        & $activateScript
    } elseif (Test-Path ".venv") {
        Write-Host "❌ Found .venv but no activation script. Try running 'uv venv' again." -ForegroundColor Yellow
    } else {
        Write-Host "❌ No .venv found in current directory ($PWD)." -ForegroundColor Red
        Write-Host "   Run 'uv venv' first to create one." -ForegroundColor Yellow
    }
}

# 顺便加个停用命令（可选）
function deact {
    deactivate
}