$originalPrompt = (Get-Command prompt -ErrorAction SilentlyContinue).ScriptBlock

function Global:prompt {
    if ($env:TERM_PROGRAM -eq "WezTerm") {
        $cwd = (Get-Location).Path -replace "\\", "/"
        $esc = [char]27
        Write-Host "$esc]7;file:///$cwd`a" -NoNewline
    }

    if ($originalPrompt) {
        & $originalPrompt
    } else {
        "PS $($executionContext.SessionState.Path.CurrentLocation)> "
    }
}
