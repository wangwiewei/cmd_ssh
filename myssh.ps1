# myssh.ps1 - SSH Host Manager (PowerShell 5.1 + GBK/ANSI Compatible)
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"
$hostsFile = "$env:USERPROFILE\ssh_hosts.txt"

# Locate ssh.exe
$sshPath = "C:\Windows\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $sshPath)) {
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if ($sshCmd) {
        $sshPath = $sshCmd.Source
    } else {
        Write-Host "Error: OpenSSH client not found." -ForegroundColor Red
        exit 1
    }
}

# ==============================
# Case 1: Called with arguments �� direct connect + auto-save
# ==============================
if ($Args.Count -gt 0) {
    $cmd = ($Args -join " ").Trim()
    
    if ([string]::IsNullOrEmpty($cmd)) {
        Write-Host "Error: Empty command."
        exit 1
    }

    # Validate format
    if ($cmd -notlike "*@*") {
        Write-Host "Error: Invalid SSH format (missing '@')." -ForegroundColor Red
        exit 1
    }

    # Read existing hosts (use Default encoding = GBK on Chinese Windows)
    $existingHosts = @()
    if (Test-Path $hostsFile) {
        Get-Content $hostsFile -Encoding Default | ForEach-Object {
            $trimmed = $_.Trim()
            if ($trimmed -ne "") {
                $existingHosts += $trimmed
            }
        }
    }

    # Add if not exists (exact match, trimmed)
    if ($cmd -notin $existingHosts) {
        Add-Content -Path $hostsFile -Value $cmd -Encoding Default
        Write-Host "[+] Added new host: $cmd" -ForegroundColor Green
    }

    # Execute SSH
    & $sshPath @Args
    exit
}

# ==============================
# Case 2: Interactive mode
# ==============================
function Show-Menu {
    # Debug: Show hosts file path
    Write-Host "Debug: hostsFile = $hostsFile" -ForegroundColor Yellow
    
    # Create file if not exists (use Default encoding)
    if (-not (Test-Path $hostsFile)) {
        Set-Content -Path $hostsFile -Value "" -Encoding Default -Force | Out-Null
        Write-Host "Debug: Created new hosts file" -ForegroundColor Yellow
    } else {
        Write-Host "Debug: Hosts file exists" -ForegroundColor Yellow
    }

    # Load and trim hosts (use UTF8 encoding)
    $script:hosts = @()
    Get-Content $hostsFile -Encoding UTF8 | ForEach-Object {
        $trimmed = $_.Trim()
        if ($trimmed -ne "") {
            $script:hosts += $trimmed
        }
    }
    
    # Debug: Show hosts array content
    Write-Host "Debug: Hosts count = $($script:hosts.Count)" -ForegroundColor Yellow
    for ($i = 0; $i -lt $script:hosts.Count; $i++) {
        Write-Host "Debug: Host $($i+1) = '$($script:hosts[$i])'" -ForegroundColor Yellow
    }
    
    Clear-Host
    Write-Host "=== SSH Host Manager ===" -ForegroundColor Cyan
    Write-Host ""


    Write-Host "=== SSH Host List ===" -ForegroundColor Cyan
    Write-Host ""

    if ($script:hosts.Count -eq 0) {
        Write-Host "No hosts found."
    } else {
        for ($i = 0; $i -lt $script:hosts.Count; $i++) {
            Write-Host "$($i + 1). $($script:hosts[$i])"
        }
    }

    Write-Host ""
    Write-Host "Enter number to connect, 'n' to add, 'd' to delete, 'q' to quit."
}

# Main interactive loop
do {
    Show-Menu
    $choice = Read-Host "Your choice"

    switch ($choice) {
        'q' {
            exit
        }

        'n' {
            $new = (Read-Host "Enter new connection (e.g.: user@host -p port)").Trim()
            if ([string]::IsNullOrEmpty($new)) {
                continue
            }

            if ($new -notlike "*@*") {
                Write-Host "Error: Invalid format (missing '@')." -ForegroundColor Red
                Read-Host "Press Enter to continue..."
                continue
            }

            if ($new -notin $script:hosts) {
                Add-Content -Path $hostsFile -Value $new -Encoding Default
                Write-Host "[+] Added: $new" -ForegroundColor Green
                # Reload hosts
                $script:hosts = @()
                Get-Content $hostsFile -Encoding Default | ForEach-Object {
                    $trimmed = $_.Trim()
                    if ($trimmed -ne "") {
                        $script:hosts += $trimmed
                    }
                }
            } else {
                Write-Host "[i] Record already exists." -ForegroundColor Yellow
            }

            & $sshPath $new
            exit
        }

        'd' {
            if ($script:hosts.Count -eq 0) {
                Write-Host "No hosts to delete."
                Read-Host "Press Enter to continue..."
                continue
            }

            $delNumStr = Read-Host "Enter the number to delete"
            if (-not ($delNumStr -match "^\d+$")) {
                Write-Host "Error: Please enter a valid number." -ForegroundColor Red
                Read-Host "Press Enter to continue..."
                continue
            }

            $delNum = [int]$delNumStr
            if ($delNum -le 0 -or $delNum -gt $script:hosts.Count) {
                Write-Host "Error: Number out of range (1-$($script:hosts.Count))." -ForegroundColor Red
                Read-Host "Press Enter to continue..."
                continue
            }

            #  Accurate deletion by index
            $index = $delNum - 1
            $deletedHost = $script:hosts[$index]
            $newHosts = @()
            if ($index -gt 0) { 
                $newHosts += $script:hosts[0..($index - 1)] 
            }
            if ($index -lt $script:hosts.Count - 1) { 
                $newHosts += $script:hosts[($index + 1)..($script:hosts.Count - 1)] 
            }

            $newHosts | Set-Content $hostsFile -Encoding Default
            Write-Host "[-] Deleted record #${delNum}: $deletedHost" -ForegroundColor Magenta
            Read-Host "Press Enter to continue..."
        }

        default {
            # Try as number
            if ($choice -match "^\d+$") {
                $num = [int]$choice
                if ($num -ge 1 -and $num -le $script:hosts.Count) {
                    $target = $script:hosts[$num - 1]
                    Write-Host "Connecting to: $target" -ForegroundColor Cyan
                    & $sshPath $target
                    exit
                } else {
                    Write-Host "Error: Number out of range." -ForegroundColor Red
                    Read-Host "Press Enter to continue..."
                }
            } else {
                Write-Host "Error: Invalid input." -ForegroundColor Red
                Read-Host "Press Enter to continue..."
            }
        }
    }

} while ($true)