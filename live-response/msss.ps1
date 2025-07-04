<#
.SYNOPSIS
    Microsoft Safety Scanner downloader and executor for MDE Live Response
.DESCRIPTION
    Downloads and runs Microsoft Safety Scanner on endpoints through MDE Live Response
.NOTES
    File Name: msss.ps1
    Author: Bio-Rad Security Team
    Requires: PowerShell v3.0 or later
    Usage: Upload to Live Response Library and run on endpoints as needed
.EXAMPLE
    From MDE Live Response console:
    run msss.ps1
#>

# Function definition - keeps code organized
function Invoke-MicrosoftSafetyScanner {
    [CmdletBinding()]
    param()
    
    # Start with timestamp
    $startTime = Get-Date
    Write-Host "Microsoft Safety Scanner execution started at $startTime"

    # Set download URL (64-bit only)
    $downloadUrl = "https://go.microsoft.com/fwlink/?LinkId=212732"

    # Create temp directory in Live Response working directory
    $tempDir = "C:\ProgramData\Microsoft\Windows Defender Advanced Threat Protection\Downloads\SafetyScanner_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    try {
        New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction Stop | Out-Null
        Write-Host "Created temporary directory: $tempDir"
    } catch {
        Write-Host "Error creating directory: $_"
        $tempDir = "C:\ProgramData\Microsoft\Windows Defender Advanced Threat Protection\Downloads" # Fallback location
        Write-Host "Using fallback directory: $tempDir"
    }

    # Download Microsoft Safety Scanner
    $scannerPath = Join-Path $tempDir "msert.exe"
    Write-Host "Downloading Microsoft Safety Scanner from $downloadUrl..."
    
    try {
        # Method 1: Try WebClient (usually faster and more reliable for large files)
        Write-Host "Attempting download using WebClient..."
        
        # Set global timeout for all web requests
        [System.Net.ServicePointManager]::DefaultConnectionLimit = 100
        [System.Net.ServicePointManager]::MaxServicePointIdleTime = 1800000  # 30 minutes in milliseconds
        
        $webClient = New-Object System.Net.WebClient
        # Create a timeout token source for cancellation
        $timeoutTask = New-TimeSpan -Minutes 30
        $startTime = Get-Date
        
        try {
            $webClient.DownloadFile($downloadUrl, $scannerPath)
            Write-Host "Download completed successfully using WebClient to: $scannerPath"
        }
        catch {
            # Check if timeout occurred
            if ((Get-Date) - $startTime -gt $timeoutTask) {
                Write-Host "WebClient download timed out after 30 minutes."
            } else {
                Write-Host "WebClient download failed with error: $_"
            }
            throw  # Re-throw to trigger the fallback
        }
    }
    catch {
        Write-Host "WebClient download failed: $_"
        Write-Host "Falling back to Invoke-WebRequest..."
        
        try {
            # Method 2: Use Invoke-WebRequest with progress disabled
            $ProgressPreference = 'SilentlyContinue'  # Disable progress bar to improve performance
            Invoke-WebRequest -Uri $downloadUrl -OutFile $scannerPath -UseBasicParsing -ErrorAction Stop -TimeoutSec 1800
            $ProgressPreference = 'Continue'  # Reset progress preference
            Write-Host "Download completed successfully using Invoke-WebRequest to: $scannerPath"
        }
        catch {
            Write-Host "Both download methods failed. Error: $_"
            return
        }
    }

    # Verify file was downloaded
    if ((-not (Test-Path $scannerPath)) -or ((Get-Item $scannerPath).Length -eq 0)) {
        Write-Host "Error: Scanner executable not found or empty after download"
        return
    }

    # Kill any existing Microsoft Safety Scanner processes before starting new one
    Write-Host "Checking for existing Microsoft Safety Scanner processes..."
    try {
        $existingProcesses = Get-Process -Name "msert" -ErrorAction SilentlyContinue
        if ($existingProcesses) {
            Write-Host "Found $($existingProcesses.Count) existing msert.exe process(es). Terminating..."
            foreach ($proc in $existingProcesses) {
                try {
                    Write-Host "Killing process PID: $($proc.Id)"
                    $proc.Kill()
                    $proc.WaitForExit(30000)  # Wait up to 30 seconds for graceful exit
                    Write-Host "Process PID $($proc.Id) terminated successfully"
                } catch {
                    Write-Host "Warning: Could not terminate process PID $($proc.Id): $_"
                }
            }
            # Give system time to clean up
            Start-Sleep -Seconds 5
        } else {
            Write-Host "No existing Microsoft Safety Scanner processes found"
        }
    } catch {
        Write-Host "Warning: Error checking for existing processes: $_"
    }

    # Run scanner with full scan
    Write-Host "Starting Microsoft Safety Scanner full scan at $(Get-Date)..."
    Write-Host "This may take a considerable amount of time depending on system size..."
    Write-Host "Scanner will run with reduced priority to minimize desktop/server impact..."
    try {
        # /F = full scan, /Q = quiet mode, /N = no user interaction
        # Additional parameters for automated operation
        $scanArgs = @("/F", "/Q", "/N")
        
        Write-Host "Executing: $scannerPath $($scanArgs -join ' ')"
        
        # Start process with timeout mechanism and low priority
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $scannerPath
        $processStartInfo.Arguments = $scanArgs -join " "
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        
        # Start the process
        $process.Start() | Out-Null
        Write-Host "Scanner process started with PID: $($process.Id)"
        
        # Apply resource throttling immediately after process start
        try {
            # Set to Idle priority for maximum throttling
            $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
            Write-Host "Process priority set to Idle (lowest possible) to minimize system impact"
            
            # Limit CPU cores on multi-core systems
            $processorCount = [Environment]::ProcessorCount
            if ($processorCount -gt 2) {
                # Use only 1 core on systems with more than 2 cores
                $process.ProcessorAffinity = [IntPtr]1  # Binary 0001 = first core only
                Write-Host "Process affinity set to use 1 of $processorCount CPU cores"
            } elseif ($processorCount -eq 2) {
                # On dual-core systems, still use only 1 core
                $process.ProcessorAffinity = [IntPtr]1
                Write-Host "Process affinity set to use 1 of 2 CPU cores"
            }
            
            # Get system memory info for memory throttling
            $totalMemoryGB = [Math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
            $memoryLimitMB = [Math]::Min(2048, [Math]::Max(512, $totalMemoryGB * 1024 * 0.15))  # 15% of total RAM, min 512MB, max 2GB
            Write-Host "System has $totalMemoryGB GB RAM. Scanner memory limit set to $([Math]::Round($memoryLimitMB, 0)) MB"
            
            # Enhanced PowerShell job for CPU and memory throttling
            $throttleJob = Start-Job -ScriptBlock {
                param($ProcessId, $ProcessName, $MemoryLimitMB)
                
                $throttleCount = 0
                $memoryKillCount = 0
                $lastCpuTime = 0
                $maxMemoryUsed = 0
                
                while ($true) {
                    Start-Sleep -Seconds 10  # Check every 10 seconds
                    
                    try {
                        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
                        
                        # Memory usage check
                        $memoryUsageMB = [Math]::Round($proc.WorkingSet64 / 1MB, 1)
                        if ($memoryUsageMB -gt $maxMemoryUsed) {
                            $maxMemoryUsed = $memoryUsageMB
                        }
                        
                        Write-Output "[$ProcessName] Memory: $memoryUsageMB MB (Max: $maxMemoryUsed MB, Limit: $MemoryLimitMB MB)"
                        
                        # Memory limit enforcement
                        if ($memoryUsageMB -gt $MemoryLimitMB) {
                            $memoryKillCount++
                            Write-Output "[$ProcessName] MEMORY LIMIT EXCEEDED! $memoryUsageMB MB > $MemoryLimitMB MB. Kill attempt #$memoryKillCount"
                            
                            if ($memoryKillCount -ge 3) {
                                Write-Output "[$ProcessName] CRITICAL: Memory limit exceeded 3 times. Terminating process for system stability!"
                                try {
                                    $proc.Kill()
                                    Write-Output "[$ProcessName] Process terminated due to excessive memory usage"
                                    break
                                } catch {
                                    Write-Output "[$ProcessName] Failed to terminate process: $_"
                                }
                            } else {
                                # Try to force garbage collection and suspend temporarily
                                Write-Output "[$ProcessName] Attempting memory pressure relief..."
                                try {
                                    # Suspend process to allow system memory cleanup
                                    $null = & wmic process where "ProcessId=$ProcessId" call suspend 2>$null
                                    Start-Sleep -Seconds 5
                                    [System.GC]::Collect()
                                    [System.GC]::WaitForPendingFinalizers()
                                    $null = & wmic process where "ProcessId=$ProcessId" call resume 2>$null
                                } catch {
                                    Write-Output "[$ProcessName] Memory pressure relief failed: $_"
                                }
                            }
                        }
                        
                        # CPU usage check (existing logic)
                        $currentCpuTime = $proc.TotalProcessorTime.TotalSeconds
                        $cpuDelta = $currentCpuTime - $lastCpuTime
                        
                        # If process used more than 1 second of CPU time in last 10 seconds (>10% usage)
                        if ($cpuDelta -gt 1 -and $lastCpuTime -gt 0) {
                            $throttleCount++
                            Write-Output "[$ProcessName] High CPU usage detected ($([Math]::Round($cpuDelta * 10, 1))% over 10s). Applying throttle #$throttleCount"
                            
                            # Suspend process for 2 seconds to throttle it
                            try {
                                $null = & wmic process where "ProcessId=$ProcessId" call suspend 2>$null
                                Start-Sleep -Seconds 2
                                $null = & wmic process where "ProcessId=$ProcessId" call resume 2>$null
                            } catch {
                                # Fallback: try to set priority even lower
                                try {
                                    $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
                                } catch { }
                            }
                        }
                        
                        $lastCpuTime = $currentCpuTime
                        
                    } catch {
                        # Process probably ended
                        Write-Output "[$ProcessName] Process monitoring ended - process likely completed"
                        Write-Output "[$ProcessName] Final stats - Max memory used: $maxMemoryUsed MB, CPU throttles: $throttleCount, Memory warnings: $memoryKillCount"
                        break
                    }
                }
            } -ArgumentList $process.Id, "MSERT", $memoryLimitMB
            
            Write-Host "CPU and Memory throttling monitor started"
            Write-Host "  - CPU limit: ~10% usage"
            Write-Host "  - Memory limit: $([Math]::Round($memoryLimitMB, 0)) MB"
            Write-Host "  - Process will be terminated if memory limit is exceeded 3 times"
            
        } catch {
            Write-Host "Warning: Could not apply full resource throttling: $_"
            Write-Host "Scanner will run with default priority"
        }
        
        # Wait for process with timeout (3 hours max due to throttling)
        $timeoutMinutes = 180  # Increased timeout due to throttling
        Write-Host "Waiting for scan completion (timeout: $timeoutMinutes minutes)..."
        Write-Host "Note: Scan will take longer due to CPU throttling but will not impact system performance"
        
        if ($process.WaitForExit($timeoutMinutes * 60 * 1000)) {
            Write-Host "Scan process completed at $(Get-Date) with exit code: $($process.ExitCode)"
            
            # Clean up throttling job
            if ($throttleJob) {
                try {
                    Stop-Job -Job $throttleJob -Force -ErrorAction SilentlyContinue
                    $throttleOutput = Receive-Job -Job $throttleJob -ErrorAction SilentlyContinue
                    if ($throttleOutput) {
                        Write-Host "Throttling log:"
                        $throttleOutput | ForEach-Object { Write-Host "  $_" }
                    }
                    Remove-Job -Job $throttleJob -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Host "Note: Throttling job cleanup completed"
                }
            }
            
            # Read any output
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            
            if ($stdout) {
                Write-Host "Scanner output:"
                Write-Host $stdout
            }
            
            if ($stderr) {
                Write-Host "Scanner errors:"
                Write-Host $stderr
            }
        } else {
            Write-Host "Scanner process timed out after $timeoutMinutes minutes. Terminating process..."
            
            # Clean up throttling job
            if ($throttleJob) {
                try {
                    Stop-Job -Job $throttleJob -Force -ErrorAction SilentlyContinue
                    Remove-Job -Job $throttleJob -Force -ErrorAction SilentlyContinue
                } catch { }
            }
            
            try {
                $process.Kill()
                Write-Host "Process terminated successfully."
            } catch {
                Write-Host "Error terminating process: $_"
            }
        }
        
        $process.Close()
        
    } catch {
        Write-Host "Error during scan execution: $_"
    }

    # Check for scan log
    $logPath = "C:\Windows\debug\msert.log"
    if (Test-Path $logPath) {
        Write-Host "Scan completed. Log file available at: $logPath"
        Write-Host "Log file preview (last 20 lines):"
        Get-Content $logPath -Tail 20 | ForEach-Object { Write-Host $_ }
        
        # Copy log to temp directory for easier access
        $logCopy = Join-Path $tempDir "msert.log"
        Copy-Item -Path $logPath -Destination $logCopy -Force
        Write-Host "Log file copied to: $logCopy for easier collection"
    } else {
        Write-Host "Scan completed but log file not found at expected location: $logPath"
    }

    # Display execution summary
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Host "Microsoft Safety Scanner execution completed at $endTime"
    Write-Host "Total execution time: $($duration.Hours):$($duration.Minutes):$($duration.Seconds)"
    Write-Host "Scanner location: $scannerPath"
    Write-Host "Log location: $logPath and $logCopy"
}

# For Live Response usage, automatically execute the function when script is run
try {
    # Print banner for easier identification in console output
    Write-Host "============================================================"
    Write-Host "  MICROSOFT SAFETY SCANNER - MDE LIVE RESPONSE EXECUTION"
    Write-Host "============================================================"
    Write-Host "Hostname: $env:COMPUTERNAME"
    Write-Host "Date: $(Get-Date)"
    Write-Host "User: $env:USERNAME"
    
    # Create command ID tracking for Live Response background execution
    $commandId = [System.Guid]::NewGuid().ToString()
    $commandIdFile = "C:\ProgramData\Microsoft\Windows Defender Advanced Threat Protection\Downloads\msss_command_id.txt"
    
    try {
        # Write command ID to file for easy retrieval
        $commandId | Out-File -FilePath $commandIdFile -Encoding UTF8 -Force
        Write-Host "Command ID: $commandId"
        Write-Host "Command ID saved to: $commandIdFile"
        Write-Host ""
        Write-Host "LIVE RESPONSE COMMANDS FOR BACKGROUND EXECUTION:"
        Write-Host "1. To check status: fg $commandId"
        Write-Host "2. To get command ID: getfile `"$commandIdFile`""
        Write-Host "3. To get log file: getfile `"%SYSTEMROOT%\debug\msert.log`""
        Write-Host "4. Alternative log: getfile `"C:\ProgramData\Microsoft\Windows Defender Advanced Threat Protection\Downloads\SafetyScanner_*\msert.log`""
    } catch {
        Write-Host "Warning: Could not create command ID file: $_"
        Write-Host "Command ID: $commandId (copy manually if needed)"
    }
    
    Write-Host "============================================================"
    
    # Execute the scanner function
    Invoke-MicrosoftSafetyScanner
    
    # Success exit code
    exit 0
} catch {
    # Handle any unhandled exceptions
    Write-Host "ERROR: Unhandled exception in script execution: $_"
    Write-Host $_.ScriptStackTrace
    # Error exit code
    exit 1
}
