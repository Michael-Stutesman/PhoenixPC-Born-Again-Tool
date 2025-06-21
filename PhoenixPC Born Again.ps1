# Self-elevate script if not running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
	try {
		Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
		exit
	} catch {
		Write-Host "Elevation cancelled or failed. Exiting..."
		exit
	}
}

# Load .NET Assemblies First
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Custom C# Mutex class
Add-Type -TypeDefinition @"
using System;
using System.Threading;
public static class MutexHandler {
	public static Mutex mutex;
	public static bool CreateMutex(string name) {
		bool createdNew;
		mutex = new Mutex(true, name, out createdNew);
		return createdNew;
	}
}
"@

# Native Win32 API for window control
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
	[DllImport("user32.dll", SetLastError = true)]
	public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

	[DllImport("user32.dll")]
	public static extern bool SetForegroundWindow(IntPtr hWnd);

	[DllImport("user32.dll")]
	public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

	[DllImport("user32.dll")]
	public static extern void SwitchToThisWindow(IntPtr hWnd, bool fUnknown);

	[DllImport("kernel32.dll")]
	public static extern IntPtr GetConsoleWindow();
}
"@

# Hide Console Window Immediately
[Win32]::ShowWindow([Win32]::GetConsoleWindow(), 0)

# Prevent Multiple Instances Using Mutex
$mutexName = "PhoenixPC_Mutex_Lock"
if (-not [MutexHandler]::CreateMutex($mutexName)) {
	[System.Windows.Forms.MessageBox]::Show("PhoenixPC Born Again is already running.", "Already Running", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
	exit
}

# Directories and Config Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir = [IO.Path]::Combine($env:LOCALAPPDATA, "PhoenixPC Born Again")

# Load Icon (if exists)
$icon = [IO.Path]::Combine($scriptDir, "PhoenixPC.ico")
if (Test-Path $icon) {
	$formIcon = [Drawing.Icon]::ExtractAssociatedIcon($icon)
}

if (-not (Test-Path $configDir)) {
	New-Item -ItemType Directory -Path $configDir | Out-Null
}

$configRammapPath        = [IO.Path]::Combine($configDir, "rammap_config.txt")
$configReduceMemPath     = [IO.Path]::Combine($configDir, "reducememory_config.txt")
$configDevconPath        = [IO.Path]::Combine($configDir, "devcon_path.txt")
$configCheckboxStatePath = [IO.Path]::Combine($configDir, "checkbox_states.txt")
$positionFile            = [IO.Path]::Combine($configDir, "form_position.txt")
$configTimerPath         = [IO.Path]::Combine($configDir, "timer_config.txt")

Set-Variable -Name configTimerPath -Value $configTimerPath -Scope Global

# Helper function to load saved form position
function Load-FormPosition {
	if (Test-Path $positionFile) {
		$pos = Get-Content $positionFile -ErrorAction SilentlyContinue
		if ($pos -match '^\s*(\d+),\s*(\d+)\s*$') {
			return New-Object System.Drawing.Point($matches[1], $matches[2])
		}
	}
	return $null
}

# --- Form Setup ---
$form = New-Object Windows.Forms.Form
$form.Text = "PhoenixPC Born Again"
$form.Size = New-Object Drawing.Size(495, 700)
$form.MaximumSize = $form.Size
$form.MinimumSize = $form.Size
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'Manual'
$form.Topmost = $true
$form.BackColor = [Drawing.Color]::FromArgb(23, 73, 120)
$form.ForeColor = [Drawing.Color]::FromArgb(255, 245, 230)

if ($formIcon) {
	$form.Icon = $formIcon
}

# Load saved position (use it no matter where it is)
$savedPos = Load-FormPosition
if ($savedPos) {
	$form.Location = $savedPos
} else {
	# Default to center of primary screen
	$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
	$form.Location = New-Object System.Drawing.Point(
		[int]($screen.Width / 2 - $form.Width / 2),
		[int]($screen.Height / 2 - $form.Height / 2)
	)
}

# Save position on close
$form.Add_FormClosing({
	try {
		$dir = Split-Path $positionFile
		if (-not (Test-Path $dir)) {
			New-Item -ItemType Directory -Path $dir | Out-Null
		}
		"$($form.Location.X),$($form.Location.Y)" | Set-Content $positionFile
	} catch {}
	Save-TimerSettings
})

# System Tray Icon Setup
$iconPath = Join-Path $scriptDir "PhoenixPC.ico"
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = New-Object System.Drawing.Icon($iconPath)
$trayIcon.Visible = $false
$trayIcon.Text = "PhoenixPC Born Again"

# Restore form from tray on double-click
$trayIcon.Add_DoubleClick({
	$form.WindowState = 'Normal'
	$form.ShowInTaskbar = $true
	$form.Show()
	$trayIcon.Visible = $false

	$output.SelectionStart = $output.Text.Length
	$output.ScrollToCaret()
})

# Minimize to Tray Button
$btnMinToTray = New-Object Windows.Forms.Button
$btnMinToTray.Text = "Minimize To Tray"
$btnMinToTray.Size = New-Object Drawing.Size(120, 18)
$btnMinToTray.Location = New-Object Drawing.Point(359, -3)
$btnMinToTray.BackColor = [System.Drawing.Color]::FromArgb(215, 100, 20)
$btnMinToTray.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnMinToTray.FlatAppearance.BorderSize = 0

$btnMinToTray.Add_Paint({
	param($sender, $e)
	$graphics = $e.Graphics
	$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1)
	$rect = $sender.ClientRectangle
	$rect.Width -= 1
	$rect.Height -= 1
	$graphics.DrawRectangle($pen, $rect)
	$pen.Dispose()
})

$form.Controls.Add($btnMinToTray)

$btnMinToTray.Add_Click({
	$form.Hide()
	$form.ShowInTaskbar = $false
	$trayIcon.Visible = $true
})

$form.Add_FormClosed({
	[MutexHandler]::mutex.ReleaseMutex()
	[MutexHandler]::mutex.Dispose()
})

# Task definitions
$tasks = @(
	@{ N = " Flush DNS ";                          D = " Resets DNS cache.  Fixes loading and routing issues.";     A = { Flush-DNS };                Y = 10 },
	@{ N = " Restart Network Services ";          D = " Restarts network stack.  Resolves connection faults.";     A = { Restart-NetworkServices };  Y = 40 },
	@{ N = " Restart Windows Explorer ";          D = " Reloads UI shell.  Fixes desktop or taskbar bugs.";        A = { Restart-Explorer };         Y = 70 },
	@{ N = " Clear Temp Files ";                  D = " Removes temp data.  Recovers drive space.";                A = { Clear-TempFiles };          Y = 100 },
	@{ N = " Clear RAM Standby List  (RAMMap) ";  D = " Flushes standby RAM.  Helps lag, may stutter.";            A = { Clear-RAMStandby };         Y = 130 },
	@{ N = " Optimize Memory  (ReduceMemory) ";   D = " Frees unused RAM.  Smoother multitasking.";                A = { Run-ReduceMemory };         Y = 160 },
	@{ N = " Reset GPU Driver  (DevCon) ";        D = " Resets display adapter drivers.  May prompt restart*";     A = { Reset-DevconGPU };          Y = 190 },
	@{ N = " Reset Network Adapters  (DevCon) ";  D = " Restarts network adapters.  May prompt restart*";          A = { Reset-DevconNet };          Y = 220 },
	@{ N = " Reset Audio Drivers  (DevCon) ";     D = " Restarts audio devices.  May prompt restart*";             A = { Reset-DevconAudio };        Y = 250 },
	@{ N = " Reset USB Controllers  (DevCon) ";   D = " Resets USB drivers.  May prompt restart*";                 A = { Reset-DevconUSB };          Y = 280 }
)

# Add checkboxes
$checkboxes = @()
foreach ($t in $tasks) {
	$cb = New-Object Windows.Forms.CheckBox
	$cb.Text = "$($t.N) - $($t.D)"
	$cb.Location = New-Object Drawing.Point(10, $t.Y)
	$cb.Size = New-Object Drawing.Size(460, 25)
	$cb.AutoSize = $false
	$cb.BackColor = $form.BackColor
	$cb.ForeColor = $form.ForeColor
	$cb.FlatStyle = 'Standard'
	$cb.Appearance = 'Normal'

	$cb.Add_Paint({
		param($sender, $e)
		$g = $e.Graphics
		$rect = $sender.ClientRectangle
		$borderPen = New-Object Drawing.Pen([Drawing.Color]::White, 1)
		$borderRect = $rect
		$borderRect.Width -= 1
		$borderRect.Height -= 1
		$g.DrawRectangle($borderPen, $borderRect)
		$borderPen.Dispose()

		$checkBoxRect = [Drawing.Rectangle]::new(4, 4, 14, 14)
		$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(215, 100, 20))
		$g.FillRectangle($brush, $checkBoxRect)
		$brush.Dispose()

		if ($sender.Checked) {
			$p = [Drawing.Pen]::new([Drawing.Color]::White, 2)
			$g.DrawLines($p, @(
				[Drawing.Point]::new(6, 11),
				[Drawing.Point]::new(10, 15),
				[Drawing.Point]::new(16, 6)
			))
			$p.Dispose()
		}
	})

	$form.Controls.Add($cb)
	$t.CheckBox = $cb
	$checkboxes += $t
}

# Load saved checkbox states
$checkboxStates = @{ }
if (Test-Path $configCheckboxStatePath) {
	Get-Content $configCheckboxStatePath | ForEach-Object {
		$parts = $_ -split '=', 2
		if ($parts.Count -eq 2) {
			$key = $parts[0].Trim()
			$val = $parts[1].Trim().ToLower()
			$checkboxStates[$key] = ($val -eq 'true')
		}
	}
}
foreach ($t in $tasks) {
	$t.CheckBox.Checked = $checkboxStates[$t.N.Trim()] -or $false
}

# Save checkbox states on close
$form.Add_FormClosing({
	$lines = foreach ($t in $tasks) {
		"$($t.N)=$($t.CheckBox.Checked)"
	}
	$lines | Set-Content -Path $configCheckboxStatePath -Encoding UTF8
})

# Info label
$foot = New-Object Windows.Forms.Label
$foot.Text = "* Use only when experiencing issues. Restart not always required."
$foot.Location = New-Object Drawing.Point(10, 305)
$foot.Size = New-Object Drawing.Size(460, 20)
$foot.ForeColor = 'DarkGray'
$form.Controls.Add($foot)

# Run Now button
$btnRun = New-Object Windows.Forms.Button
$btnRun.Text = "Run Selected Tasks"
$btnRun.Size = New-Object Drawing.Size(225, 30)
$btnRun.Location = New-Object Drawing.Point(10, 330)
$form.Controls.Add($btnRun)

# Run Timer button
$btnRunTimer = New-Object Windows.Forms.Button
$btnRunTimer.Text = "Run Tasks On Interval"
$btnRunTimer.Size = New-Object Drawing.Size(225, 30)
$btnRunTimer.Location = New-Object Drawing.Point(245, 330)
$form.Controls.Add($btnRunTimer)

# Output box
$output = New-Object Windows.Forms.TextBox
$output.Multiline = $true
$output.ScrollBars = 'Vertical'
$output.ReadOnly = $true
$output.Size = New-Object Drawing.Size(460, 120)
$output.Location = New-Object Drawing.Point(10, 365)
$output.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$form.Controls.Add($output)

# Run Now logic
$btnRun.Add_Click({
	$output.Clear()
	try {
		foreach ($t in $checkboxes) {
			if ($t.CheckBox.Checked) {
				& $t.A
			}
		}
		Append-Output "All selected tasks completed!"
	} catch {
		Show-Error "Error: $_"
	}
})

# Timer run logic
$btnRunTimer.Add_Click({
	$output.Clear()
	try {
		$interval = [int]$intervalBox.Text
		if ($interval -lt 1) { throw "Interval must be 1 minute or more." }

		foreach ($t in $checkboxes) {
			if ($t.CheckBox.Checked) {
				& $t.A
			}
		}

		Append-Output "All selected tasks completed! (Running on Interval)"
		$time = Get-Date -Format "hh:mm:ss tt"
		Append-Output "Initial execution completed at $time"

		$timer.Interval = $interval * 60000	# Convert minutes to milliseconds
		$timer.Start()

		$stopBtn.Enabled = $true
		$btnRunTimer.Enabled = $false
		$btnRun.Enabled = $false

		$unit = if ($interval -eq 1) { "minute" } else { "minutes" }
		Append-Output "Scheduled execution started. Running every $interval $unit."
	} catch {
		Show-Error "Error: $_"
	}
})

function Append-Output([string]$txt) {
	$output.AppendText($txt + "`r`n")

	if ($output.Lines.Count -gt 300) {
		$output.Text = $output.Lines[-300..-1] -join "`r`n"
	}

	$output.SelectionStart = $output.Text.Length
	$output.Focus()
	$output.ScrollToCaret()
}

# Shows an error message box with the specified message
function Show-Error([string]$msg) {
	[Windows.Forms.MessageBox]::Show($msg, "Error", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

# Flushes the DNS resolver cache to clear DNS entries
function Flush-DNS {
	Append-Output "Flushing DNS..."
	Start-Process ipconfig -ArgumentList '/flushdns' -NoNewWindow -Wait -WindowStyle Hidden
	Append-Output "DNS flushed."
}

# Restarts a predefined list of network-related Windows services
function Restart-NetworkServices {
	Append-Output "Restarting Network Services..."
	foreach ($svc in $netSvcs) {
		try {
			Restart-Service -Name $svc -Force -ErrorAction Stop
			Append-Output "  Restarted service: $svc"
		} catch {
			Append-Output "Couldn't restart (in use or denied): $svc"
		}
	}
	Append-Output "Network services restarted."
}

# Restarts Windows Explorer process to refresh the desktop and taskbar
function Restart-Explorer {
	Append-Output "Restarting Windows Explorer..."
	try {
		Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
		Start-Sleep 1
		Start-Process explorer.exe
		Append-Output "Explorer restarted."
	} catch {
		Append-Output "Error restarting Explorer: $_"
	}
}

# Deletes files and folders inside temp directories to clear temporary files
function Clear-TempFiles {
	Append-Output "Clearing Temp Files..."
	$paths = @("$env:TEMP", "C:\Windows\Temp")
	foreach ($p in $paths) {
		try {
			Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
				try {
					if ($_.PSIsContainer) {
						Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
					} else {
						Remove-Item $_.FullName -Force -ErrorAction Stop
					}
					Append-Output "Deleted: $($_.FullName)"
				} catch {
					Append-Output "Skipped (in use or denied): $($_.FullName)"
				}
			}
		} catch {
			Append-Output "Failed to enumerate $p"
		}
	}
	Append-Output "Temp file cleanup finished."
}

# Clears RAM standby list using RAMMap tool if valid executable path provided
function Clear-RAMStandby {
	Append-Output "Clearing RAM standby list..."
	$path = $rammapPathBox.Text.Trim()
	if (-not (Test-Path $path) -or [IO.Path]::GetExtension($path).ToLower() -ne ".exe") {
		Append-Output "Invalid or missing RAMMap path: '$path'. Skipping."
		return
	}
	try {
		$proc = Start-Process -FilePath $path -ArgumentList "-E" -PassThru
		$proc.WaitForExit(15000) | Out-Null
		Append-Output "RAM standby cleared."
	} catch {
		Append-Output "RAMMap error: $_"
	}
}

# Runs ReduceMemory.exe to optimize and free RAM, reporting memory cleared
function Run-ReduceMemory {
	Append-Output "Running ReduceMemory 1.7 optimization..."
	$path = $reduceMemPathBox.Text
	if (-not (Test-Path $path) -or [IO.Path]::GetExtension($path) -ne ".exe") {
		Append-Output "ReduceMemory not found or invalid at $path. Skipping."
		return
	}

	$memBefore = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024, 1)
	$proc = Start-Process -FilePath $path -ArgumentList "/O" -PassThru
	$proc.WaitForExit(30000) | Out-Null
	$memAfter = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024, 1)

	Append-Output ("ReduceMemory complete. Cleared {0} MB of RAM." -f ($memAfter - $memBefore))
}

# Resets GPU drivers using Devcon.exe utility
function Reset-DevconGPU {
	$devcon = $devconPathBox.Text.Trim()
	if (-not (Test-Path $devcon)) {
		Append-Output "DevCon.exe not found at '$devcon'. Skipping GPU reset."
		return
	}
	Append-Output "Resetting GPU drivers..."
	try {
		$proc = Start-Process $devcon -ArgumentList "restart =DISPLAY" -PassThru
		if (-not $proc.WaitForExit(15000)) {
			Append-Output "Timeout: DevCon GPU reset still running after 15 seconds. Proceeding anyway."
		} else {
			Append-Output "GPU drivers reset."
		}
	} catch {
		Append-Output "Failed to reset GPU drivers: $_"
	}
}

# Resets Network adapters using Devcon.exe utility
function Reset-DevconNet {
	$devcon = $devconPathBox.Text.Trim()
	if (-not (Test-Path $devcon)) {
		Append-Output "DevCon.exe not found at '$devcon'. Skipping Network adapters reset."
		return
	}
	Append-Output "Resetting Network adapters..."
	try {
		$proc = Start-Process $devcon -ArgumentList "restart =NET" -PassThru
		if (-not $proc.WaitForExit(15000)) {
			Append-Output "Timeout: DevCon Network reset still running after 15 seconds. Proceeding anyway."
		} else {
			Append-Output "Network adapters reset."
		}
	} catch {
		Append-Output "Failed to reset Network adapters: $_"
	}
}

# Resets Audio drivers using Devcon.exe utility
function Reset-DevconAudio {
	$devcon = $devconPathBox.Text.Trim()
	if (-not (Test-Path $devcon)) {
		Append-Output "DevCon.exe not found at '$devcon'. Skipping Audio drivers reset."
		return
	}
	Append-Output "Resetting Audio drivers..."
	try {
		$proc = Start-Process $devcon -ArgumentList "restart =MEDIA" -PassThru
		if (-not $proc.WaitForExit(15000)) {
			Append-Output "Timeout: DevCon Audio reset still running after 15 seconds. Proceeding anyway."
		} else {
			Append-Output "Audio drivers reset."
		}
	} catch {
		Append-Output "Failed to reset Audio drivers: $_"
	}
}

# Resets USB controllers using Devcon.exe utility
function Reset-DevconUSB {
	$devcon = $devconPathBox.Text.Trim()
	if (-not (Test-Path $devcon)) {
		Append-Output "DevCon.exe not found at '$devcon'. Skipping USB controllers reset."
		return
	}
	Append-Output "Resetting USB controllers..."
	try {
		$proc = Start-Process $devcon -ArgumentList "restart =USB" -PassThru
		if (-not $proc.WaitForExit(15000)) {
			Append-Output "Timeout: DevCon USB reset still running after 15 seconds. Proceeding anyway."
		} else {
			Append-Output "USB controllers reset."
		}
	} catch {
		Append-Output "Failed to reset USB controllers: $_"
	}
}

# ------------------ RAMMap Path Input ------------------

$rammapLabel = New-Object System.Windows.Forms.Label -Property @{
	Text     = "Path to RAMMap64.exe (if used):"
	Location = New-Object Drawing.Point(90, 490)
	Size     = New-Object Drawing.Size(180, 15)
}
$form.Controls.Add($rammapLabel)

$browseRammapBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Browse..."
	Size     = New-Object Drawing.Size(75, 23)
	Location = New-Object Drawing.Point(10, 487)
}
$browseRammapBtn.Add_Click({
	$dialog = New-Object System.Windows.Forms.OpenFileDialog
	$dialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$rammapPathBox.Text = $dialog.FileName
	}
})
$form.Controls.Add($browseRammapBtn)

$rammapPathBox = New-Object System.Windows.Forms.TextBox -Property @{
	Location = New-Object Drawing.Point(10, 510)
	Size     = New-Object Drawing.Size(360, 20)
	Text     = $(if (Test-Path $configRammapPath) { Get-Content $configRammapPath -ErrorAction SilentlyContinue } else { "" })
}
$form.Controls.Add($rammapPathBox)

$saveRammapBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Save Path"
	Size     = New-Object Drawing.Size(100, 23)
	Location = New-Object Drawing.Point(375, 503)
}
$saveRammapBtn.Add_Click({
	try {
		Set-Content -Path $configRammapPath -Value $rammapPathBox.Text
		[System.Windows.Forms.MessageBox]::Show("RAMMap path saved!", "Success")
	} catch {
		Show-Error "Failed to save RAMMap path: $_"
	}
})
$form.Controls.Add($saveRammapBtn)

$rammapLink = New-Object System.Windows.Forms.LinkLabel -Property @{
	Text      = "Download RAMMap"
	Location  = New-Object Drawing.Point(375, 487)
	Size      = New-Object Drawing.Size(120, 30)
	LinkColor = [System.Drawing.Color]::FromArgb(255, 140, 60)
}
$rammapLink.Add_Click({
	Start-Process "https://learn.microsoft.com/en-us/sysinternals/downloads/rammap"
})
$form.Controls.Add($rammapLink)

# ------------------ ReduceMemory Path Input ------------------

$reduceMemLabel = New-Object System.Windows.Forms.Label -Property @{
	Text     = "Path to ReduceMemory (if used):"
	Location = New-Object Drawing.Point(90, 535)
	Size     = New-Object Drawing.Size(180, 15)
}
$form.Controls.Add($reduceMemLabel)

$browseReduceMemBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Browse..."
	Size     = New-Object Drawing.Size(75, 23)
	Location = New-Object Drawing.Point(10, 532)
}
$browseReduceMemBtn.Add_Click({
	$dialog = New-Object System.Windows.Forms.OpenFileDialog
	$dialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$reduceMemPathBox.Text = $dialog.FileName
	}
})
$form.Controls.Add($browseReduceMemBtn)

$reduceMemPathBox = New-Object System.Windows.Forms.TextBox -Property @{
	Location = New-Object Drawing.Point(10, 555)
	Size     = New-Object Drawing.Size(360, 20)
	Text     = $(if (Test-Path $configReduceMemPath) { Get-Content $configReduceMemPath -ErrorAction SilentlyContinue } else { "" })
}
$form.Controls.Add($reduceMemPathBox)

$saveReduceMemBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Save Path"
	Size     = New-Object Drawing.Size(100, 23)
	Location = New-Object Drawing.Point(375, 553)
}
$saveReduceMemBtn.Add_Click({
	try {
		Set-Content -Path $configReduceMemPath -Value $reduceMemPathBox.Text
		[System.Windows.Forms.MessageBox]::Show("ReduceMemory path saved!", "Success")
	} catch {
		Show-Error "Failed to save ReduceMemory path: $_"
	}
})
$form.Controls.Add($saveReduceMemBtn)

$reduceMemLink = New-Object System.Windows.Forms.LinkLabel -Property @{
	Text      = "Download ReduceMemory"
	Location  = New-Object Drawing.Point(375, 527)
	Size      = New-Object Drawing.Size(120, 30)
	LinkColor = [System.Drawing.Color]::FromArgb(255, 140, 60)
}
$reduceMemLink.Add_Click({
	Start-Process "https://www.sordum.org/9197/reduce-memory-v1-7/"
})
$form.Controls.Add($reduceMemLink)

# ------------------ Devcon Path Input ------------------

$devconLabel = New-Object System.Windows.Forms.Label -Property @{
	Text     = "Path to DevCon.exe (if used):"
	Location = New-Object Drawing.Point(90, 580)
	Size     = New-Object Drawing.Size(180, 15)
}
$form.Controls.Add($devconLabel)

$browseDevconBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Browse..."
	Size     = New-Object Drawing.Size(75, 23)
	Location = New-Object Drawing.Point(10, 577)
}
$browseDevconBtn.Add_Click({
	$dialog = New-Object System.Windows.Forms.OpenFileDialog
	$dialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$devconPathBox.Text = $dialog.FileName
	}
})
$form.Controls.Add($browseDevconBtn)

$devconPathBox = New-Object System.Windows.Forms.TextBox -Property @{
	Location = New-Object Drawing.Point(10, 600)
	Size     = New-Object Drawing.Size(360, 20)
	Text     = $(if (Test-Path $configDevconPath) { Get-Content $configDevconPath -ErrorAction SilentlyContinue } else { "" })
}
$form.Controls.Add($devconPathBox)

$saveDevconBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Save Path"
	Size     = New-Object Drawing.Size(100, 23)
	Location = New-Object Drawing.Point(375, 598)
}
$saveDevconBtn.Add_Click({
	try {
		Set-Content -Path $configDevconPath -Value $devconPathBox.Text
		[System.Windows.Forms.MessageBox]::Show("DevCon path saved!", "Success")
	} catch {
		Show-Error "Failed to save devcon path: $_"
	}
})
$form.Controls.Add($saveDevconBtn)

$devconLink = New-Object System.Windows.Forms.LinkLabel -Property @{
	Text      = "Download DevCon"
	Location  = New-Object Drawing.Point(375, 580)
	Size      = New-Object Drawing.Size(110, 30)
	LinkColor = [System.Drawing.Color]::FromArgb(255, 140, 60)
}
$devconLink.Add_Click({
	Start-Process "https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/devcon"
})
$form.Controls.Add($devconLink)

# ------------------ Timer Controls ------------------

# Timer object and interval setup
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1800000  # Default 30 minutes
$timerRunning = $false     # Track if timer is running

# Label and input for interval (in minutes)
$intervalLabel = New-Object System.Windows.Forms.Label -Property @{
	Text     = "Interval (minutes):"
	Location = New-Object Drawing.Point(30, 634)
	Size     = New-Object Drawing.Size(110, 20)
}
$intervalBox = New-Object Windows.Forms.TextBox -Property @{
	Location = New-Object Drawing.Point(140, 631)
	Size     = New-Object Drawing.Size(60, 20)
	Text     = "30"
}

# Stop Timer button
$stopBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Stop Timer"
	Size     = New-Object Drawing.Size(120, 24)
	Location = New-Object Drawing.Point(230, 629)
	Enabled  = $false
}

# Task Manager button
$taskMgrBtn = New-Object System.Windows.Forms.Button -Property @{
	Text     = "Task Manager"
	Size     = New-Object Drawing.Size(84, 22)
	Location = New-Object Drawing.Point(384, 630)
}

# Prevent Task Manager overlap
$script:TaskMgrLock = $false

# Handle Task Manager button click
$taskMgrBtn.Add_Click({
	if ($script:TaskMgrLock) { return }
	$script:TaskMgrLock = $true
	$taskMgrBtn.Enabled = $false	# Disable button immediately to prevent double-clicks

	try {
		$task = Get-Process -Name "Taskmgr" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }

		if ($task) {
			try {
				# Kill immediately
				$task[0].Kill()

				# Wait up to 1500ms for it to exit
				if (-not $task[0].WaitForExit(1500)) {
					Show-Error "Task Manager did not close properly."
				}
			} catch {
				Show-Error "Failed to close Task Manager: $_"
			}
		} else {
			# Start Task Manager
			Start-Process "taskmgr.exe"
		}

		Start-Sleep -Milliseconds 1500
	} catch {
		Show-Error "Error handling Task Manager: $_"
	} finally {
		$script:TaskMgrLock = $false
		$taskMgrBtn.Enabled = $true
	}
})

# Add controls in batch for slightly faster UI setup
$form.Controls.AddRange(@($intervalLabel, $intervalBox, $stopBtn, $taskMgrBtn))

# Config path (must be set earlier in full script)
$timerConfigPath = $global:configTimerPath

# Save timer settings to file
function Save-TimerSettings {
	@(
		"Checked=$($timerCheckbox.Checked)"
		"Interval=$($intervalBox.Text)"
		"Running=$timerRunning"
	) | Set-Content -Path $timerConfigPath -Encoding UTF8
}

# Load timer settings from file
function Load-TimerSettings {
	if (Test-Path $timerConfigPath) {
		Get-Content $timerConfigPath | ForEach-Object {
			$kv = $_ -split '=', 2
			switch ($kv[0]) {
				"Checked"  { $timerCheckbox.Checked = [bool]::Parse($kv[1]) }
				"Interval" { $intervalBox.Text = $kv[1] }
				"Running"  { $timerRunning = [bool]::Parse($kv[1]) }
			}
		}

		# Set interval if valid (convert minutes to milliseconds)
		if ($intervalBox.Text -match '^\d+$' -and [int]$intervalBox.Text -gt 0) {
			$timer.Interval = [int]$intervalBox.Text * 60000
		}

		# Adjust control states
		if ($timerRunning -and $timerCheckbox.Checked) {
			$timer.Start()
			$stopBtn.Enabled = $true
			$btnRunTimer.Enabled = $false
			$btnRun.Enabled = $false

			# Output interval message in minutes
			$interval = [int]$intervalBox.Text
			$unit = if ($interval -eq 1) { "minute" } else { "minutes" }
			Append-Output "Scheduled execution started. Running every $interval $unit."
		} else {
			$stopBtn.Enabled = $false
			$btnRunTimer.Enabled = $true
			$btnRun.Enabled = $true
		}
	}
}

# Timer Tick event: run all checked tasks
$timer.Add_Tick({
	try {
		foreach ($t in $checkboxes) {
			if ($t.CheckBox.Checked) {
				& $t.A
			}
		}
		$time = Get-Date -Format "hh:mm:ss tt"
		Append-Output "All selected tasks completed! (Running on Interval at $time)"
	} catch {
		Show-Error "Error during interval execution: $_"
	}
})

# Stop Timer button click
$stopBtn.Add_Click({
	$timer.Stop()
	$timerRunning = $false
	$stopBtn.Enabled = $false
	$btnRunTimer.Enabled = $true
	$btnRun.Enabled = $true
	Append-Output "Scheduled execution stopped at $(Get-Date -Format 'T')"
})

# Save on form close
$form.Add_FormClosing({ Save-TimerSettings })

# Load settings initially
Load-TimerSettings

# Auto-scroll to bottom when form is restored from minimized
$form.Add_VisibleChanged({
	if ($form.Visible -and $form.WindowState -eq 'Normal') {
		$output.SelectionStart = $output.Text.Length
		$output.ScrollToCaret()
	}
})

# Start GUI
[System.Windows.Forms.Application]::Run($form)