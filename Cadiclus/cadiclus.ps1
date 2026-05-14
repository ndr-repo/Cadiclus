$banner = @"

▄████████    ▄████████ ████████▄   ▄█   ▄████████  ▄█       ███    █▄     ▄████████
███    ███   ███    ███ ███   ▀███ ███  ███    ███ ███       ███    ███   ███    ███
███    █▀    ███    ███ ███    ███ ███▌ ███    █▀  ███       ███    ███   ███    █▀
███          ███    ███ ███    ███ ███▌ ███        ███       ███    ███   ███
███        ▀███████████ ███    ███ ███▌ ███        ███       ███    ███ ▀███████████
███    █▄    ███    ███ ███    ███ ███  ███    █▄  ███       ███    ███          ███
███    ███   ███    ███ ███   ▄███ ███  ███    ███ ███▌    ▄ ███    ███    ▄█    ███
████████▀    ███    █▀  ████████▀  █▀   ████████▀  █████▄▄██ ████████▀   ▄████████▀

                                     Version 1.5
                                     Created by: TJ Null
                                     Updated by: Gabriel H. @weekndr_sec

"@

# Print the ASCII banner
Write-Output $banner

# Function to display help if requested by the user
function Show-Help {
    $helpText = @"
General Guidelines:

A PowerShell Script that searches for possible paths to escalate privileges on Linux/Unix/MacOS hosts using PowerShell for Linux.

Available Command Options:
- Run-All
- Get-OSInfo
- Check-ADJoinStatus
- Get-Drives
- Get-NetworkActivity
- Test-Breakout
- Get-LinuxServices
- Get-LoggedInUsers
- Check-AVInstalled
- Check-CredentialManagerInstalled
- Search-PS1Files
- Search-AWSCredentials
- Search-AzureCredentials
- Review-UserHistory
- Get-PSHistory
- Search-PSHistory
- Check-Programs
- Invoke-CredentialHunting (Standalone)

Running Cadiclus:

Show me everything:
./cadiclus.ps1 Run-All
Show me certain information by running multiple commands:
./cadiclus.ps1 Get-OSInfo Get-Drives Check-AVInstalled
Search for credential patterns in files:
./cadiclus.ps1 Invoke-CredentialHunting "/dir/to/crawl"

New Functions:
- Get-PSHistory
- Search-PSHistory

"@
    Write-Output $helpText
}

function Run-All {
    Write-Output "`n[+] Running all functions..."

    Get-OSInfo
    Check-ADJoinStatus
    Get-Drives
    Get-NetworkActivity
    Test-Breakout
    Get-LinuxServices 
    Get-LoggedInUsers
    Check-AVInstalled
    Check-CredentialManagerInstalled
    Search-AWSCredentials
    Search-AzureCredentials
    Review-UserHistory
    Get-PSHistory
    Check-Programs

    Write-Output "`n[+] All functions executed."
}

# Define the function to get OS information and kernel version
function Get-OSInfo {
    $osInfo = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    $osReleaseContent = Get-Content /etc/os-release
    $osRelease = @{ }
    foreach ($line in $osReleaseContent) {
        if ($line -match '^(.+?)=(.+)$') {
            $key = $matches[1]
            $value = $matches[2].Trim('"')
            $osRelease[$key] = $value
        }
    }

    Write-Output "`n[+] Operating System Kernel Version:"
    Write-Output $osInfo
    Write-Output "`n[+] OS Release Information:"
    foreach ($key in $osRelease.Keys) {
        Write-Output "$key = $($osRelease[$key])"
    }
}

# Define the function to check if the system is joined to a domain controller
function Check-ADJoinStatus {
    Write-Output "`n[+] Checking if the system is joined to an Active Directory domain..."

    if (Test-Path "$(which realm)") {
        $adStatus = realm list | Select-String -Pattern 'domain-name'

        if ($adStatus) {
            Write-Output "The system is joined to an Active Directory domain."
        } else {
            Write-Output "The system is not joined to an Active Directory domain."
        }
    } else {
        Write-Output "The 'realm' command is not installed on this system."
    }
}

# Define the function to check for local and network drives
function Get-Drives {
    $drives = Get-PSDrive
    Write-Output "`n[+] List of Local and Network Drives:"
    $drives | Format-Table -AutoSize Name, @{Label="Provider";Expression={$_.Provider}}, Root, 
        @{Label="Used (GB)";Expression={[math]::round($_.Used/1GB,2)}}, 
        @{Label="Free (GB)";Expression={[math]::round($_.Free/1GB,2)}}
}

# Define the function to check for current network connections
function Get-NetworkActivity {
    Write-Output "`n[+] Grabbing current network connections..."
    $networkActivity = ss -ntlp | ForEach-Object {
        $columns = $_ -split '\s+'
        if ($columns.Count -ge 6) {
            [PSCustomObject]@{
                "Proto" = $columns[0]
                "Recv-Q" = $columns[1]
                "Send-Q" = $columns[2]
                "Local Address" = $columns[3]
                "Foreign Address" = $columns[4]
                "State" = $columns[5]
            }
        }
    } | Format-Table -AutoSize
    Write-Output $networkActivity

    Write-Output "`n[+] Grabbing current routing information..."
    $routeNetworkActivity = route -n | Select-String -Pattern '(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)' | ForEach-Object {
        $matches = $_.Matches[0].Groups
        [PSCustomObject]@{
            "Destination" = $matches[1].Value
            "Gateway" = $matches[2].Value
            "Genmask" = $matches[3].Value
            "Flags" = $matches[4].Value
            "Metric" = $matches[5].Value
            "Ref" = $matches[6].Value
            "Use" = $matches[7].Value
            "Iface" = $matches[8].Value
        }
    } | Format-Table -AutoSize
    Write-Output $routeNetworkActivity
}

# Define the function to check if we can escape our shell in PowerShell.
function Test-Breakout {
    param (
        [string[]]$Shells = @('bash', 'sh', 'zsh') # List of shells to test
    )

    Write-Output "[+] Testing breakout to alternative shells..."
    $breakoutResults = @()

    foreach ($shell in $Shells) {
        Write-Output "[+] Checking for $shell..."

        # Check if the shell exists in the system PATH
        if (Get-Command $shell -ErrorAction SilentlyContinue) {
            Write-Output "$shell found. Attempting to spawn $shell in a subshell..."

            try {
                # Spawn the shell as a subshell using a new process
                Start-Process -FilePath $shell -ArgumentList "-c", "'exit'" -NoNewWindow -Wait
                Write-Output "Successfully spawned and exited $shell."
                $breakoutResults += [PSCustomObject]@{
                    Shell   = $shell
                    Status  = "Success"
                }
            } catch {
                Write-Warning "Failed to spawn $shell."
                $breakoutResults += [PSCustomObject]@{
                    Shell   = $shell
                    Status  = "Failed"
                }
            }
        } else {
            Write-Warning "$shell not found in PATH."
            $breakoutResults += [PSCustomObject]@{
                Shell   = $shell
                Status  = "Not Found"
            }
        }
    }

    Write-Output "[+] Breakout testing completed. Results:"
    $breakoutResults | Format-Table -AutoSize
}

# Define the function to get a list of running services
function Get-LinuxServices {
    [CmdletBinding()]
    param ()

    Write-Output "[+] Gathering a list of running services on the Linux system..."

    $services = @()

    try {
        # Check if the system uses systemd (common in modern Linux distributions)
        if (Test-Path "/etc/systemd/system/") {
            Write-Output "[+] Systemd detected. Gathering service information..."
            # Read service files from the systemd folder
            $serviceFiles = Get-ChildItem -Path "/etc/systemd/system/" -Recurse -Filter "*.service" -ErrorAction SilentlyContinue
            foreach ($file in $serviceFiles) {
                # Extract service details
                $serviceName = $file.Name
                $servicePath = $file.FullName
                $status = if (Test-Path "/var/run/${serviceName}") { "Running" } else { "Stopped" }

                $services += [PSCustomObject]@{
                    Name   = $serviceName
                    Path   = $servicePath
                    Status = $status
                }
            }
        } elseif (Test-Path "/etc/init.d/") {
            Write-Output "[+] SysVinit detected. Gathering service information..."
            # Read service files from init.d
            $initFiles = Get-ChildItem -Path "/etc/init.d/" -ErrorAction SilentlyContinue
            foreach ($file in $initFiles) {
                # Extract service details
                $serviceName = $file.Name
                $servicePath = $file.FullName
                $status = if (Test-Path "/var/run/${serviceName}") { "Running" } else { "Stopped" }

                $services += [PSCustomObject]@{
                    Name   = $serviceName
                    Path   = $servicePath
                    Status = $status
                }
            }
        } else {
            Write-Warning "No recognizable service management system found."
        }

        if ($services.Count -gt 0) {
            Write-Output "[+] Services retrieved successfully. Displaying results:"
            $services | Format-Table -AutoSize
        } else {
            Write-Output "[+] No services found on the system."
        }
    } catch {
        Write-Warning "An error occurred while retrieving services: $_"
    }
}


# Define the function to check for currently logged-in users
function Get-LoggedInUsers {
    $loggedInUsers = who
    Write-Output "`n[+] Currently Logged-In Users:"
    Write-Output $loggedInUsers
}

# Define the function to check if Antivirus is currently installed
function Check-AVInstalled {
    $avPackages = "clamav", "clamav-daemon", "clamtk", "trellix", "wazuh", "mdatp", "mdatp-*"
    $installedPackages = dpkg-query -W -f='${Package}\n'
    $avInstalled = $avPackages | ForEach-Object { $installedPackages -contains $_ }
    if ($avInstalled -contains $true) {
        Write-Output "`n[+] Antivirus software is installed on the system."
    } else {
        Write-Output "`n[+] Antivirus software is not installed on the system."
    }
}

function Check-CredentialManagerInstalled {
    $credentialManagers = "gnome-keyring", "kwalletmanager", "pass", "seahorse"
    $installed = $credentialManagers | ForEach-Object { which $_ }
    $installedManagers = $installed -ne $null
    if ($installedManagers) {
        Write-Output "`n[+] Credential management tools are installed on the system."
    } else {
        Write-Output "`n[+] Credential management tools are not installed on the system."
    }
}

# Function to search for .ps1 files on the target
function Search-PS1Files {
    Write-Output "Searching for .ps1 files in all directories..."

    $ErrorActionPreference = 'SilentlyContinue'

    $ps1Files = Get-ChildItem -Path / -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue

    $searchResults = @()

    if ($ps1Files) {
        $totalFiles = $ps1Files.Count

        # Display progress bar
        Write-Progress -Activity "Searching .ps1 files" -Status "Progress:" -PercentComplete 0 -SecondsRemaining -1

        foreach ($file in $ps1Files) {
            # Process each .ps1 file
            $searchResults += $file.FullName
        }

        Write-Progress -Activity "Searching .ps1 files" -Status "Complete" -PercentComplete 100
    } else {
        Write-Output "No .ps1 files found."
    }

    $ErrorActionPreference = 'Continue'

    # Output the search results
    $searchResults
}

function Search-AWSCredentials {
    Write-Output "`n[+] Searching for AWS credentials on the system..."

    $ErrorActionPreference = 'SilentlyContinue'

    # Common paths where AWS credentials might be stored
    $pathsToSearch = @(
        "$HOME/.aws/credentials",
        "$HOME/.aws/config"
    )

    # Search for credentials in common paths
    foreach ($path in $pathsToSearch) {
        if (Test-Path $path) {
            Write-Output "`nChecking $path for AWS credentials..."
            $content = Get-Content $path

            $awsAccessKeys = $content | Select-String -Pattern 'aws_access_key_id'
            $awsSecretKeys = $content | Select-String -Pattern 'aws_secret_access_key'
            $awsSessionTokens = $content | Select-String -Pattern 'aws_session_token'

            if ($awsAccessKeys) {
                Write-Output "`nAWS Access Keys found in $path"
                $awsAccessKeys | ForEach-Object { Write-Output $_.Line }
            }

            if ($awsSecretKeys) {
                Write-Output "`nAWS Secret Keys found in $path"
                $awsSecretKeys | ForEach-Object { Write-Output $_.Line }
            }

            if ($awsSessionTokens) {
                Write-Output "`nAWS Session Tokens found in $path"
                $awsSessionTokens | ForEach-Object { Write-Output $_.Line }
            }
        } else {
            Write-Output "$path not found."
        }
    }

    # Search for credentials in environment variables
    $awsEnvVars = Get-ChildItem Env: | Where-Object { $_.Name -match 'AWS_' }
    if ($awsEnvVars) {
        Write-Output "`nAWS credentials found in environment variables:"
        $awsEnvVars | Format-Table -AutoSize Name, Value
    }

    $ErrorActionPreference = 'Continue'
}

function Search-AzureCredentials {
    Write-Output "`n[+] Searching for Azure credentials on the system..."
    $azureCredentialsPath = "$HOME/.azure/credentials"

    if (Test-Path $azureCredentialsPath) {
        $azureCredentials = Get-Content $azureCredentialsPath
        Write-Output "`nAzure credentials found:"
        $azureCredentials | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "`nAzure credentials not found."
    }
}

function Review-UserHistory {
    Write-Output "`n[+] Reviewing user history..."
    $userHistory = Get-Content ~/.bash_history
    Write-Output "`n[+] User Command History:"
    $userHistory | ForEach-Object { Write-Output $_ }
}

function Get-PSHistory {
    [CmdletBinding()]
    param(
        [switch]$Unique
    )

    Write-Output "`n[+] Reviewing user PowerShell history..."

    $userPSHistory = Get-Content -Encoding UTF8 (Get-PSReadLineOption).HistorySavePath

    if ($Unique) {
        $userPSHistory = $userPSHistory | Sort-Object -Unique
    }

    Write-Output "`n[+] Users Powershell Command History:"
    $userPSHistory | ForEach-Object { Write-Output $_ }
}

function Search-PSHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        [switch]$SimpleMatch,
        [switch]$Unique
    )
    Write-Output "`n[+] Matched Powershell Command History:"
    Get-PSHistory -Unique:$Unique |
        Select-String -Pattern $Pattern -SimpleMatch:$SimpleMatch | ForEach-Object { Write-Output $_}
}

function Check-Programs {
    $programs = @("nmap", "netcat", "curl", "wget", "ssh", "ftp", "gcc", "g++", "make", "python", "ruby", "perl", "python3")
    Write-Output "`n[+] Checking for installed programs..."
    foreach ($program in $programs) {
        if (Get-Command $program -ErrorAction SilentlyContinue) {
            Write-Output "[+] $program is installed."
        } else {
            Write-Output "[-] $program is not installed."
        }
    }
}

# Define the function to check files for password and API key / token-like patterns - by t3l3machus 
function Invoke-CredentialHunting {
    param(
        [string]$RootDir = "/"
    )

    # Regex patterns 
    $regexPatterns = @{
        "credentials" = ".{0,10}passw.{0,10}[\=\:]{1,2} *[\S]{2,64}"  # e.g., DB_PASSWORD = "qwerty!@#"", secret-password: 12345!@#
        "tokens" = "(?:[a-z0-9]{0,15}api|access|secret|token)(?:_|__|\-|\.\ )?(?:[a-z0-9]{0,15}key|token|secret|val|value|tok3n|k3y)? *[\=\:]{1,2} *[\S]{4,128}"  # Matches API key / token-like patterns
    }

    Write-Output "[+] Searching for credentials and API / token-like values in $RootDir"
    
    try {
        # Search files while excluding large binaries and extensions unlikely to contain credentials, and symlinks
        # The "-Attributes !ReparsePoint" in Get-ChildItem ensures that symbolic links are excluded from the search. A symlink that points back to itself or creates a loop can cause errors.
        Get-ChildItem -Path $RootDir -Recurse -File -ErrorAction SilentlyContinue -Exclude *.exe,*.dll,*.so,*.bin,*.jpg,*.jpeg,*.png,*.gif,*.bmp,*.font,*.woff,*.mp4,*.mp3,*.zip,*.tar,*.gz,*.rar,*.7z,*.kdbx,*.vmdk,*.vdi,*.vhd,*.vhdx,*.qcow2*,*.css,*.iso,*.jar,*.war -Attributes !ReparsePoint 2> $null | 
        ForEach-Object {
            try { 
                $file = $_.FullName
                $fileContent = Get-Content $file -Raw -ErrorAction SilentlyContinue
                if ([string]::IsNullOrEmpty($fileContent)) {
                    Continue
                }

                $regexPatterns.Keys | ForEach-Object {
                    $key = $_
                    $pattern = $regexPatterns[$_]
                    $matches = [regex]::Matches($fileContent, $regexPatterns[$_], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

                    if ($matches.Count -gt 0) {
                        Write-Output "[" -NoNewline
                        Write-Output "`e[38;5;214m!`e[0m" -NoNewline
                        Write-Output "] Potential $_ found in: " -NoNewline
                        Write-Output "`e[38;5;214m$($file)`e[0m"
                        $matches | ForEach-Object {
                            Write-Output "   "$_.Value
                        }
                    }
                }
            } catch {
                Write-Output "[X] Error processing file $file"
            }
        }
    } catch {
        Write-Output "[X] Error accessing $RootDir"
    }
}

# Function to handle multiple command executions
function Execute-Commands {
    param (
        [string[]]$commands
    )
    foreach ($command in $commands) {
        if (Get-Command $command -ErrorAction SilentlyContinue) {
            Invoke-Expression $command
        } else {
            Write-Output "`n[!] Unknown command: $command"
        }
    }
}

if ($args.Count -eq 0) {
    Write-Output "`n[!] No commands specified. Use './cadiclus.ps1 Show-Help' for available options."
} elseif ($args[0] -ieq "Invoke-CredentialHunting") {
    $RootDir = "/"
    # If an additional argument exists, use it as RootDir
    if ($args.Count -gt 1 -and -not [string]::IsNullOrEmpty($args[1])) {
        $RootDir = $args[1]
        if (-not (Test-Path -Path $RootDir -PathType Container)) {
            Write-Output "[X] Error: '$RootDir' is not a valid directory."
            Exit 1
        }
    }
    Invoke-CredentialHunting -RootDir $RootDir
} else {
    Execute-Commands -commands $args
}
