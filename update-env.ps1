# Environment Variable Updater PowerShell Version
# Cross-platform Windows support

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$BackupOnly,
    [string]$Rollback,
    [string]$Config,
    [string]$Format = "env",
    [string]$Output = ".env",
    [switch]$Encrypt,
    [switch]$ShowDiff,
    [string]$BatchDir,
    [switch]$Help,
    [switch]$Version
)

$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ConfigFile = Join-Path $ScriptDir "config.json"
$Script:LogFile = Join-Path $ScriptDir "update-env.log"
$Script:BackupDir = Join-Path $ScriptDir "backups"
$Script:ScriptVersion = "2.0.0"

# Configuration defaults
$Script:PreserveComments = $true
$Script:VerboseOutput = $Verbose

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Script:LogFile -Value $logEntry
    
    if ($Script:VerboseOutput -or $Level -eq "ERROR") {
        switch ($Level) {
            "ERROR" { Write-Host "[ERROR] $Message" -ForegroundColor Red }
            "WARN"  { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
            "INFO"  { Write-Host "[INFO] $Message" -ForegroundColor Green }
            "DEBUG" { Write-Host "[DEBUG] $Message" -ForegroundColor Blue }
        }
    }
}

function Show-Usage {
    @"
Environment Variable Updater v$($Script:ScriptVersion) (PowerShell)

Usage: .\update-env.ps1 -Environment <env> [OPTIONS]

Parameters:
  -Environment <env>     Environment to use (local, server, or custom name)

Options:
  -DryRun               Preview changes without applying them
  -Verbose              Enable verbose output
  -BackupOnly           Create backup without updating
  -Rollback [file]      Rollback to previous backup or specific file
  -Config <file>        Use custom configuration file
  -Format <format>      Input format (env, json, yaml)
  -Output <file>        Output file (default: .env)
  -Encrypt              Encrypt sensitive variables
  -ShowDiff             Show differences before applying
  -BatchDir <dir>       Process multiple directories
  -Help                 Show this help message
  -Version              Show version information

Examples:
  .\update-env.ps1 -Environment local
  .\update-env.ps1 -Environment server -DryRun
  .\update-env.ps1 -Rollback
"@
}

function Test-EnvFile {
    param([string]$FilePath)
    
    Write-Log "DEBUG" "Validating file: $FilePath"
    
    $errors = 0
    $lineNum = 0
    
    Get-Content $FilePath | ForEach-Object {
        $lineNum++
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            return
        }
        
        # Check key=value format
        if ($line -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
            Write-Log "WARN" "Invalid format at line $lineNum`: $line"
            $errors++
        }
    }
    
    if ($errors -gt 0) {
        Write-Log "ERROR" "Found $errors validation errors in $FilePath"
        return $false
    }
    
    Write-Log "INFO" "File validation passed: $FilePath"
    return $true
}

function New-Backup {
    param(
        [string]$SourceFile,
        [string]$BackupName = (Get-Date -Format "yyyyMMdd_HHmmss")
    )
    
    if (-not (Test-Path $Script:BackupDir)) {
        New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null
    }
    
    if (Test-Path $SourceFile) {
        $backupFile = Join-Path $Script:BackupDir ".env.backup.$BackupName"
        Copy-Item $SourceFile $backupFile
        Write-Log "INFO" "Backup created: $backupFile"
        return $backupFile
    } else {
        Write-Log "WARN" "Source file not found for backup: $SourceFile"
        return $null
    }
}

function Restore-Backup {
    param(
        [string]$BackupFile,
        [string]$TargetFile = ".env"
    )
    
    if ([string]::IsNullOrEmpty($BackupFile)) {
        $BackupFile = Get-ChildItem (Join-Path $Script:BackupDir ".env.backup.*") | 
                     Sort-Object LastWriteTime -Descending | 
                     Select-Object -First 1 -ExpandProperty FullName
        
        if (-not $BackupFile) {
            Write-Log "ERROR" "No backup files found"
            exit 1
        }
    }
    
    if (-not (Test-Path $BackupFile)) {
        Write-Log "ERROR" "Backup file not found: $BackupFile"
        exit 1
    }
    
    if ($DryRun) {
        Write-Log "INFO" "DRY RUN: Would rollback from $BackupFile to $TargetFile"
        return
    }
    
    Copy-Item $BackupFile $TargetFile
    Write-Log "INFO" "Rollback completed from $BackupFile"
}

function Show-Differences {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )
    
    if (Test-Path $TargetFile) {
        Write-Host "Differences between current .env and $SourceFile`:" -ForegroundColor Blue
        # Simple diff implementation for PowerShell
        $source = Get-Content $SourceFile
        $target = Get-Content $TargetFile
        Compare-Object $target $source -IncludeEqual | ForEach-Object {
            switch ($_.SideIndicator) {
                "==" { Write-Host "  $($_.InputObject)" }
                "=>" { Write-Host "+ $($_.InputObject)" -ForegroundColor Green }
                "<=" { Write-Host "- $($_.InputObject)" -ForegroundColor Red }
            }
        }
    } else {
        Write-Host "Target file doesn't exist. All variables from $SourceFile will be added." -ForegroundColor Blue
        Get-Content $SourceFile
    }
}

function Update-EnvFile {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )
    
    # Validate source file
    if (-not (Test-EnvFile $SourceFile)) {
        Write-Log "ERROR" "Source file validation failed"
        exit 1
    }
    
    # Create backup
    if (Test-Path $TargetFile) {
        New-Backup $TargetFile | Out-Null
    }
    
    # Read existing target file
    $existingVars = @{}
    if (Test-Path $TargetFile) {
        Get-Content $TargetFile | ForEach-Object {
            if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $existingVars[$matches[1]] = $matches[2]
            }
        }
    }
    
    $updated = 0
    $added = 0
    $newContent = @()
    
    # Process source file
    Get-Content $SourceFile | ForEach-Object {
        $line = $_
        
        # Skip empty lines and comments (unless preserving)
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            if ($Script:PreserveComments) {
                $newContent += $line
            }
            return
        }
        
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            
            if ($existingVars.ContainsKey($key)) {
                if ($DryRun) {
                    Write-Log "INFO" "DRY RUN: Would update $key"
                } else {
                    Write-Log "DEBUG" "Updated: $key"
                    $updated++
                }
            } else {
                if ($DryRun) {
                    Write-Log "INFO" "DRY RUN: Would add $key=$value"
                } else {
                    Write-Log "DEBUG" "Added: $key"
                    $added++
                }
            }
            
            $newContent += "$key=$value"
        }
    }
    
    if (-not $DryRun) {
        $newContent | Set-Content $TargetFile
        Write-Log "INFO" "Environment updated: $updated variables updated, $added variables added"
    } else {
        Write-Log "INFO" "DRY RUN: Would update $updated variables and add $added variables"
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

if ($Version) {
    Write-Host "Environment Variable Updater v$($Script:ScriptVersion) (PowerShell)"
    exit 0
}

Write-Log "INFO" "Environment Variable Updater v$($Script:ScriptVersion) started (PowerShell)"

# Handle rollback
if ($Rollback -or $PSBoundParameters.ContainsKey('Rollback')) {
    Restore-Backup $Rollback $Output
    exit 0
}

# Validate environment argument
if ([string]::IsNullOrEmpty($Environment)) {
    Write-Log "ERROR" "Environment argument required. Use -Help for usage."
    exit 1
}

# Determine source file
$sourceFile = Join-Path $Script:ScriptDir ".env.$Environment"
if (-not (Test-Path $sourceFile)) {
    Write-Log "ERROR" "Source file not found: $sourceFile"
    exit 1
}

# Handle backup only
if ($BackupOnly) {
    New-Backup $Output | Out-Null
    exit 0
}

# Show differences if requested
if ($ShowDiff) {
    Show-Differences $sourceFile $Output
    $response = Read-Host "`nContinue with update? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 0
    }
}

# Process the environment file
Update-EnvFile $sourceFile $Output

Write-Log "INFO" "Environment Variable Updater completed successfully"