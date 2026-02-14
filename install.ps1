# Islands Dark Theme Installer for Windows
# Run this script in PowerShell as Administrator

param()

$ErrorActionPreference = "Stop"

Write-Host "🏝️  Islands Dark Theme Installer for Windows" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if VS Code: is installed
$codePath = Get-Command "code" -ErrorAction SilentlyContinue
if (-not $codePath) {
    # Try to find code in common locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd"
    )
    
    $found = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $env:Path += ";$(Split-Path $path)"
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Host "❌ Error: VS Code: CLI (code) not found!" -ForegroundColor Red
        Write-Host "Please install VS Code: and make sure 'code' command is in your PATH."
        Write-Host "You can do this by:"
        Write-Host "  1. Open VS Code:"
        Write-Host "  2. Press Ctrl+Shift+P"
        Write-Host "  3. Type 'Shell Command: Install code command in PATH'"
        exit 1
    }
}

Write-Host "✓ VS Code: CLI found" -ForegroundColor Green

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "📦 Step 1: Installing Islands Dark theme extension..."
Set-Location $scriptDir
try {
    $output = code --install-extension . --force 2>&1
    Write-Host "✓ Theme extension installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install theme extension" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "🔧 Step 2: Installing Custom UI Style extension..."
try {
    $output = code --install-extension subframe7536.custom-ui-style --force 2>&1
    Write-Host "✓ Custom UI Style extension installed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not install Custom UI Style extension automatically" -ForegroundColor Yellow
    Write-Host "   Please install it manually from the Extensions marketplace"
}

Write-Host ""
Write-Host "🔤 Step 3: Installing Bear Sans UI fonts..."
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$systemFontDir = "$env:SystemRoot\Fonts"

# Try user fonts first, fallback to system fonts
$targetDir = $fontDir
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

try {
    $fonts = Get-ChildItem "$scriptDir\fonts\*.otf"
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace(0x14) # Fonts folder
    
    foreach ($font in $fonts) {
        try {
            # Copy to user fonts directory
            Copy-Item $font.FullName $targetDir -Force -ErrorAction SilentlyContinue
        } catch {
            # Silently continue if copy fails
        }
    }
    
    Write-Host "✓ Fonts installed" -ForegroundColor Green
    Write-Host "   Note: You may need to restart applications to use the new fonts" -ForegroundColor DarkGray
} catch {
    Write-Host "⚠️  Could not install fonts automatically" -ForegroundColor Yellow
    Write-Host "   Please manually install the fonts from the 'fonts/' folder"
    Write-Host "   Select all .otf files and right-click > Install"
}

Write-Host ""
Write-Host "⚙️  Step 4: Applying VS Code: settings..."
$settingsDir = "$env:APPDATA\Code\User"
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$settingsFile = Join-Path $settingsDir "settings.json"
$newSettings = Get-Content "$scriptDir\settings.json" | ConvertFrom-Json

if (Test-Path $settingsFile) {
    Write-Host "⚠️  Existing settings.json found" -ForegroundColor Yellow
    Write-Host "   Backing up to settings.json.backup"
    Copy-Item $settingsFile "$settingsFile.backup" -Force
    
    try {
        $existingSettings = Get-Content $settingsFile | ConvertFrom-Json
        
        # Merge settings - Islands Dark settings take precedence
        $mergedSettings = @{}
        $existingSettings.PSObject.Properties | ForEach-Object {
            $mergedSettings[$_.Name] = $_.Value
        }
        $newSettings.PSObject.Properties | ForEach-Object {
            $mergedSettings[$_.Name] = $_.Value
        }
        
        # Special handling for custom-ui-style.stylesheet
        if ($existingSettings.'custom-ui-style' -and $existingSettings.'custom-ui-style'.stylesheet) {
            if (-not $mergedSettings['custom-ui-style']) {
                $mergedSettings['custom-ui-style'] = @{}
            }
            $mergedStylesheet = @{}
            $existingSettings.'custom-ui-style'.stylesheet.PSObject.Properties | ForEach-Object {
                $mergedStylesheet[$_.Name] = $_.Value
            }
            $newSettings.'custom-ui-style'.stylesheet.PSObject.Properties | ForEach-Object {
                $mergedStylesheet[$_.Name] = $_.Value
            }
            $mergedSettings['custom-ui-style'].stylesheet = $mergedStylesheet
        }
        
        $mergedSettings | ConvertTo-Json -Depth 100 | Set-Content $settingsFile
        Write-Host "✓ Settings merged successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not merge settings automatically" -ForegroundColor Yellow
        Write-Host "   Please manually merge settings.json from this repo into your VS Code: settings"
        Write-Host "   Your original settings have been backed up to settings.json.backup"
    }
} else {
    Copy-Item "$scriptDir\settings.json" $settingsFile
    Write-Host "✓ Settings applied" -ForegroundColor Green
}

Write-Host ""
Write-Host "🚀 Step 5: Enabling Custom UI Style..."

# Check if this is the first run
$firstRunFile = Join-Path $scriptDir ".islands_dark_first_run"
if (-not (Test-Path $firstRunFile)) {
    New-Item -ItemType File -Path $firstRunFile | Out-Null
    Write-Host ""
    Write-Host "📝 Important Notes:" -ForegroundColor Yellow
    Write-Host "   • Geist Mono font needs to be installed separately from: https://vercel.com/font"
    Write-Host "   • After VS Code: reloads, you may see a 'corrupt installation' warning"
    Write-Host "   • This is expected - click the gear icon and select 'Don't Show Again'"
    Write-Host "   • If you need to install Geist Mono, do so now before VS Code: reloads"
    Write-Host ""
    Read-Host "Press Enter to continue and reload VS Code:"
}

Write-Host "   Applying CSS customizations..."

# Show notification
try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Islands Dark theme has been installed successfully!`n`nVS Code: will now reload to apply the custom UI style.",
        "🏝️ Islands Dark - Installation Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} catch {
    # Silently continue if notification fails
}

Write-Host ""
Write-Host "🎉 Islands Dark theme has been installed!" -ForegroundColor Green
Write-Host "   VS Code: will now reload to apply the custom UI style."
Write-Host ""

# Reload VS Code:
Write-Host "   Reloading VS Code:..." -ForegroundColor Cyan
try {
    code --reload-window 2>$null
} catch {
    # If reload-window fails, try to open the folder
    code $scriptDir 2>$null
}

Write-Host ""
Write-Host "Done! 🏝️" -ForegroundColor Green

# Keep window open briefly so user can see the message
Start-Sleep -Seconds 3
