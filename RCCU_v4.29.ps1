Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ("RetroBatWindowApi" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RetroBatWindowApi
{
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

}
"@
}

# RichTextBox scroll-position support.  EM_GETFIRSTVISIBLELINE lets RCCU
# remember the exact line the user was reading while live output continues.
# EM_LINESCROLL then restores that viewport after new text is appended.
if (-not ("RCCURichEditApi" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RCCURichEditApi
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(
        IntPtr hWnd,
        int msg,
        IntPtr wParam,
        IntPtr lParam
    );

    public const int EM_GETFIRSTVISIBLELINE = 0x00CE;
    public const int EM_LINESCROLL = 0x00B6;
}
"@
}

# ------------------------------------------------------------
# WINDOWS 11 DARK TITLE BAR SUPPORT
# ------------------------------------------------------------
if (-not ("RetroBatDarkModeApi" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RetroBatDarkModeApi
{
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(
        IntPtr hwnd,
        int dwAttribute,
        ref int pvAttribute,
        int cbAttribute
    );
}
"@
}

function Set-DarkTitleBar {
    param(
        [System.Windows.Forms.Form]$Window,
        [bool]$Enabled = $true
    )

    if ($null -eq $Window) {
        return
    }

    try {
        $useDark = if ($Enabled) { 1 } else { 0 }
        # DWMWA_USE_IMMERSIVE_DARK_MODE = 20 on current Windows 10/11.
        [RetroBatDarkModeApi]::DwmSetWindowAttribute(
            $Window.Handle,
            20,
            [ref]$useDark,
            4
        ) | Out-Null
    }
    catch {
        # Older Windows builds may not expose this attribute.
    }
}

function Apply-DarkThemeToControl {
    param(
        $Control,
        [bool]$Enabled = $true
    )

    if ($null -eq $Control) {
        return
    }

    if ($Enabled) {
        $back = [System.Drawing.Color]::FromArgb(30,30,30)
        $panelBack = [System.Drawing.Color]::FromArgb(38,38,38)
        $controlBack = [System.Drawing.Color]::FromArgb(45,45,45)
        $buttonBack = [System.Drawing.Color]::FromArgb(55,55,55)
        $fore = [System.Drawing.Color]::WhiteSmoke
    }
    else {
        $back = [System.Drawing.SystemColors]::Control
        $panelBack = [System.Drawing.SystemColors]::Control
        $controlBack = [System.Drawing.SystemColors]::Window
        $buttonBack = [System.Drawing.SystemColors]::Control
        $fore = [System.Drawing.SystemColors]::ControlText
    }

    if ($Control -is [System.Windows.Forms.Form]) {
        $Control.BackColor = $back
        $Control.ForeColor = $fore
    }
    elseif ($Control -is [System.Windows.Forms.RichTextBox]) {
        $Control.BackColor = $controlBack
        $Control.ForeColor = $fore
    }
    elseif (
        $Control -is [System.Windows.Forms.TextBoxBase] -or
        $Control -is [System.Windows.Forms.CheckedListBox] -or
        $Control -is [System.Windows.Forms.ListBox] -or
        $Control -is [System.Windows.Forms.ComboBox]
    ) {
        $Control.BackColor = $controlBack
        $Control.ForeColor = $fore
    }
    elseif ($Control -is [System.Windows.Forms.Button]) {
        $Control.BackColor = $buttonBack
        $Control.ForeColor = $fore
        $Control.UseVisualStyleBackColor = $false
    }
    elseif ($Control -is [System.Windows.Forms.Panel] -or
            $Control -is [System.Windows.Forms.GroupBox] -or
            $Control -is [System.Windows.Forms.SplitContainer]) {
        $Control.BackColor = $panelBack
        $Control.ForeColor = $fore
    }
    else {
        $Control.ForeColor = $fore
    }

    if ($Control.Controls) {
        foreach ($child in @($Control.Controls)) {
            Apply-DarkThemeToControl $child $Enabled
        }
    }
}

function Set-DarkThemeForForm {
    param(
        [System.Windows.Forms.Form]$Window,
        [bool]$Enabled = $true
    )

    if ($null -eq $Window) {
        return
    }

    # Child windows inherit the main interface theme.  The root selector is
    # created before the main checkbox exists, so it keeps the default dark theme.
    if ($null -ne $script:MainDarkModeState) {
        $Enabled = [bool]$script:MainDarkModeState
    }

    Apply-DarkThemeToControl $Window $Enabled
    Set-DarkTitleBar $Window $Enabled
    [System.Windows.Forms.Application]::DoEvents()
}

$ErrorActionPreference = "Stop"

# ============================================================
# CREATE A SIMPLE FLAT RAZOR/SCRAPER BLADE ICON
# ============================================================
# Flat single-edge scraper/razor silhouette — no knife handle or knife profile.
$razorBitmap = New-Object System.Drawing.Bitmap(64,64)
$razorGraphics = [System.Drawing.Graphics]::FromImage($razorBitmap)
$razorGraphics.Clear([System.Drawing.Color]::Transparent)
$razorGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$razorOutline = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(25,25,25),2)
$razorSteel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(218,220,224))
$razorEdgeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(135,138,144))
$razorHolder = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55,58,62))

# Broad flat blade with a shallow trapezoid shoulder and one exposed cutting edge.
$blade = @(
    [System.Drawing.Point]::new(9,12),
    [System.Drawing.Point]::new(55,12),
    [System.Drawing.Point]::new(52,43),
    [System.Drawing.Point]::new(12,43)
)
$razorGraphics.FillPolygon($razorSteel,$blade)
$razorGraphics.DrawPolygon($razorOutline,$blade)

# Exposed single cutting edge.
$edge = @(
    [System.Drawing.Point]::new(12,38),
    [System.Drawing.Point]::new(52,38),
    [System.Drawing.Point]::new(52,43),
    [System.Drawing.Point]::new(12,43)
)
$razorGraphics.FillPolygon($razorEdgeBrush,$edge)
$razorGraphics.DrawLine($razorOutline,12,43,52,43)

# Small central mounting slot and holes make it read as a razor/scraper blade.
$slotPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(95,98,103),2)
$razorGraphics.DrawLine($slotPen,25,20,39,20)
$razorGraphics.DrawLine($slotPen,25,24,39,24)
$razorGraphics.FillEllipse($razorHolder,17,20,5,5)
$razorGraphics.FillEllipse($razorHolder,42,20,5,5)

# Short holder strip behind the lower edge.
$razorGraphics.FillRectangle($razorHolder,16,43,32,7)
$razorGraphics.DrawRectangle($razorOutline,16,43,32,7)

$slotPen.Dispose()
$razorGraphics.Dispose()
$razorOutline.Dispose()
$razorSteel.Dispose()
$razorEdgeBrush.Dispose()
$razorHolder.Dispose()

$script:RazorIcon = [System.Drawing.Icon]::FromHandle($razorBitmap.GetHicon())

# ============================================================
# RETROBAT COLLECTION CLEANUP UTILITY
# ============================================================

function Show-RootSelectionDialog {
    param([string]$DefaultPath)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Icon = $script:RazorIcon
    $dialog.Text = "RCCU - RetroBat Collection Cleanup Utility - Select Root Directory"
    $dialog.Size = [System.Drawing.Size]::new(1120,430)
    $dialog.StartPosition = "CenterScreen"
    $dialog.TopMost = $true
    $dialog.ShowInTaskbar = $true
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Run from current directory, or choose the RetroBat root containing the ROMs and gamelist.xml:"
    $label.Location = [System.Drawing.Point]::new(15,15)
    $label.Size = [System.Drawing.Size]::new(1080,30)
    $label.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $label.AutoSize = $false
    $label.AutoEllipsis = $true
    $dialog.Controls.Add($label)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Text = [System.IO.Path]::GetFullPath($DefaultPath)
    $box.Location = [System.Drawing.Point]::new(15,50)
    $box.Size = [System.Drawing.Size]::new(920,38)
    $box.Font = [System.Drawing.Font]::new("Consolas",14,[System.Drawing.FontStyle]::Regular)
    $dialog.Controls.Add($box)

    $runCurrent = New-Object System.Windows.Forms.CheckBox
    $runCurrent.Text = "Run from current directory"
    $runCurrent.Location = [System.Drawing.Point]::new(15,96)
    $runCurrent.Size = [System.Drawing.Size]::new(330,30)
    $runCurrent.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $runCurrent.Checked = $true
    $runCurrent.Add_CheckedChanged({
        if ($runCurrent.Checked) { $box.Text = [System.IO.Path]::GetFullPath((Get-Location).Path) }
    })
    $dialog.Controls.Add($runCurrent)

    $browse = New-Object System.Windows.Forms.Button
    $browse.Text = "Browse..."
    $browse.Location = [System.Drawing.Point]::new(950,49)
    $browse.Size = [System.Drawing.Size]::new(135,40)
    $browse.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $browse.Add_Click({
        $folder = New-Object System.Windows.Forms.FolderBrowserDialog
        $folder.Description = "Select the RetroBat root directory"
        $folder.SelectedPath = $box.Text
        if ($folder.ShowDialog($dialog) -eq [System.Windows.Forms.DialogResult]::OK) {
            $runCurrent.Checked = $false
            $box.Text = $folder.SelectedPath
        }
        $folder.Dispose()
    })
    $dialog.Controls.Add($browse)

    $autoRecursive = New-Object System.Windows.Forms.CheckBox
    $autoRecursive.Text = "[DANGER] AUTOMATIC RECURSIVE ROOT - process every gamelist.xml directory sequentially AND YES TO EVERYTHING"
    $autoRecursive.Location = [System.Drawing.Point]::new(15,132)
    $autoRecursive.Size = [System.Drawing.Size]::new(1075,30)
    $autoRecursive.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($autoRecursive)

    $autoAll = New-Object System.Windows.Forms.CheckBox
    $autoAll.Text = "[DANGER] AUTOMATIC - YES TO EVERYTHING (all prompts are automatically accepted)"
    $autoAll.Location = [System.Drawing.Point]::new(15,163)
    $autoAll.Size = [System.Drawing.Size]::new(1075,30)
    $autoAll.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($autoAll)

    $warning = New-Object System.Windows.Forms.Label
    $warning.Text = "WARNING: Automatic mode can recycle/delete files, crop images, repair XML, and promote changes without asking. All file deletions still use RCCU's safe recycle/recovery system."
    $warning.Location = [System.Drawing.Point]::new(15,198)
    $warning.Size = [System.Drawing.Size]::new(1075,72)
    $warning.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
    $warning.AutoEllipsis = $true
    $dialog.Controls.Add($warning)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Use This Directory"
    $ok.Location = [System.Drawing.Point]::new(750,335)
    $ok.Size = [System.Drawing.Size]::new(210,46)
    $ok.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $ok.Add_Click({
        if ([string]::IsNullOrWhiteSpace($box.Text) -or -not (Test-Path -LiteralPath $box.Text -PathType Container)) {
            [System.Windows.Forms.MessageBox]::Show($dialog,"Please select an existing directory.","Invalid Directory",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $dialog.Tag = [pscustomobject]@{
            Root = [System.IO.Path]::GetFullPath($box.Text.Trim())
            AutomaticRecursive = [bool]$autoRecursive.Checked
            AutomaticYesAll = [bool]$autoAll.Checked
        }
        $dialog.Close()
    })
    $dialog.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = [System.Drawing.Point]::new(970,335)
    $cancel.Size = [System.Drawing.Size]::new(120,46)
    $cancel.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $cancel.Add_Click({ $dialog.Tag = $null; $dialog.Close() })
    $dialog.Controls.Add($cancel)
    $dialog.AcceptButton = $ok
    $dialog.CancelButton = $cancel
    $dialog.Add_Shown({
        $dialog.TopMost = $true
        $dialog.Activate()
        $dialog.BringToFront()
        $box.SelectAll()
        $box.Focus()
        Set-DarkTitleBar $dialog
    })

    # Dark mode is enabled before the initial directory popup is shown.
    Set-DarkThemeForForm $dialog

    $dialog.ShowDialog() | Out-Null
    $result = $dialog.Tag
    $dialog.Dispose()
    return $result
}

$DefaultRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { [System.IO.Path]::GetFullPath($PSScriptRoot) } else { (Get-Location).Path }
$rootSelection = Show-RootSelectionDialog $DefaultRoot
if ($null -eq $rootSelection) { return }
$Root = [string]$rootSelection.Root
$script:AutomaticRecursiveRoot = [bool]$rootSelection.AutomaticRecursive
$script:AutomaticYesAll = [bool]($rootSelection.AutomaticYesAll -or $rootSelection.AutomaticRecursive)

# Determine the recycle strategy once before any cleanup begins.
# The function is declared later; PowerShell resolves function definitions before execution.

$RealXml = Join-Path $Root "gamelist.xml"
$TestXml = Join-Path $Root "gamelist_TEST.xml"
$DuplicateLog = Join-Path $Root "000-Duplicates.txt"
$UniformLog = Join-Path $Root "000-UniformImages.txt"
$MediaLog = Join-Path $Root "000-MediaAudit.txt"
$VerificationLog = Join-Path $Root "000-VerificationAudit.txt"
$OutputLog = Join-Path $Root "000-Output.txt"
$XmlChangesLog = Join-Path $Root "000-XMLChanges.txt"
$NormalizedGameListLog = Join-Path $Root "000-GameList.txt"
                $VideoNormalizationLog = Join-Path $Root "000-VideoNormalization.txt"

$UniformThreshold = 100
$GreenTolerance = 12

$Stage2Threads = [math]::Min(
    8,
    [math]::Max(
        2,
        [Environment]::ProcessorCount - 1
    )
)

# Parallel workers for CPU-heavy image/video analysis.  Video encoding gets
# fewer concurrent jobs because each FFmpeg process is itself multithreaded.
$Stage3Threads = $Stage2Threads
$Stage9Threads = [math]::Min(
    4,
    [math]::Max(
        2,
        [Environment]::ProcessorCount - 1
    )
)
$Stage9FfmpegThreadsPerJob = [math]::Max(1, [int][math]::Floor([Environment]::ProcessorCount / [double]$Stage9Threads))

$ImageExtensions = @(
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".bmp",
    ".gif",
    ".tif",
    ".tiff"
)

$MediaTagMap = @{
    "box2dback" = "box2dback"
    "box2dfront" = "box2dfront"
    "box2dside" = "box2dside"
    "box3d" = "box3d"
    "boxtexture" = "boxtexture"
    "fanart" = "fanart"
    "images" = "image"
    "manual" = "manual"
    "manuals" = "manual"
    "screenmarquee" = "screenmarquee"
    "screenmarqueesmall" = "screenmarqueesmall"
    "screenshot" = "screenshot"
    "screenshotlille" = "screenshotlille"
    "skraper" = "skraper"
    "steamgrid" = "steamgrid"
    "support" = "support"
    "supporttexture" = "supporttexture"
    "videos" = "video"
    "wheel" = "wheel"
    "wheelcarbon" = "wheelcarbon"
    "wheelsteel" = "wheelsteel"

    "marquee" = "marquee"
    "thumbnail" = "thumbnail"
    "thumbnails" = "thumbnail"
    "thumb" = "thumbnail"
    "snaps" = "snap"
    "snap" = "snap"
    "titles" = "title"
    "title" = "title"
    "covers" = "cover"
    "cover" = "cover"
    "back" = "back"
    "front" = "front"
    "clearlogo" = "clearlogo"
    "logo" = "logo"
    "logos" = "logo"
    "mix" = "mix"
    "miximages" = "miximage"
    "miximage" = "miximage"
    "artwork" = "artwork"
    "art" = "art"
    "maps" = "map"
    "map" = "map"
    "bezels" = "bezel"
    "bezel" = "bezel"
    "overlays" = "overlay"
    "overlay" = "overlay"
    "textures" = "texture"
    "texture" = "texture"
    "shaders" = "shader"
    "shader" = "shader"
}

$IgnoredSuffixes = @(
    "-map",
    "-bezel",
    "-overlay",
    "-texture",
    "-gametexture",
    "-screen-gametexture"
)

# ============================================================
# GUI
# ============================================================

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "RCCU - RetroBat Collection Cleanup Utility   |   v4.29"
$Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$Form.Size = [System.Drawing.Size]::new(1200,900)
$Form.StartPosition = "CenterScreen"
$Form.MinimumSize = [System.Drawing.Size]::new(1100,700)
$Form.ShowInTaskbar = $true
$Form.MinimizeBox = $true
$Form.MaximumSize = [System.Drawing.Size]::new(0,0)
$Form.MaximizeBox = $true

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "RetroBat Collection Cleanup Utility   —   v4.29"
$Title.Font = [System.Drawing.Font]::new("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$Title.Location = [System.Drawing.Point]::new(20,10)
$Title.Size = [System.Drawing.Size]::new(720,38)
$Title.AutoSize = $false
$Title.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$Form.Controls.Add($Title)

$ByLabel = New-Object System.Windows.Forms.Label
$ByLabel.Text = "by"
$ByLabel.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$ByLabel.Location = [System.Drawing.Point]::new(744,16)
$ByLabel.Size = [System.Drawing.Size]::new(32,26)
$ByLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$CutterLabel = New-Object System.Windows.Forms.Label
$CutterLabel.Text = "Cutter81"
$CutterLabel.Font = [System.Drawing.Font]::new("Segoe UI",12,[System.Drawing.FontStyle]::Italic)
$CutterLabel.Location = [System.Drawing.Point]::new(780,11)
$CutterLabel.Size = [System.Drawing.Size]::new(180,32)
$CutterLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$Form.Controls.Add($CutterLabel)
$Form.Controls.Add($ByLabel)
$ByLabel.BringToFront()

$AuthorLabel = New-Object System.Windows.Forms.Label
$AuthorLabel.Text = ""
$AuthorLabel.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$AuthorLabel.Location = [System.Drawing.Point]::new(20,49)
$AuthorLabel.AutoSize = $true
$Form.Controls.Add($AuthorLabel)

$PathLabel = New-Object System.Windows.Forms.Label
$PathLabel.Text = "System: $Root"
$PathLabel.Location = [System.Drawing.Point]::new(20,53)
$PathLabel.Size = [System.Drawing.Size]::new(1050,28)
$PathLabel.AutoEllipsis = $true
$Form.Controls.Add($PathLabel)

$StagePanel = New-Object System.Windows.Forms.Panel
$StagePanel.Location = [System.Drawing.Point]::new(15,88)
$StagePanel.Size = [System.Drawing.Size]::new(895,680)
$StagePanel.AutoScroll = $true
$StagePanel.HorizontalScroll.Enabled = $true
$StagePanel.HorizontalScroll.Visible = $true
$StagePanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$Form.Controls.Add($StagePanel)

$OutputLabel = New-Object System.Windows.Forms.Label
$OutputLabel.Text = "Current status"
$OutputLabel.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$OutputLabel.Location = [System.Drawing.Point]::new(20,770)
$OutputLabel.Size = [System.Drawing.Size]::new(180,26)
$OutputLabel.AutoSize = $false
$OutputLabel.AutoEllipsis = $false
$OutputLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$OutputLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($OutputLabel)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Idle"
$StatusLabel.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Regular)
$StatusLabel.Location = [System.Drawing.Point]::new(20,797)
$StatusLabel.Size = [System.Drawing.Size]::new(875,50)
$StatusLabel.AutoEllipsis = $true
$StatusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($StatusLabel)
$script:StatusLabel = $StatusLabel

$StartButton = New-Object System.Windows.Forms.Button
$StartButton.Text = "START"
$StartButton.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$StartButton.Size = [System.Drawing.Size]::new(110,32)
$StartButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$StartButton.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($StartButton)

$StopButton = New-Object System.Windows.Forms.Button
$StopButton.Text = "STOP"
$StopButton.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$StopButton.Size = [System.Drawing.Size]::new(110,32)
$StopButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$StopButton.Enabled = $false
$StopButton.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($StopButton)

$StartOverButton = New-Object System.Windows.Forms.Button
$StartOverButton.Text = "START OVER"
$StartOverButton.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$StartOverButton.Size = [System.Drawing.Size]::new(130,32)
$StartOverButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$StartOverButton.Enabled = $false
$StartOverButton.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($StartOverButton)

$PauseButton = New-Object System.Windows.Forms.Button
$PauseButton.Text = "PAUSE"
$PauseButton.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$PauseButton.Size = [System.Drawing.Size]::new(110,32)
$PauseButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$PauseButton.Enabled = $false
$PauseButton.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($PauseButton)

$OpenSourceLabel = New-Object System.Windows.Forms.Label
$OpenSourceLabel.Text = "Open Source"
$OpenSourceLabel.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$OpenSourceLabel.Size = [System.Drawing.Size]::new(125,28)
$OpenSourceLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$OpenSourceLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
$Form.Controls.Add($OpenSourceLabel)

$DarkModeCheck = New-Object System.Windows.Forms.CheckBox
$DarkModeCheck.Text = "Dark mode"
$DarkModeCheck.Location = [System.Drawing.Point]::new(780,875)
$DarkModeCheck.Size = [System.Drawing.Size]::new(125,28)
$DarkModeCheck.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$DarkModeCheck.Checked = $true
$script:MainDarkModeState = $true
$Form.Controls.Add($DarkModeCheck)

# ------------------------------------------------------------
# APPLICATION ICON
# ------------------------------------------------------------
$Form.Icon = $script:RazorIcon

# ------------------------------------------------------------
# SINGLE-WINDOW SPLIT UI
# ------------------------------------------------------------
# The utility is deliberately one top-level window.  The existing
# cleanup UI remains on the left and the live output is a child
# control on the right.  There is no second output Form and no window
# ownership/z-order relationship to fight with PowerShell ISE.
$MainSplit = New-Object System.Windows.Forms.SplitContainer
$MainSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$MainSplit.Orientation = [System.Windows.Forms.Orientation]::Vertical
$MainSplit.SplitterWidth = 6
$MainSplit.IsSplitterFixed = $false
# Do not set large minimum panel sizes while the SplitContainer still has
# its design-time/default width.  WinForms validates the minimums immediately
# and can throw before the fullscreen form has been sized.
$MainSplit.Panel1MinSize = 0
$MainSplit.Panel2MinSize = 0
$Form.Controls.Add($MainSplit)
# SplitterDistance is intentionally assigned only after the form has its
# real fullscreen client width.  Never assign a design-time distance here.
$MainSplit.BringToFront()

# Move the complete existing cleanup UI into the left pane without
# rebuilding any of its controls or stage definitions.
$leftControls = @(
    $Title,
    $ByLabel,
    $CutterLabel,
    $AuthorLabel,
    $PathLabel,
    $StagePanel,
    $OutputLabel,
    $StatusLabel,
    $StartButton,
    $StopButton,
    $StartOverButton,
    $PauseButton,
    $OpenSourceLabel,
    $DarkModeCheck
)
foreach ($control in $leftControls) {
    $Form.Controls.Remove($control)
    $MainSplit.Panel1.Controls.Add($control)
}

$OutputTitle = New-Object System.Windows.Forms.Label
$OutputTitle.Text = "Full live output"
$OutputTitle.Font = [System.Drawing.Font]::new("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$OutputTitle.Location = [System.Drawing.Point]::new(12,8)
$OutputTitle.Size = [System.Drawing.Size]::new(300,24)
$OutputTitle.AutoSize = $false
$OutputTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$MainSplit.Panel2.Controls.Add($OutputTitle)

$OutputBox = New-Object System.Windows.Forms.RichTextBox
$OutputBox.Location = [System.Drawing.Point]::new(10,44)
$OutputBox.Size = [System.Drawing.Size]::new(580,850)
$OutputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$OutputBox.ReadOnly = $true
$OutputBox.WordWrap = $false
$OutputBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
$OutputBox.Font = [System.Drawing.Font]::new("Consolas",11,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point)
$OutputBox.ZoomFactor = 1.0
$OutputBox.ContextMenuStrip = $null
$OutputCopyTip = New-Object System.Windows.Forms.ToolTip
$OutputCopyTip.AutoPopDelay = 1800
$OutputCopyTip.InitialDelay = 0
$OutputCopyTip.ReshowDelay = 0
$OutputCopyTip.ShowAlways = $true
$OutputBox.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$OutputBox.ForeColor = [System.Drawing.Color]::WhiteSmoke
# Right-clicking a detected file link opens a small file-action menu.
# Normal right-clicks elsewhere in the output remain inert; Ctrl+C still works
# normally for selected text.
$script:OutputContextPath = $null
$script:OutputContextSelectedText = $null
$script:OutputContextAction = $null
$script:OutputContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$script:OutputContextMenu.ShowImageMargin = $false

$copyFileItem = $script:OutputContextMenu.Items.Add("Copy name and location to clipboard")
$openFileItem = $script:OutputContextMenu.Items.Add("Open file")
$openDirItem = $script:OutputContextMenu.Items.Add("Open directory and highlight file")
$copySelectionItem = $script:OutputContextMenu.Items.Add("Copy selected text")

$copyFileItem.Add_Click({
    try {
        $path = [string]$script:OutputContextPath
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $fileName = [System.IO.Path]::GetFileName($path)
            $fullPath = [System.IO.Path]::GetFullPath($path)
            [System.Windows.Forms.Clipboard]::SetText(("Name: {0}`r`nLocation: {1}" -f $fileName,$fullPath))
            if ($null -ne $script:StatusLabel) { $script:StatusLabel.Text = "Copied file name and location to clipboard." }
        }
    }
    catch {
        if ($null -ne $script:StatusLabel) { $script:StatusLabel.Text = "Could not copy file information: $($_.Exception.Message)" }
    }
    finally { $script:OutputContextMenu.Hide() }
})

$openFileItem.Add_Click({
    try {
        $path = [string]$script:OutputContextPath
        if (-not [string]::IsNullOrWhiteSpace($path)) { Open-OutputFilePath $path }
    }
    catch {}
    finally { $script:OutputContextMenu.Hide() }
})

$openDirItem.Add_Click({
    try {
        $path = [string]$script:OutputContextPath
        if (-not [string]::IsNullOrWhiteSpace($path)) { Open-PathInExplorerHighlight $path }
    }
    catch {}
    finally { $script:OutputContextMenu.Hide() }
})

$copySelectionItem.Add_Click({
    try {
        $selected = [string]$script:OutputContextSelectedText
        if (-not [string]::IsNullOrEmpty($selected)) {
            [System.Windows.Forms.Clipboard]::SetText($selected)
            if ($null -ne $script:StatusLabel) { $script:StatusLabel.Text = "Copied selected text to clipboard." }
        }
    }
    catch {
        if ($null -ne $script:StatusLabel) { $script:StatusLabel.Text = "Could not copy selected text: $($_.Exception.Message)" }
    }
    finally { $script:OutputContextMenu.Hide() }
})

$OutputBox.Add_MouseUp({
    param($sender,$e)

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        try {
            $script:OutputContextPath = $null
            $script:OutputContextSelectedText = [string]$sender.SelectedText

            $charIndex = $sender.GetCharIndexFromPosition($e.Location)
            $link = Get-OutputLinkAtPosition $charIndex

            if ($null -ne $link) {
                $script:OutputContextPath = [string]$link.Path
                $script:OutputContextSelectedText = $null
                $copyFileItem.Visible = $true
                $openFileItem.Visible = $true
                $openDirItem.Visible = $true
                $copySelectionItem.Visible = $false
                $script:OutputContextMenu.Show($sender,$e.Location)
            }
            elseif (-not [string]::IsNullOrEmpty($script:OutputContextSelectedText)) {
                $copyFileItem.Visible = $false
                $openFileItem.Visible = $false
                $openDirItem.Visible = $false
                $copySelectionItem.Visible = $true
                $script:OutputContextMenu.Show($sender,$e.Location)
            }
        }
        catch {
        }
        return
    }

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        try {
            $charIndex = $sender.GetCharIndexFromPosition($e.Location)
            $link = Get-OutputLinkAtPosition $charIndex
            if ($null -ne $link) {
                Open-OutputFilePath $link.Path
            }
        }
        catch {
        }
    }
})

$OutputBox.Add_MouseMove({
    param($sender,$e)

    try {
        $charIndex = $sender.GetCharIndexFromPosition($e.Location)
        $link = Get-OutputLinkAtPosition $charIndex
        if ($null -ne $link) {
            $sender.Cursor = [System.Windows.Forms.Cursors]::Hand
        }
        else {
            $sender.Cursor = [System.Windows.Forms.Cursors]::IBeam
        }
    }
    catch {
        $sender.Cursor = [System.Windows.Forms.Cursors]::IBeam
    }
})
$MainSplit.Panel2.Controls.Add($OutputBox)

# Keep RichTextBox text at one fixed size. Ctrl+mouse-wheel must not zoom it.
$OutputBox.Add_MouseWheel({
    if ([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) {
        $OutputBox.ZoomFactor = 1.0
        $OutputBox.Font = [System.Drawing.Font]::new("Consolas",11,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point)
    }
})

$OutputHint = New-Object System.Windows.Forms.Label
$OutputHint.Text = "Everything displayed here is also saved to 000-Output.txt"
$OutputHint.Location = [System.Drawing.Point]::new(12,895)
$OutputHint.Size = [System.Drawing.Size]::new(580,25)
$OutputHint.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
$MainSplit.Panel2.Controls.Add($OutputHint)

$Stages = @{}
$StageSkipRequested = @{}
$StageY = 10

function Add-Stage {
    param(
        [int]$Number,
        [string]$Name
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = [System.Drawing.Point]::new(5,$script:StageY)
    $panel.Size = [System.Drawing.Size]::new(850,100)
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Stage $Number - $Name"
    $label.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $runCheck = New-Object System.Windows.Forms.CheckBox
    $runCheck.Text = ""
    $runCheck.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Regular)
    $runCheck.Location = [System.Drawing.Point]::new(8,6)
    $runCheck.Size = [System.Drawing.Size]::new(22,28)
    $runCheck.Checked = $true
    $panel.Controls.Add($runCheck)

    $label.Location = [System.Drawing.Point]::new(38,6)
    $label.Size = [System.Drawing.Size]::new(590,30)
    $label.AutoSize = $false
    $label.AutoEllipsis = $false
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $panel.Controls.Add($label)

    $percent = New-Object System.Windows.Forms.Label
    $percent.Text = "0%"
    $percent.Location = [System.Drawing.Point]::new(780,6)
    $percent.Size = [System.Drawing.Size]::new(70,30)
    $percent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $panel.Controls.Add($percent)

    $skip = New-Object System.Windows.Forms.Button
    $skip.Text = "SKIP"
    $skip.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $skip.Location = [System.Drawing.Point]::new(740,37)
    $skip.Size = [System.Drawing.Size]::new(105,30)

    $skip.Tag = $Number

    $skip.Add_Click({
        $stageNumber = [int]$this.Tag
        $script:StageSkipRequested[$stageNumber] = $true
        $this.Enabled = $false
        $script:StatusLabel.Text = "Skip requested for Stage $stageNumber."
        [System.Windows.Forms.Application]::DoEvents()
    })

    $panel.Controls.Add($skip)

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Location = [System.Drawing.Point]::new(10,37)
    $bar.Size = [System.Drawing.Size]::new(720,20)
    $bar.Minimum = 0
    $bar.Maximum = 100
    $bar.Value = 0
    $panel.Controls.Add($bar)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "Waiting..."
    $info.Location = [System.Drawing.Point]::new(10,69)
    $info.Size = [System.Drawing.Size]::new(815,20)
    $info.AutoEllipsis = $true
    $panel.Controls.Add($info)

    $script:StagePanel.Controls.Add($panel)

    $script:Stages[$Number] = @{
        Panel = $panel
        Label = $label
        Run = $runCheck
        Percent = $percent
        Bar = $bar
        Info = $info
        Skip = $skip
    }

    $script:StageSkipRequested[$Number] = $false
    $script:StageY += 100
}

Add-Stage 1 "File & Folder Permissions"
Add-Stage 2 "Duplicate ROM Review"
Add-Stage 3 "Empty / Uniform Image Scan"
Add-Stage 4 "Black-Bar Image Review"
Add-Stage 5 "Video Normalization"
Add-Stage 6 "Stale XML Audit"
Add-Stage 7 "Media Audit"
Add-Stage 8 "XML Repair"
Add-Stage 9 "Final Verification & Promotion"

# Manual mode: permission repair and video normalization are opt-in.
# Automatic mode from the first window enables both automatically.
if (-not $script:AutomaticYesAll) {
    $script:Stages[1].Run.Checked = $false
    $script:Stages[5].Run.Checked = $false
}

function Wait-IfPaused {
    while ($script:MaintenanceRunning -and $script:Paused -and -not $script:StopRequested) {
        $StatusLabel.Text = "Paused."
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(100)
    }
}

function Update-Stage {
    param(
        [int]$Number,
        [int]$Percent,
        [string]$Info
    )

    if ($Percent -lt 0) {
        $Percent = 0
    }

    if ($Percent -gt 100) {
        $Percent = 100
    }

    $s = $script:Stages[$Number]

    $s.Bar.Value = $Percent
    $s.Percent.Text = "$Percent%"
    $s.Info.Text = $Info

    if (
        $script:StageSkipRequested.ContainsKey($Number) -and
        $script:StageSkipRequested[$Number]
    ) {
        $baseName = $s.Label.Text -replace " - RUNNING$",""
        $baseName = $baseName -replace " - COMPLETE$",""
        $baseName = $baseName -replace " - SKIPPED$",""
        $s.Label.Text = "$baseName - SKIPPED"
        $s.Skip.Enabled = $false
    }
    elseif ($Percent -lt 100) {
        $baseName = $s.Label.Text -replace " - RUNNING$",""
        $baseName = $baseName -replace " - COMPLETE$",""
        $baseName = $baseName -replace " - SKIPPED$",""
        $s.Label.Text = "$baseName - RUNNING"
    }
    else {
        $baseName = $s.Label.Text -replace " - RUNNING$",""
        $baseName = $baseName -replace " - COMPLETE$",""
        $baseName = $baseName -replace " - SKIPPED$",""
        $s.Label.Text = "$baseName - COMPLETE"
        $s.Skip.Enabled = $false
    }

    $script:StatusLabel.Text = $Info

    [System.Windows.Forms.Application]::DoEvents()
    Wait-IfPaused
}

function Set-StageSkipped {
    param(
        [int]$Number,
        [string]$Info
    )

    $s = $script:Stages[$Number]

    $s.Skip.Enabled = $false
    $s.Percent.Text = "SKIP"
    $s.Info.Text = $Info

    $baseName = $s.Label.Text -replace " - RUNNING$",""
    $baseName = $baseName -replace " - COMPLETE$",""
    $baseName = $baseName -replace " - SKIPPED$",""

    $s.Label.Text = "$baseName - SKIPPED"

    $script:StatusLabel.Text = $Info

    [System.Windows.Forms.Application]::DoEvents()
}

# ============================================================
# GENERAL HELPERS
# ============================================================

Add-Type -AssemblyName Microsoft.VisualBasic

# Recycle strategy is determined once per processing root/drive instead of
# probing Windows Recycle Bin for every single deleted file.  A failed Windows
# Recycle Bin attempt permanently switches the current drive to the safe RCCU
# recovery bin for the remainder of the run.
$script:RecycleMode = 'Uninitialized'       # WINDOWS or RCCU
$script:RecycleRoot = $null
$script:RecycleDriveRoot = $null
$script:RecycleError = $null
$script:RecycleCreatedDirectories = @{}
$script:RecycleLogWriter = $null

function Initialize-RecycleStrategy {
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
    $driveRoot = [System.IO.Path]::GetPathRoot($fullRoot)
    if ([string]::IsNullOrWhiteSpace($driveRoot)) {
        throw "Could not determine drive root for cleanup root: $fullRoot"
    }

    $driveInfo = [System.IO.DriveInfo]::new($driveRoot)
    $script:RecycleDriveRoot = $driveRoot
    $script:RecycleRoot = Join-Path $driveRoot 'RCCU_RecycleBin'
    $script:RecycleError = $null
    $script:RecycleCreatedDirectories = @{}

    if ($driveInfo.DriveType -eq [System.IO.DriveType]::Removable) {
        # Never use Windows Recycle Bin on removable/SD media.  It can appear
        # to accept a recycle request while still permanently deleting files.
        $script:RecycleMode = 'RCCU'
        $script:RecycleError = 'Removable volume; RCCU recovery bin selected at startup.'
    }
    else {
        # Fixed/network/etc. drives start with the normal Windows Recycle Bin.
        # If the first real recycle operation fails, Move-FileToRecycleBin
        # switches the cached mode to RCCU so every later file avoids the same
        # failed Windows check.
        $script:RecycleMode = 'WINDOWS'
    }

    Write-Host "Recycle strategy initialized: $($script:RecycleMode)"
    Write-Host "Recycle/recovery root: $($script:RecycleRoot)"
}

# Fast recovery-bin path: removable media never uses the Windows Shell
# recycle operation. Files are moved directly within the same volume while
# preserving their complete relative path.
function Move-FileToRecycleBin {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found for recycle operation: $Path"
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($fullPath)

    # The strategy is initialized when each processing root starts.  This is a
    # safety fallback for any unusual call made before that initialization.
    if ($script:RecycleMode -eq 'Uninitialized' -or
        $script:RecycleDriveRoot -ne $root) {
        Initialize-RecycleStrategy -RootPath $fullPath
    }

    if ($script:RecycleMode -eq 'WINDOWS') {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $fullPath,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
            return
        }
        catch {
            # Cache the failure.  Do not make every subsequent deletion pay
            # the cost of another Windows Recycle Bin attempt.
            $script:RecycleError = $_.Exception.Message
            $script:RecycleMode = 'RCCU'
            Write-Host "Windows Recycle Bin unavailable on $root; switching to RCCU recovery bin for the rest of this drive."
        }
    }

    try {
        if ([string]::IsNullOrWhiteSpace($script:RecycleRoot)) {
            throw "RCCU recovery root is not initialized."
        }

        # RCCU's fallback bin lives on the same drive, so moving the file is
        # reversible and preserves the complete original relative path.
        $fallbackRoot = $script:RecycleRoot
        $relative = $fullPath.Substring($root.Length).TrimStart('\')
        $destination = Join-Path $fallbackRoot $relative
        $destinationDir = Split-Path -Parent $destination

        # Directory.CreateDirectory is substantially cheaper than invoking the
        # PowerShell provider for every abandoned file. Cache directories we
        # have already created so large media cleanups do not repeatedly touch
        # the filesystem just to verify the same destination exists.
        if (-not $script:RecycleCreatedDirectories.ContainsKey($destinationDir)) {
            if (-not [System.IO.Directory]::Exists($destinationDir)) {
                [System.IO.Directory]::CreateDirectory($destinationDir) | Out-Null
            }
            $script:RecycleCreatedDirectories[$destinationDir] = $true
        }

        if ([System.IO.File]::Exists($destination)) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($destination)
            $ext  = [System.IO.Path]::GetExtension($destination)
            $n = 1
            do {
                $candidate = Join-Path $destinationDir ("{0} (RCCU {1}){2}" -f $base,$n,$ext)
                $n++
            } while ([System.IO.File]::Exists($candidate))
            $destination = $candidate
        }

        # Same-volume move: use .NET directly instead of the PowerShell
        # provider. This avoids a large amount of provider overhead when RCCU
        # is recycling hundreds/thousands of abandoned media files.
        [System.IO.File]::Move($fullPath, $destination)

        # Keep the recovery log, but append with .NET rather than invoking the
        # Add-Content cmdlet for every file. The log is intentionally opened
        # only for this write so the file remains immediately readable/recoverable.
        $manifest = Join-Path $fallbackRoot 'RCCU_RecycleBin_Log.txt'
        $logLine = "{0} | ORIGINAL={1} | STORED={2} | WINDOWS_RECYCLE_BIN_ERROR={3}" -f `
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $fullPath, $destination, $script:RecycleError
        [System.IO.File]::AppendAllText($manifest, $logLine + [Environment]::NewLine)

        # Only announce the switch once; individual deletions stay quiet.
        if ($script:RecycleError -and $script:RecycleError -ne 'Removable volume; RCCU recovery bin selected at startup.') {
            # The switch message was already printed above.
        }
    }
    catch {
        throw "RCCU could not safely recover the file. Original Windows Recycle Bin error: $script:RecycleError | Recovery error: $($_.Exception.Message)"
    }
}

function Get-RccuCurrentUserName {
    try { return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
    catch { throw "Could not determine the current Windows user: $($_.Exception.Message)" }
}

function Test-RccuUserModifyAccess {
    param([string]$Path,[string]$UserName)
    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $userSid = ([System.Security.Principal.NTAccount]$UserName).Translate([System.Security.Principal.SecurityIdentifier])
        $allowModify = $false
        $denyModify = $false
        foreach ($rule in $acl.Access) {
            try { $ruleSid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) } catch { continue }
            if ($ruleSid.Value -ne $userSid.Value) { continue }
            $rights = [System.Security.AccessControl.FileSystemRights]$rule.FileSystemRights
            if (($rights -band [System.Security.AccessControl.FileSystemRights]::Modify) -ne 0 -or
                ($rights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) {
                if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) { $denyModify = $true }
                elseif ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) { $allowModify = $true }
            }
        }
        $ownerMatches = $false
        try {
            $ownerSid = ([System.Security.Principal.NTAccount]$acl.Owner).Translate([System.Security.Principal.SecurityIdentifier])
            $ownerMatches = ($ownerSid.Value -eq $userSid.Value)
        } catch { $ownerMatches = ($acl.Owner -ieq $UserName) }
        return [pscustomobject]@{ Path=$Path; OwnerMatches=$ownerMatches; ModifyAllow=$allowModify; ModifyDeny=$denyModify; Sufficient=($ownerMatches -and $allowModify -and -not $denyModify) }
    }
    catch {
        return [pscustomobject]@{ Path=$Path; OwnerMatches=$false; ModifyAllow=$false; ModifyDeny=$false; Sufficient=$false; Error=$_.Exception.Message }
    }
}

function Get-RccuPermissionItems {
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add([System.IO.Path]::GetFullPath($Root))
    foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-IsRccuRecoveryPath $_.FullName) })) {
        [void]$items.Add([System.IO.Path]::GetFullPath($dir.FullName))
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-IsRccuRecoveryPath $_.FullName) })) {
        [void]$items.Add([System.IO.Path]::GetFullPath($file.FullName))
    }
    return @($items)
}

function Invoke-FileFolderPermissions {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 2 - FILE & FOLDER PERMISSIONS"
    Write-Host "============================================================"
    $currentUser = Get-RccuCurrentUserName
    Write-Host "Current Windows user: $currentUser"
    Write-Host "Checking ownership and Modify access recursively under: $Root"
    $items = @(Get-RccuPermissionItems)
    $total = $items.Count
    $bad = New-Object System.Collections.Generic.List[object]
    $checked = 0
    foreach ($item in $items) {
        if ($script:StopRequested) { return $false }
        Wait-IfPaused
        $result = Test-RccuUserModifyAccess -Path $item -UserName $currentUser
        if (-not $result.Sufficient) { [void]$bad.Add($result) }
        $checked++
        Update-Stage 1 ([int](($checked / [double][math]::Max(1,$total)) * 100)) "Checking permissions $checked of $total"
    }
    if ($bad.Count -eq 0) {
        Update-Stage 1 100 "Permissions OK. $total items checked for $currentUser."
        Write-Host "Permissions already meet the required ownership/Modify check for $currentUser."
        return $true
    }
    Write-Host "Permission problems found: $($bad.Count) of $total items."
    $answer = [System.Windows.Forms.DialogResult]::Yes
    if (-not $script:AutomaticYesAll) {
        $answer = [System.Windows.Forms.MessageBox]::Show($Form,
            "RCCU found $($bad.Count) permission problem(s).`r`n`r`nCurrent user: $currentUser`r`n`r`nRepair ownership and grant Modify access recursively?",
            "Repair File & Folder Permissions",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    }
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        Update-Stage 1 100 "Permission repair declined. Stage 2 will not be allowed to start."
        return $false
    }
    Update-Stage 1 0 "Repairing ownership and Modify access..."
    $ownerOutput = & icacls.exe $Root /setowner $currentUser /T /C 2>&1
    $ownerExit = $LASTEXITCODE
    $ownerOutput | ForEach-Object { Write-Host $_ }
    $grantSpec = "$($currentUser):(OI)(CI)M"
    $grantOutput = & icacls.exe $Root /grant $grantSpec /T /C 2>&1
    $grantExit = $LASTEXITCODE
    $grantOutput | ForEach-Object { Write-Host $_ }
    Write-Host "icacls owner exit code: $ownerExit; Modify grant exit code: $grantExit"

    $remaining = 0
    $checked = 0
    foreach ($item in $items) {
        if ($script:StopRequested) { return $false }
        Wait-IfPaused
        if (-not (Test-RccuUserModifyAccess -Path $item -UserName $currentUser).Sufficient) { $remaining++ }
        $checked++
        Update-Stage 1 ([int](($checked / [double][math]::Max(1,$total)) * 100)) "Verifying repaired permissions $checked of $total"
    }
    if ($remaining -gt 0) {
        Update-Stage 1 100 "FAILED. $remaining item(s) still do not meet the required ownership/Modify check."
        Write-Host "PERMISSION CHECK FAILED: $remaining item(s) remain."
        return $false
    }
    Update-Stage 1 100 "Permissions repaired and verified for $currentUser. $total items checked."
    Write-Host "Permission repair complete and verified for $currentUser."
    return $true
}

function Test-RccuPermissionsPrerequisite {
    $currentUser = Get-RccuCurrentUserName
    foreach ($item in @(Get-RccuPermissionItems)) {
        if (-not (Test-RccuUserModifyAccess -Path $item -UserName $currentUser).Sufficient) { return $false }
    }
    return $true
}

function Test-StageSelected {
    param([int]$Number)
    if (-not $script:Stages.ContainsKey($Number)) { return $false }
    return [bool]$script:Stages[$Number].Run.Checked
}


$script:OutputFileLinks = New-Object System.Collections.ArrayList

function Get-OutputFileLinkCandidates {
    param([string]$Line)

    $result = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Line)) {
        return @()
    }

    # Absolute Windows paths.  The pipe character is deliberately excluded
    # because the utility uses "|" as a readable field separator in output.
    $absolutePattern = '(?<path>[A-Za-z]:\\[^<>:"|?*\r\n]+)'
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($Line,$absolutePattern)) {
        $candidate = $match.Groups["path"].Value.Trim()
        $candidate = $candidate.TrimEnd([char[]]@('.',',',';'))
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            [void]$result.Add(
                [PSCustomObject]@{
                    Start = $match.Groups["path"].Index
                    Length = $candidate.Length
                    Path = [System.IO.Path]::GetFullPath($candidate)
                }
            )
        }
    }

    # Relative RetroBat paths and recognized media paths.  Resolve them
    # against the selected RetroBat root before making them clickable.
    $relativePattern = '(?<path>(?:\./|\.\\|images[\\/]|media[\\/]|box2dback[\\/]|box2dfront[\\/]|box2dside[\\/]|box3d[\\/]|boxtexture[\\/]|fanart[\\/]|manual[\\/]|manuals[\\/]|videos[\\/]|marquee[\\/]|thumbnail[s]?[\\/]|thumb[\\/]|snap[s]?[\\/]|title[s]?[\\/]|cover[s]?[\\/]|back[\\/]|front[\\/]|clearlogo[\\/]|logo[s]?[\\/]|mix(?:image|images)?[\\/]|artwork[\\/]|maps?[\\/]|bezel[s]?[\\/]|overlay[s]?[\\/]|texture[s]?[\\/]|shader[s]?[\\/]|wheel(?:carbon|steel)?[\\/]|screenmarquee(?:small)?[\\/]|screenshot(?:lille)?[\\/]|skraper[\\/]|steamgrid[\\/]|support(?:texture)?[\\/])[^|<>?\r\n]+)'
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($Line,$relativePattern,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $candidate = $match.Groups["path"].Value.Trim()
        $candidate = $candidate.TrimEnd([char[]]@('.',',',';'))
        $candidate = $candidate.Trim()

        $resolved = $null
        try {
            $resolved = Resolve-XmlPath $candidate
        }
        catch {
            $resolved = $null
        }

        if ($null -ne $resolved -and (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            [void]$result.Add(
                [PSCustomObject]@{
                    Start = $match.Groups["path"].Index
                    Length = $candidate.Length
                    Path = [System.IO.Path]::GetFullPath($resolved)
                }
            )
        }
    }

    # De-duplicate overlapping candidates and prefer the longest valid path.
    return @(
        $result |
        Sort-Object Start,@{Expression={$_.Length};Descending=$true} |
        ForEach-Object {
            $candidate = $_
            $overlap = $false

            foreach ($existing in @($result | Where-Object { $_ -ne $candidate })) {
                if (
                    $candidate.Start -lt ($existing.Start + $existing.Length) -and
                    $existing.Start -lt ($candidate.Start + $candidate.Length)
                ) {
                    if ($existing.Length -ge $candidate.Length) {
                        $overlap = $true
                        break
                    }
                }
            }

            if (-not $overlap) {
                $candidate
            }
        } |
        Sort-Object Start
    )
}

function Open-OutputFilePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return
        }

        # Hand the file directly to the normal Windows shell association.
        # This is the same Windows-level behavior used when a full file path
        # is entered into Explorer's address bar and opened.
        Start-Process -FilePath $Path | Out-Null
    }
    catch {
        try {
            # Fallback only: ask Explorer to open the file.
            [System.Diagnostics.Process]::Start(
                "explorer.exe",
                ('"{0}"' -f $Path)
            ) | Out-Null
        }
        catch {
        }
    }
}

function Get-OutputLinkAtPosition {
    param([int]$CharacterIndex)

    foreach ($link in @($script:OutputFileLinks)) {
        if (
            $CharacterIndex -ge $link.Start -and
            $CharacterIndex -lt ($link.Start + $link.Length)
        ) {
            return $link
        }
    }

    return $null
}

function Append-OutputPane {
    param([string]$Text)

    if ($null -eq $OutputBox) {
        return
    }

    $line = [string]$Text

    $color = [System.Drawing.Color]::WhiteSmoke
    if ($line -match 'FATAL|FAILED|ERROR') { $color = [System.Drawing.Color]::LightCoral }
    elseif ($line -match 'DELETED|DELETE|REMOVING|REMOVED') { $color = [System.Drawing.Color]::Orange }
    elseif ($line -match 'ADDED|Added|COMPLETE|CLEAN|PROMOTION COMPLETE') { $color = [System.Drawing.Color]::LightGreen }
    elseif ($line -match 'STAGE|====') { $color = [System.Drawing.Color]::DeepSkyBlue }
    elseif ($line -match 'SKIP|SKIPPED|KEPT') { $color = [System.Drawing.Color]::Khaki }

    # Save the user's actual vertical viewport before changing the text.
    # RichTextBox.SelectionStart/ScrollToCaret is NOT sufficient here: changing
    # the selection while appending can force the viewport back to the bottom.
    $wasAtBottom = $true
    $savedFirstVisibleLine = 0

    if ($OutputBox.TextLength -gt 0) {
        try {
            $savedFirstVisibleLine = [int][RCCURichEditApi]::SendMessage(
                $OutputBox.Handle,
                [RCCURichEditApi]::EM_GETFIRSTVISIBLELINE,
                [IntPtr]::Zero,
                [IntPtr]::Zero
            )

            $bottomPoint = New-Object System.Drawing.Point(
                4,
                [int][math]::Max(4,$OutputBox.ClientSize.Height - 8)
            )
            $bottomChar = $OutputBox.GetCharIndexFromPosition($bottomPoint)
            $wasAtBottom = ($bottomChar -ge [int][math]::Max(0,$OutputBox.TextLength - 5))
        }
        catch {
            $wasAtBottom = $true
            $savedFirstVisibleLine = 0
        }
    }

    $lineStart = $OutputBox.TextLength

    $OutputBox.SelectionStart = $lineStart
    $OutputBox.SelectionLength = 0
    $OutputBox.SelectionColor = $color
    $OutputBox.SelectionFont = New-Object System.Drawing.Font(
        "Consolas",
        11,
        [System.Drawing.FontStyle]::Regular,
        [System.Drawing.GraphicsUnit]::Point
    )
    $OutputBox.AppendText($line + [Environment]::NewLine)

    $candidates = @(Get-OutputFileLinkCandidates $line)

    foreach ($candidate in $candidates) {

        $absoluteStart = $lineStart + [int]$candidate.Start
        $absoluteLength = [int]$candidate.Length

        if ($absoluteLength -le 0) {
            continue
        }

        [void]$script:OutputFileLinks.Add(
            [PSCustomObject]@{
                Start = $absoluteStart
                Length = $absoluteLength
                Path = $candidate.Path
            }
        )

        $OutputBox.Select($absoluteStart,$absoluteLength)
        $OutputBox.SelectionColor = [System.Drawing.Color]::DeepSkyBlue
        $OutputBox.SelectionFont = New-Object System.Drawing.Font(
            "Consolas",
            11,
            [System.Drawing.FontStyle]::Underline,
            [System.Drawing.GraphicsUnit]::Point
        )
    }

    $OutputBox.SelectionStart = $OutputBox.TextLength
    $OutputBox.SelectionLength = 0
    $OutputBox.SelectionColor = $OutputBox.ForeColor
    $OutputBox.SelectionFont = New-Object System.Drawing.Font(
        "Consolas",
        11,
        [System.Drawing.FontStyle]::Regular,
        [System.Drawing.GraphicsUnit]::Point
    )

    if ($wasAtBottom) {
        # At the bottom: continue following live output.
        $OutputBox.ScrollToCaret()
    }
    else {
        # User was reading older output.  Restore the exact first visible line.
        # Do NOT call ScrollToCaret here; that is what was causing the jump.
        try {
            $currentFirstVisibleLine = [int][RCCURichEditApi]::SendMessage(
                $OutputBox.Handle,
                [RCCURichEditApi]::EM_GETFIRSTVISIBLELINE,
                [IntPtr]::Zero,
                [IntPtr]::Zero
            )

            $delta = $savedFirstVisibleLine - $currentFirstVisibleLine
            if ($delta -ne 0) {
                [void][RCCURichEditApi]::SendMessage(
                    $OutputBox.Handle,
                    [RCCURichEditApi]::EM_LINESCROLL,
                    [IntPtr]::Zero,
                    [IntPtr]$delta
                )
            }
        }
        catch {
        }
    }

    [System.Windows.Forms.Application]::DoEvents()
}

function Write-Host {
    param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Object)
    $text = ($Object | ForEach-Object { [string]$_ }) -join ' '
    Microsoft.PowerShell.Utility\Write-Host -Object $text
    Append-OutputPane $text
    Add-Content -LiteralPath $OutputLog -Value $text
}

function Write-Log {
    param(
        [string]$File,
        [string]$Text
    )

    Add-Content -LiteralPath $File -Value $Text
}

function Get-NormalName {
    param(
        [string]$Name
    )

    $n = [System.IO.Path]::GetFileNameWithoutExtension($Name)

    do {
        $old = $n

        # Remove common region/revision/release tags for matching only.
        # If this collapses two different ROMs to one key, the audit reports
        # the result as ambiguous instead of guessing.
        $n = $n -replace '\s*\((?:USA|U|Europe|EUR|World|Japan|J|Korea|K|Australia|Asia|Canada|France|Germany|Spain|Italy|Brazil)\)\s*',' '
        $n = $n -replace '\s*\((?:Rev\s*[A-Z0-9]+|v?\d+(?:\.\d+)*|Beta|Demo|Sample|Proto(?:type)?|Unl)\)\s*',' '
        $n = $n -replace '\s*\[a\d*\]\s*',' '
        $n = $n -replace '\s*\[b\d*\]\s*',' '
        $n = $n -replace '\s*\[p\]\s*',' '
        $n = $n -replace '\s*\[proto(?:type)?\]\s*',' '

        # Trailing TOSEC-style release flags are metadata, not part of the
        # game title.  Examples include (AGA), (SW), (PD), (M), etc.
        # Only short all-caps flag groups at the END are removed, so real
        # title/developer groups such as (Burlock, Craig) remain untouched.
        $n = $n -replace '\s*\([A-Z]{1,5}\d{0,2}\)\s*$',' '

        # Trailing square-bracket release/dump tags are likewise metadata.
        # For matching purposes, any final [...] group is ignored.  This does
        # not alter the actual filename on disk.
        $n = $n -replace '\s*\[[^\]]*\]\s*$',' '

        $n = $n.Trim()

    } while ($n -ne $old)

    return $n.ToLowerInvariant()
}

function Get-NormalizedGameListName {
    param(
        [string]$Name
    )

    $n = [System.IO.Path]::GetFileNameWithoutExtension($Name)

    do {
        $old = $n

        # Remove common ROM region/release clutter while keeping the actual game title.
        $n = $n -replace '\s*\((?:USA|U|Europe|EUR|World|Japan|J|Korea|K|Australia|Asia|Canada|France|Germany|Spain|Italy|Brazil|En|EnFr|Fr|De|Es|It)\)\s*',' ' -replace '\s*\[(?:USA|U|Europe|EUR|World|Japan|J|Korea|K|Australia|Asia|Canada|France|Germany|Spain|Italy|Brazil|En|EnFr|Fr|De|Es|It)\]\s*',' '
        $n = $n -replace '\s*\((?:Rev\s*[A-Z0-9]+|v?\d+(?:\.\d+)*|Beta|Demo|Sample|Proto(?:type)?)\)\s*',' '
        $n = $n -replace '\s*\[(?:a\d*|b\d*|p|proto(?:type)?)\]\s*',' '
        $n = $n -replace '\s{2,}',' '
        $n = $n.Trim(' ','.','-','_')
    } while ($n -ne $old)

    return $n
}

function Save-NormalizedGameList {
    param(
        [string]$OutputPath
    )

    $games = New-Object System.Collections.Generic.List[string]
    foreach ($gameFile in @(Get-GameFiles)) {
        if ($null -eq $gameFile) { continue }
        $name = Get-NormalizedGameListName ([string]$gameFile.Name)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $games.Add($name)
        }
    }

    $sorted = @($games | Sort-Object -Unique)
    Set-Content -LiteralPath $OutputPath -Value $sorted -Encoding UTF8
    Write-Host "Normalized game list saved: $OutputPath"
    Write-Host "Normalized game titles: $($sorted.Count)"
}

function Get-RelativePath {
    param(
        [string]$Base,
        [string]$Full
    )

    $baseUri = New-Object System.Uri(($Base.TrimEnd('\') + '\'))
    $fullUri = New-Object System.Uri($Full)

    $relative = $baseUri.MakeRelativeUri($fullUri).ToString()

    return [System.Uri]::UnescapeDataString($relative).Replace('\','/')
}

function Load-XmlSafe {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $XmlText = [System.IO.File]::ReadAllText(
        $Path,
        [System.Text.Encoding]::UTF8
    ).TrimStart([char]0xFEFF)

    return [xml]$XmlText
}

function Save-XmlSafe {
    param(
        [xml]$Xml,
        [string]$Path
    )

    if ($null -eq $Xml -or $null -eq $Xml.DocumentElement) {
        throw "Cannot save XML because the XML document has no document root."
    }

    $tempPath = "$Path.tmp"
    $writer = $null

    try {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }

        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
        $settings.Indent = $true
        $settings.OmitXmlDeclaration = $false

        $writer = [System.Xml.XmlWriter]::Create($tempPath, $settings)
        $Xml.Save($writer)
        $writer.Flush()
        $writer.Close()
        $writer.Dispose()
        $writer = $null

        if (-not (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
            throw "Temporary XML file was not created."
        }

        $tempXml = Load-XmlSafe $tempPath
        if ($null -eq $tempXml -or $null -eq $tempXml.DocumentElement) {
            throw "Temporary XML validation failed."
        }

        $tempGameCount = @(Get-XmlGameNodes $tempXml).Count
        $sourceGameCount = @(Get-XmlGameNodes $Xml).Count

        if ($sourceGameCount -eq 0) {
            throw "XML save validation failed: refusing to save an XML document containing 0 game entries."
        }

        if ($tempGameCount -ne $sourceGameCount) {
            throw "XML save validation failed: source had $sourceGameCount game entries but temporary file has $tempGameCount."
        }

        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if ($writer) {
            try { $writer.Close() } catch { }
            try { $writer.Dispose() } catch { }
        }

        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-XmlGameNodes {
    param(
        [xml]$Xml
    )

    if ($null -eq $Xml -or $null -eq $Xml.DocumentElement) {
        return @()
    }

    # RetroBat XML is normally <gameList><game>...</game></gameList>.
    # Use a case-insensitive local-name test so harmless XML naming/namespace
    # differences do not make real game entries disappear.
    $nodes = @(
        $Xml.DocumentElement.SelectNodes(
            "./*[translate(local-name(),'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='game']"
        )
    )

    # If an XML uses an additional wrapper around the game entries, accept
    # descendant <game> nodes as a compatibility fallback.
    if ($nodes.Count -eq 0) {
        $nodes = @(
            $Xml.SelectNodes(
                "//*[translate(local-name(),'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='game']"
            )
        )
    }

    return @($nodes)
}

function Resolve-XmlPath {
    param(
        [string]$XmlPath
    )

    if ([string]::IsNullOrWhiteSpace($XmlPath)) {
        return $null
    }

    $value = $XmlPath.Trim()

    # RetroBat normally stores paths as ./filename.ext.
    # Treat the XML path literally and resolve it relative to the folder
    # containing this script/gamelist.xml, not the PowerShell working directory.
    $value = $value -replace '/', '\'

    if ($value.StartsWith('./')) {
        $value = $value.Substring(2)
    }
    elseif ($value.StartsWith('.\')) {
        $value = $value.Substring(2)
    }

    if ([System.IO.Path]::IsPathRooted($value)) {
        return [System.IO.Path]::GetFullPath($value)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $value))
}

function Get-XmlNodeText {
    param(
        $Node,
        [string]$Name
    )

    if ($null -eq $Node) {
        return ""
    }

    $child = $Node.SelectSingleNode("./*[local-name()='$Name']")

    if ($null -eq $child) {
        return ""
    }

    return [string]$child.InnerText
}

function Get-LooseName {
    param(
        [string]$Name
    )

    $n = Get-NormalName $Name
    return ($n -replace '[^a-z0-9]+','')
}

function Test-IsRccuRecoveryPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    return ($Path -match '(?i)(^|\\)RCCU_RecycleBin(\\|$)')
}

function Test-IsRccuXmlNamedFile {
    param([System.IO.FileInfo]$File)
    if ($null -eq $File) { return $false }
    # Any filename containing the three-character sequence "xml" is metadata,
    # backup XML, or XML-related material -- never treat it as a game or media file.
    return ($File.Name -match '(?i)xml')
}

function Get-GameFiles {
    # A BIN/CUE disc image is represented in gamelist.xml by the CUE sheet.
    # The BIN is a payload file, not a second game.  When a matching CUE exists,
    # hide the BIN from game-entry, duplicate, and final-verification scans.
    # This prevents the normal "CUE + BIN" pair from becoming a duplicate or
    # from producing a false "game exists without an XML entry" error.
    return @(
        Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue |
        Where-Object {
            if (Test-IsRccuXmlNamedFile $_) { return $false }
            if ($_.Name -like "000-*.txt") {
                return $false
            }

            if ($_.Extension -ieq '.bin') {
                $cuePath = [System.IO.Path]::ChangeExtension($_.FullName,'.cue')
                if (Test-Path -LiteralPath $cuePath -PathType Leaf) {
                    return $false
                }
            }

            return $true
        }
    )
}

function Show-YesNo {
    param(
        [string]$TitleText,
        [string]$Message
    )

    if ($script:AutomaticYesAll) {
        Write-Host "[DANGER] AUTOMATIC: YES -> $TitleText"
        return $true
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        $Form,
        $Message,
        $TitleText,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

# ============================================================
# DELETE REVIEW DIALOG
# ============================================================

function Open-PathInExplorerHighlight {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    try {
        $full = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return
    }

    try {
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            # /select makes Explorer open the containing directory and highlight
            # the exact file instead of merely opening the file itself.
            Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$full`"" | Out-Null
            return
        }

        if (Test-Path -LiteralPath $full -PathType Container) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$full`"" | Out-Null
            return
        }

        $parent = Split-Path -LiteralPath $full -Parent
        if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$parent`"" | Out-Null
        }
    }
    catch {
        Write-Host "Could not open Explorer for: $full"
        Write-Host $_.Exception.Message
    }
}

# ============================================================
# DELETE REVIEW DIALOG
# ============================================================

function Show-DeletionReviewDialog {
    param([string]$TitleText,[string]$IntroText,[array]$Items)

    if ($script:AutomaticYesAll) {
        Write-Host "[DANGER] AUTOMATIC: RECYCLE ALL -> $TitleText ($($Items.Count) items)"
        return [pscustomobject]@{ Action="RECYCLE"; Items=@($Items | ForEach-Object {
            if ($_ -is [string]) { [string]$_ }
            elseif ($null -ne $_.RelativePath -and $null -ne $_.Reason) { "$($_.RelativePath) | $($_.Reason)" }
            else { [string]$_ }
        }) }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Icon = $script:RazorIcon
    $form.Text = $TitleText
    $form.Size = [System.Drawing.Size]::new(1060,780)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MinimumSize = [System.Drawing.Size]::new(980,650)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Select files to delete"
    $title.Font = [System.Drawing.Font]::new("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
    $title.Location = [System.Drawing.Point]::new(18,15)
    $title.Size = [System.Drawing.Size]::new(700,34)
    $title.AutoSize = $false
    $title.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $form.Controls.Add($title)

    $intro = New-Object System.Windows.Forms.Label
    $intro.Text = $IntroText
    $intro.Location = [System.Drawing.Point]::new(18,53)
    $intro.Size = [System.Drawing.Size]::new(1000,42)
    $intro.AutoSize = $false
    $intro.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $intro.AutoEllipsis = $true
    $form.Controls.Add($intro)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = [System.Drawing.Point]::new(18,104)
    $list.Size = [System.Drawing.Size]::new(1000,520)
    $list.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $list.CheckOnClick = $true
    $list.HorizontalScrollbar = $true
    $list.IntegralHeight = $false
    $list.ScrollAlwaysVisible = $true
    $list.Font = [System.Drawing.Font]::new("Segoe UI",11,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Point)
    $list.ItemHeight = 22

    # Keep the actual object/path beside each display row.  The visible text
    # can then be clicked to jump straight to the real file in Explorer.
    $rowItems = New-Object System.Collections.ArrayList

    foreach ($item in $Items) {
        if ($item -is [string]) {
            $display = [string]$item
            $path = $null
        }
        elseif ($null -ne $item.RelativePath) {
            $reason = if ($null -ne $item.Reason -and -not [string]::IsNullOrWhiteSpace([string]$item.Reason)) { " | $($item.Reason)" } else { "" }
            $display = "$($item.RelativePath)$reason"
            $path = if ($null -ne $item.FullPath -and -not [string]::IsNullOrWhiteSpace([string]$item.FullPath)) { [string]$item.FullPath } else { $null }
        }
        elseif ($null -ne $item.File) {
            $reason = if ($null -ne $item.Reason -and -not [string]::IsNullOrWhiteSpace([string]$item.Reason)) { " | $($item.Reason)" } else { "" }
            $display = "$($item.File.FullName)$reason"
            $path = [string]$item.File.FullName
        }
        else {
            $display = [string]$item
            $path = $null
        }

        [void]$rowItems.Add([pscustomobject]@{ Display=$display; Path=$path; Source=$item })
        [void]$list.Items.Add($display,$true)
    }
    $form.Controls.Add($list)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = "Click the file text to open its folder in Explorer and highlight the file. Click the checkbox to select/deselect it."
    $hint.Font = [System.Drawing.Font]::new("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
    $hint.Location = [System.Drawing.Point]::new(18,628)
    $hint.Size = [System.Drawing.Size]::new(700,24)
    $hint.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $form.Controls.Add($hint)

    $list.Add_MouseUp({
        param($sender,$e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }

        $index = $sender.IndexFromPoint($e.Location)
        if ($index -lt 0 -or $index -ge $rowItems.Count) { return }

        # Leave the checkbox itself for selection.  Clicking the filename area
        # opens Explorer without changing the checked state.
        if ($e.X -lt 24) { return }

        $target = [string]$rowItems[$index].Path
        if (-not [string]::IsNullOrWhiteSpace($target)) {
            Open-PathInExplorerHighlight $target
        }
    })

    $selectAll = New-Object System.Windows.Forms.Button
    $selectAll.Text = "SELECT ALL"
    $selectAll.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $selectAll.Location = [System.Drawing.Point]::new(18,660)
    $selectAll.Size = [System.Drawing.Size]::new(170,46)
    $selectAll.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $selectAll.AutoEllipsis = $false
    $selectAll.UseCompatibleTextRendering = $false
    $selectAll.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $selectAll.Add_Click({ for ($i=0;$i -lt $list.Items.Count;$i++) { $list.SetItemChecked($i,$true) } })
    $form.Controls.Add($selectAll)

    $selectNone = New-Object System.Windows.Forms.Button
    $selectNone.Text = "SELECT NONE"
    $selectNone.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $selectNone.Location = [System.Drawing.Point]::new(198,660)
    $selectNone.Size = [System.Drawing.Size]::new(170,46)
    $selectNone.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $selectNone.AutoEllipsis = $false
    $selectNone.UseCompatibleTextRendering = $false
    $selectNone.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $selectNone.Add_Click({ for ($i=0;$i -lt $list.Items.Count;$i++) { $list.SetItemChecked($i,$false) } })
    $form.Controls.Add($selectNone)

    $delete = New-Object System.Windows.Forms.Button
    $delete.Text = "RECYCLE"
    $delete.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $delete.Location = [System.Drawing.Point]::new(650,660)
    $delete.Size = [System.Drawing.Size]::new(230,46)
    $delete.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $delete.AutoEllipsis = $false
    $delete.UseCompatibleTextRendering = $false
    $delete.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $delete.Add_Click({ $form.Tag = [pscustomobject]@{ Action="RECYCLE"; Items=@($list.CheckedItems) }; $form.Close() })
    $form.Controls.Add($delete)

    $skip = New-Object System.Windows.Forms.Button
    $skip.Text = "SKIP"
    $skip.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $skip.Location = [System.Drawing.Point]::new(890,660)
    $skip.Size = [System.Drawing.Size]::new(130,46)
    $skip.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $skip.AutoEllipsis = $false
    $skip.UseCompatibleTextRendering = $false
    $skip.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $skip.Add_Click({ $form.Tag = [pscustomobject]@{ Action="SKIP"; Items=@() }; $form.Close() })
    $form.Controls.Add($skip)

    foreach ($button in @($selectAll,$selectNone,$delete,$skip)) {
        $button.AutoSize = $false
        $button.UseCompatibleTextRendering = $false
        $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    }

    $form.Add_Resize({
        $list.Height = [int][math]::Max(180, $form.ClientSize.Height - $list.Top - 98)
        $intro.Width = [int][math]::Max(300, $form.ClientSize.Width - 36)
        $list.Width = [int][math]::Max(300, $form.ClientSize.Width - 36)
        $hint.Top = $form.ClientSize.Height - 78
        $hint.Width = [int][math]::Max(300, $form.ClientSize.Width - 36)
        $bottom = $form.ClientSize.Height - $skip.Height - 18
        $skip.Left = $form.ClientSize.Width - $skip.Width - 18
        $skip.Top = $bottom
        $delete.Left = $skip.Left - $delete.Width - 10
        $delete.Top = $bottom
        $selectAll.Left = 18
        $selectAll.Top = $bottom
        $selectNone.Left = $selectAll.Left + $selectAll.Width + 10
        $selectNone.Top = $bottom
    })
    $form.Add_Shown({
        $bottom = $form.ClientSize.Height - $skip.Height - 18
        $skip.Left = $form.ClientSize.Width - $skip.Width - 18
        $skip.Top = $bottom
        $delete.Left = $skip.Left - $delete.Width - 10
        $delete.Top = $bottom
        $selectAll.Left = 18
        $selectAll.Top = $bottom
        $selectNone.Left = $selectAll.Left + $selectAll.Width + 10
        $selectNone.Top = $bottom
        [System.Windows.Forms.Application]::DoEvents()
    })

    $form.Add_FormClosing({ if ($null -eq $form.Tag) { $form.Tag = [pscustomobject]@{ Action="SKIP"; Items=@() } } })

    Set-DarkThemeForForm $form

    # IMPORTANT: this review is intentionally modeless.  ShowDialog() made the
    # main RCCU window inaccessible while a deletion review was open.  Show()
    # lets the user click the original window, while the small DoEvents loop
    # keeps this function synchronous for the maintenance stage.
    $form.Show()
    $form.Activate()
    $form.BringToFront()

    while ($form.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(25)
    }

    $result = $form.Tag
    $form.Dispose()
    return $result
}

# ============================================================
# STAGE 2 - DUPLICATE DIALOG
# ============================================================

function Show-DuplicateDialog {
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$Files
    )

    $files = @($Files | Sort-Object LastWriteTime -Descending)

    $form = New-Object System.Windows.Forms.Form
    $form.Icon = $script:RazorIcon
    $form.Text = "Duplicate ROM Review"
    $form.Size = [System.Drawing.Size]::new(920,650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MinimumSize = [System.Drawing.Size]::new(760,520)
    $form.KeyPreview = $true
    $form.Tag = [pscustomobject]@{ Action="SKIP"; Files=@() }

    $title = New-Object System.Windows.Forms.Label
    $title.Text = if ($files.Count -eq 2) { "Duplicate ROMs found — select files to DELETE" } else { "Multiple duplicate ROMs found — select files to DELETE" }
    $title.Font = [System.Drawing.Font]::new("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
    $title.Location = [System.Drawing.Point]::new(18,15)
    $title.Size = [System.Drawing.Size]::new(850,32)
    $form.Controls.Add($title)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "Newest copy starts unchecked. Check any copy you want RCCU to recycle. Nothing is deleted until you click DELETE or YES TO ALL."
    $info.Location = [System.Drawing.Point]::new(18,48)
    $info.Size = [System.Drawing.Size]::new(850,32)
    $form.Controls.Add($info)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = [System.Drawing.Point]::new(18,86)
    $list.Size = [System.Drawing.Size]::new(866,445)
    $list.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $list.CheckOnClick = $true
    $list.HorizontalScrollbar = $true
    $fileMap = @()

    foreach ($file in $files) {
        # Show only the filename so the user decides what to keep/delete from the checkbox state.
        [void]$list.Items.Add($file.Name, $false)
        $fileMap += $file
    }
    $form.Controls.Add($list)

    $delete = New-Object System.Windows.Forms.Button
    $delete.Text = "DELETE"
    $delete.Size = [System.Drawing.Size]::new(150,44)
    $delete.Location = [System.Drawing.Point]::new(18,555)
    $delete.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $delete.Add_Click({
        $selected = @()
        foreach ($checkedIndex in @($list.CheckedIndices)) {
            $candidate = $fileMap[[int]$checkedIndex]
            if ($candidate -ne $files[0]) { $selected += $candidate }
        }
        $form.Tag = [pscustomobject]@{ Action="DELETE"; Files=$selected }
        $form.Close()
    })
    $form.Controls.Add($delete)

    $yesAll = New-Object System.Windows.Forms.Button
    $yesAll.Text = "YES TO ALL"
    $yesAll.Size = [System.Drawing.Size]::new(150,44)
    $yesAll.Location = [System.Drawing.Point]::new(178,555)
    $yesAll.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $yesAll.Add_Click({
        $selected = @()
        foreach ($checkedIndex in @($list.CheckedIndices)) {
            $candidate = $fileMap[[int]$checkedIndex]
            if ($candidate -ne $files[0]) { $selected += $candidate }
        }
        $form.Tag = [pscustomobject]@{ Action="YES TO ALL"; Files=$selected }
        $form.Close()
    })
    $form.Controls.Add($yesAll)

    $noAll = New-Object System.Windows.Forms.Button
    $noAll.Text = "NO TO ALL"
    $noAll.Size = [System.Drawing.Size]::new(150,44)
    $noAll.Location = [System.Drawing.Point]::new(338,555)
    $noAll.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $noAll.Add_Click({ $form.Tag = [pscustomobject]@{ Action="NO TO ALL"; Files=@() }; $form.Close() })
    $form.Controls.Add($noAll)

    $skip = New-Object System.Windows.Forms.Button
    $skip.Text = "SKIP"
    $skip.Size = [System.Drawing.Size]::new(150,44)
    $skip.Location = [System.Drawing.Point]::new(498,555)
    $skip.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $skip.Add_Click({ $form.Tag = [pscustomobject]@{ Action="SKIP"; Files=@() }; $form.Close() })
    $form.Controls.Add($skip)

    $form.Add_KeyDown({
        param($sender,$e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $form.Tag = [pscustomobject]@{ Action="SKIP"; Files=@() }
            $form.Close()
        }
    })

    Set-DarkThemeForForm $form
    $form.ShowDialog() | Out-Null
    $result = $form.Tag
    $form.Dispose()
    return $result
}

# ============================================================
# STAGE 2 - DUPLICATE ROM REVIEW
# ============================================================

function Invoke-DuplicateReview {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 2 - DUPLICATE ROM REVIEW"
    Write-Host "============================================================"

    Set-Content -LiteralPath $DuplicateLog -Value "RetroBat Duplicate ROM Review - $(Get-Date)"
    Add-Content -LiteralPath $DuplicateLog -Value "System: $Root"
    Add-Content -LiteralPath $DuplicateLog -Value ""

    $files = @(Get-GameFiles)

    if ($files.Count -eq 0) {
        Write-Host "No root-level ROM files found."
        Update-Stage 2 100 "No root-level ROM files found."
        return $true
    }

    # M3U playlists are valid when they correspond to a real game/source file.
    # Only unmatched M3Us remain eligible for the normal duplicate grouping.
    # This prevents a legitimate playlist from being treated as a duplicate ROM
    # merely because its basename matches the actual game it belongs to.
    $sourceKeys = @{}
    foreach ($sourceFile in @($files | Where-Object { $_.Extension -ine '.m3u' })) {
        $sourceKey = Get-NormalName $sourceFile.Name
        if (-not $sourceKeys.ContainsKey($sourceKey)) {
            $sourceKeys[$sourceKey] = $true
        }
    }

    $groups = @{}

    foreach ($file in $files) {

        if ($file.Extension -ieq '.m3u') {
            $m3uKey = Get-NormalName $file.Name
            if ($sourceKeys.ContainsKey($m3uKey)) {
                Add-Content -LiteralPath $DuplicateLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | IGNORE MATCHED M3U | $($file.FullName) | MATCH=$m3uKey"
                continue
            }
        }

        # Multi-disc / multi-disk filenames are not duplicate candidates.
        # A title such as "Game (Disc 1)" or "Game (Disk 2)" must never be
        # collapsed into a duplicate group with another disc.
        if ($file.Name -match '(?i)\b(?:disk|disc)\b') {
            Add-Content -LiteralPath $DuplicateLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | IGNORE DISK/DISC FILE | $($file.FullName)"
            continue
        }

        $key = Get-NormalName $file.Name

        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = New-Object System.Collections.ArrayList
        }

        [void]$groups[$key].Add($file)
    }

    $duplicates = @(
        $groups.GetEnumerator() |
        Where-Object {
            $_.Value.Count -gt 1
        }
    )

    $total = $duplicates.Count

    if ($total -eq 0) {
        Write-Host "No duplicate ROM groups found."
        Update-Stage 2 100 "No duplicate ROM groups found."
        return $true
    }

    Write-Host "Duplicate groups found: $total"

    $index = 0
    $yesToAll = $false
    $noToAll = $false

    foreach ($group in $duplicates) {

        if ($script:StageSkipRequested[2]) {
            Write-Host "Stage 2 skipped by user."
            Set-StageSkipped 2 "Stage 2 skipped by user. Remaining duplicate groups were not reviewed."
            return $true
        }

        $index++

        $percent = [int](($index / $total) * 100)

        Update-Stage 2 $percent "Reviewing duplicate group $index of $total"

        $sorted = @(
            $group.Value |
            Sort-Object LastWriteTime -Descending
        )

        if ($script:AutomaticYesAll -or $yesToAll) {
            # YES TO ALL means keep the newest copy and recycle every older duplicate
            # for this and all remaining duplicate groups.
            $decision = [pscustomobject]@{ Action="YES TO ALL"; Files=@($sorted | Select-Object -Skip 1) }
            Write-Host "[DANGER] YES TO ALL: KEEP NEWEST / RECYCLE $([math]::Max(0,$sorted.Count-1)) OLDER DUPLICATE(S)"
        }
        elseif ($noToAll) {
            $decision = [pscustomobject]@{ Action="NO TO ALL"; Files=@() }
            Write-Host "NO TO ALL: keeping this and all remaining duplicate groups."
        }
        else {
            $decision = $null
        }

        Write-Host ""
        Write-Host "Duplicate group: $($sorted.Count) files"
        foreach ($item in $sorted) { Write-Host "  $($item.FullName)" }

        if ($null -eq $decision) {
            $decision = Show-DuplicateDialog -Files $sorted
        }
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $action = [string]$decision.Action
        $selectedFiles = @($decision.Files)

        Add-Content -LiteralPath $DuplicateLog -Value "$time | $action | GROUP=$($sorted[0].Name) | SELECTED=$($selectedFiles.Name -join '; ')"

        switch ($action) {
            "DELETE" {
                foreach ($fileToDelete in $selectedFiles) {
                    try {
                        Move-FileToRecycleBin -Path $fileToDelete.FullName
                        Write-Host "Recycled: $($fileToDelete.FullName)"
                    }
                    catch {
                        Write-Host "FAILED TO DELETE: $($fileToDelete.FullName)"
                        Write-Host $_.Exception.Message
                    }
                }
            }
            "YES TO ALL" {
                $yesToAll = $true
                foreach ($fileToDelete in $selectedFiles) {
                    try {
                        Move-FileToRecycleBin -Path $fileToDelete.FullName
                        Write-Host "Recycled: $($fileToDelete.FullName)"
                    }
                    catch {
                        Write-Host "FAILED TO DELETE: $($fileToDelete.FullName)"
                        Write-Host $_.Exception.Message
                    }
                }
            }
            "NO TO ALL" {
                $noToAll = $true
                Write-Host "Keeping this and all remaining duplicate groups."
            }
            "SKIP" { Write-Host "Skipped duplicate group." }
        }
    }

    Update-Stage 2 100 "Duplicate review complete. $total duplicate groups reviewed."

    return $true
}

# ============================================================
# IMAGE ANALYSIS
# ============================================================

function Get-ImageColorStats {
    param(
        [string]$Path
    )

    $bitmap = $null
    $small = $null
    $graphics = $null

    try {

        $bitmap = [System.Drawing.Bitmap]::FromFile($Path)

        $maxDimension = 500

        $width = $bitmap.Width
        $height = $bitmap.Height

        if ($width -gt $maxDimension -or $height -gt $maxDimension) {

            $scale = [math]::Min(
                $maxDimension / [double]$width,
                $maxDimension / [double]$height
            )

            $newWidth = [math]::Max(
                1,
                [int]($width * $scale)
            )

            $newHeight = [math]::Max(
                1,
                [int]($height * $scale)
            )

            $small = New-Object System.Drawing.Bitmap(
                $newWidth,
                $newHeight
            )

            $graphics = [System.Drawing.Graphics]::FromImage($small)

            $graphics.DrawImage(
                $bitmap,
                0,
                0,
                $newWidth,
                $newHeight
            )

            $scan = $small
        }
        else {
            $scan = $bitmap
        }

        $total = 0
        $black = 0
        $white = 0
        $green = 0
        $transparent = 0

        for ($y = 0; $y -lt $scan.Height; $y++) {

            for ($x = 0; $x -lt $scan.Width; $x++) {

                $p = $scan.GetPixel($x,$y)

                $total++

                $a = $p.A
                $r = $p.R
                $g = $p.G
                $b = $p.B

                if ($a -eq 0) {
                    $transparent++
                    continue
                }

                if (
                    $r -le 12 -and
                    $g -le 12 -and
                    $b -le 12
                ) {
                    $black++
                }

                if (
                    $r -ge 243 -and
                    $g -ge 243 -and
                    $b -ge 243
                ) {
                    $white++
                }

                if (
                    [math]::Abs($r - 0) -le $script:GreenTolerance -and
                    [math]::Abs($g - 255) -le $script:GreenTolerance -and
                    [math]::Abs($b - 0) -le $script:GreenTolerance
                ) {
                    $green++
                }
            }
        }

        if ($total -eq 0) {
            return $null
        }

        $blackPct = [math]::Round(
            ($black / $total) * 100,
            1
        )

        $whitePct = [math]::Round(
            ($white / $total) * 100,
            1
        )

        $greenPct = [math]::Round(
            ($green / $total) * 100,
            1
        )

        $transparentPct = [math]::Round(
            ($transparent / $total) * 100,
            1
        )

        $targetPct = [math]::Round(
            (($black + $white + $green) / $total) * 100,
            1
        )

        $reason = ""

        if ($transparentPct -ge $script:UniformThreshold) {
            $reason = "TRANSPARENT $transparentPct%"
        }
        elseif ($blackPct -ge $script:UniformThreshold) {
            $reason = "BLACK $blackPct%"
        }
        elseif ($whitePct -ge $script:UniformThreshold) {
            $reason = "WHITE $whitePct%"
        }
        elseif ($greenPct -ge $script:UniformThreshold) {
            $reason = "GREEN #00FF00 $greenPct%"
        }

        return [PSCustomObject]@{
            Width = $width
            Height = $height
            BlackPct = $blackPct
            WhitePct = $whitePct
            GreenPct = $greenPct
            TransparentPct = $transparentPct
            TargetPct = $targetPct
            Reason = $reason
        }
    }
    catch {

        Write-Host "Image read failed: $Path"
        Write-Host $_.Exception.Message

        return $null
    }
    finally {

        if ($graphics) {
            $graphics.Dispose()
        }

        if ($small) {
            $small.Dispose()
        }

        if ($bitmap) {
            $bitmap.Dispose()
        }
    }
}

# ============================================================
# STAGE 3 - IMAGE REVIEW
# ============================================================

function Invoke-UniformImageReview {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 3 - IMAGE REVIEW"
    Write-Host "============================================================"

    Set-Content -LiteralPath $UniformLog -Value "RetroBat Uniform Image Review - $(Get-Date)"
    Add-Content -LiteralPath $UniformLog -Value "System: $Root"
    Add-Content -LiteralPath $UniformLog -Value "Threshold: $UniformThreshold%"
    Add-Content -LiteralPath $UniformLog -Value "Green: #00FF00"
    Add-Content -LiteralPath $UniformLog -Value "ACTION: User selects flagged images in checklist; only checked files are deleted"
    Add-Content -LiteralPath $UniformLog -Value ""

    $allImages = New-Object System.Collections.ArrayList

    $directories = @(
        Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsRccuRecoveryPath $_.FullName) -and
            $MediaTagMap.ContainsKey($_.Name.ToLowerInvariant())
        }
    )

    foreach ($dir in $directories) {

        if ($script:StageSkipRequested[3]) {
            Write-Host "Stage 3 skipped by user during directory scan."
            Set-StageSkipped 3 "Stage 3 skipped by user. Image scan was stopped."
            return $true
        }

        $files = @(
            Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                -not (Test-IsRccuRecoveryPath $_.FullName) -and
                -not (Test-IsRccuXmlNamedFile $_) -and
                ($ImageExtensions -contains $_.Extension.ToLowerInvariant())
            }
        )

        foreach ($file in $files) {
            [void]$allImages.Add($file)
        }
    }

    $allImages = @(
        $allImages |
        Sort-Object FullName -Unique
    )

    $total = $allImages.Count

    if ($total -eq 0) {
        Write-Host "No images found."
        Update-Stage 3 100 "No recognized media images found."
        return $true
    }

    Write-Host "Images to inspect: $total"
    Write-Host "Image analysis workers: $Stage2Threads"

    $index = 0
    $flagged = 0
    $deleted = 0
    $failed = 0
    $flaggedItems = New-Object System.Collections.ArrayList

    # ============================================================
    # MULTITHREADED IMAGE ANALYSIS
    # ============================================================

    $workerScript = {
        param(
            [string]$ImagePath,
            [int]$UniformThreshold,
            [int]$GreenTolerance
        )

        $bitmap = $null
        $small = $null
        $graphics = $null

        try {

            $bitmap = [System.Drawing.Bitmap]::FromFile($ImagePath)

            $maxDimension = 500

            $width = $bitmap.Width
            $height = $bitmap.Height

            if ($width -gt $maxDimension -or $height -gt $maxDimension) {

                $scale = [math]::Min(
                    $maxDimension / [double]$width,
                    $maxDimension / [double]$height
                )

                $newWidth = [math]::Max(
                    1,
                    [int]($width * $scale)
                )

                $newHeight = [math]::Max(
                    1,
                    [int]($height * $scale)
                )

                $small = New-Object System.Drawing.Bitmap(
                    $newWidth,
                    $newHeight
                )

                $graphics = [System.Drawing.Graphics]::FromImage($small)

                $graphics.DrawImage(
                    $bitmap,
                    0,
                    0,
                    $newWidth,
                    $newHeight
                )

                $scan = $small
            }
            else {
                $scan = $bitmap
            }

            $totalPixels = 0
            $black = 0
            $white = 0
            $green = 0
            $transparent = 0

            for ($y = 0; $y -lt $scan.Height; $y++) {

                for ($x = 0; $x -lt $scan.Width; $x++) {

                    $p = $scan.GetPixel($x,$y)

                    $totalPixels++

                    $a = $p.A
                    $r = $p.R
                    $g = $p.G
                    $b = $p.B

                    if ($a -eq 0) {
                        $transparent++
                        continue
                    }

                    if (
                        $r -le 12 -and
                        $g -le 12 -and
                        $b -le 12
                    ) {
                        $black++
                    }

                    if (
                        $r -ge 243 -and
                        $g -ge 243 -and
                        $b -ge 243
                    ) {
                        $white++
                    }

                    if (
                        [math]::Abs($r - 0) -le $GreenTolerance -and
                        [math]::Abs($g - 255) -le $GreenTolerance -and
                        [math]::Abs($b - 0) -le $GreenTolerance
                    ) {
                        $green++
                    }
                }
            }

            if ($totalPixels -eq 0) {
                return [PSCustomObject]@{
                    Path = $ImagePath
                    Stats = $null
                    Error = $null
                }
            }

            $blackPct = [math]::Round(
                ($black / $totalPixels) * 100,
                1
            )

            $whitePct = [math]::Round(
                ($white / $totalPixels) * 100,
                1
            )

            $greenPct = [math]::Round(
                ($green / $totalPixels) * 100,
                1
            )

            $transparentPct = [math]::Round(
                ($transparent / $totalPixels) * 100,
                1
            )

            $targetPct = [math]::Round(
                (($black + $white + $green) / $totalPixels) * 100,
                1
            )

            $reason = ""

            if ($transparentPct -ge $UniformThreshold) {
                $reason = "TRANSPARENT $transparentPct%"
            }
            elseif ($blackPct -ge $UniformThreshold) {
                $reason = "BLACK $blackPct%"
            }
            elseif ($whitePct -ge $UniformThreshold) {
                $reason = "WHITE $whitePct%"
            }
            elseif ($greenPct -ge $UniformThreshold) {
                $reason = "GREEN #00FF00 $greenPct%"
            }

            return [PSCustomObject]@{
                Path = $ImagePath
                Stats = [PSCustomObject]@{
                    Width = $width
                    Height = $height
                    BlackPct = $blackPct
                    WhitePct = $whitePct
                    GreenPct = $greenPct
                    TransparentPct = $transparentPct
                    TargetPct = $targetPct
                    Reason = $reason
                }
                Error = $null
            }
        }
        catch {

            return [PSCustomObject]@{
                Path = $ImagePath
                Stats = $null
                Error = $_.Exception.Message
            }
        }
        finally {

            if ($graphics) {
                $graphics.Dispose()
            }

            if ($small) {
                $small.Dispose()
            }

            if ($bitmap) {
                $bitmap.Dispose()
            }
        }
    }

    $runspacePool = [runspacefactory]::CreateRunspacePool(
        1,
        $Stage2Threads
    )

    $runspacePool.Open()

    $jobs = New-Object System.Collections.ArrayList
    $nextImage = 0
    $completed = 0
    $stopSubmitting = $false

    try {

        while (
            ($nextImage -lt $total -and -not $stopSubmitting) -or
            $jobs.Count -gt 0
        ) {

            if ($script:StageSkipRequested[3]) {
                $stopSubmitting = $true
            }

            while (
                -not $stopSubmitting -and
                $nextImage -lt $total -and
                $jobs.Count -lt $Stage2Threads
            ) {

                $file = $allImages[$nextImage]

                $powershell = [powershell]::Create()
                $powershell.RunspacePool = $runspacePool

                [void]$powershell.AddScript($workerScript)
                [void]$powershell.AddArgument($file.FullName)
                [void]$powershell.AddArgument($UniformThreshold)
                [void]$powershell.AddArgument($GreenTolerance)

                $asyncResult = $powershell.BeginInvoke()

                [void]$jobs.Add(
                    [PSCustomObject]@{
                        PowerShell = $powershell
                        AsyncResult = $asyncResult
                        File = $file
                    }
                )

                $nextImage++
            }

            $finishedJob = $null

            foreach ($job in @($jobs)) {

                if ($job.AsyncResult.IsCompleted) {
                    $finishedJob = $job
                    break
                }
            }

            if ($null -eq $finishedJob) {

                [System.Windows.Forms.Application]::DoEvents()

                [System.Threading.Thread]::Sleep(10)

                continue
            }

            $result = $null

            try {
                $result = $finishedJob.PowerShell.EndInvoke(
                    $finishedJob.AsyncResult
                )
            }
            catch {
                Write-Host "Image worker failed: $($finishedJob.File.FullName)"
                Write-Host $_.Exception.Message
            }

            $finishedJob.PowerShell.Dispose()

            [void]$jobs.Remove($finishedJob)

            $completed++
            $index = $completed

            $percent = [int](($completed / $total) * 100)

            Update-Stage 3 $percent "Scanning image $completed of $total - $($finishedJob.File.Name)"

            if ($null -eq $result -or $result.Count -eq 0) {
                continue
            }

            $analysis = $result[0]

            if ($null -ne $analysis.Error) {

                Write-Host "Image read failed: $($analysis.Path)"
                Write-Host $analysis.Error

                continue
            }

            $stats = $analysis.Stats

            if ($null -eq $stats) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($stats.Reason)) {
                continue
            }

            $flagged++

            Write-Host ""
            Write-Host "SUSPICIOUS IMAGE:"
            Write-Host "  File   : $($finishedJob.File.FullName)"
            Write-Host "  Reason : $($stats.Reason)"
            Write-Host "  Action : QUEUED FOR RECYCLE REVIEW"

            [void]$flaggedItems.Add(
                [PSCustomObject]@{
                    File = $finishedJob.File
                    RelativePath = Get-RelativePath $Root $finishedJob.File.FullName
                    Reason = $stats.Reason
                }
            )
        }
    }
    finally {

        foreach ($job in @($jobs)) {

            try {
                $job.PowerShell.Stop()
            }
            catch {
            }

            try {
                $job.PowerShell.Dispose()
            }
            catch {
            }
        }

        $jobs.Clear()

        $runspacePool.Close()
        $runspacePool.Dispose()
    }

    if ($flaggedItems.Count -gt 0 -and -not $script:StageSkipRequested[3]) {

        $deleteApproved = Show-DeletionReviewDialog `
            "Image Deletion Review" `
            "Stage 3 found $($flaggedItems.Count) image(s) that meet the 100% uniform/empty criteria. Review the filenames below before anything is recycled." `
            @($flaggedItems)

        if ($deleteApproved) {
            foreach ($item in @($flaggedItems)) {
                if ($script:StageSkipRequested[3]) { break }
                $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                try {
                    Move-FileToRecycleBin -Path $item.File.FullName
                    $deleted++
                    Write-Host "Recycled image: $($item.File.FullName)"
                    Add-Content -LiteralPath $UniformLog -Value "$time | RECYCLED | $($item.Reason) | $($item.File.FullName)"
                }
                catch {
                    $failed++
                    Write-Host "FAILED TO DELETE: $($item.File.FullName)"
                    Write-Host $_.Exception.Message
                    Add-Content -LiteralPath $UniformLog -Value "$time | FAILED | $($item.Reason) | $($item.File.FullName) | $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Host "User skipped deletion of flagged images."
            Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | SKIPPED FLAGGED IMAGE DELETION | Count=$($flaggedItems.Count)"
        }
    }

    if ($script:StageSkipRequested[3]) {

        $summary = "Stage 3 skipped by user. Scanned $completed of $total images. Flagged $flagged. Deleted $deleted. Failed $failed."

        Write-Host ""
        Write-Host $summary

        Set-StageSkipped 3 $summary

        return $true
    }

    $summary = "Complete. Scanned $total images. Flagged $flagged. Deleted $deleted. Failed $failed."

    Write-Host ""
    Write-Host $summary

    Update-Stage 3 100 $summary

    return $true
}


# ============================================================
# BLACK-BAR DETECTION / CROP REVIEW
# ============================================================

function Test-DarkBorderRow {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Y,
        [int]$DarkThreshold,
        [double]$RequiredPercent
    )

    $dark = 0
    for ($x = 0; $x -lt $Bitmap.Width; $x++) {
        $p = $Bitmap.GetPixel($x,$Y)
        if ($p.R -le $DarkThreshold -and $p.G -le $DarkThreshold -and $p.B -le $DarkThreshold) {
            $dark++
        }
    }
    return (($dark / [double]$Bitmap.Width) * 100.0 -ge $RequiredPercent)
}

function Test-DarkBorderColumn {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$X,
        [int]$DarkThreshold,
        [double]$RequiredPercent
    )

    $dark = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        $p = $Bitmap.GetPixel($X,$y)
        if ($p.R -le $DarkThreshold -and $p.G -le $DarkThreshold -and $p.B -le $DarkThreshold) {
            $dark++
        }
    }
    return (($dark / [double]$Bitmap.Height) * 100.0 -ge $RequiredPercent)
}

function Get-BlackBarCrop {
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )

    $result = [pscustomobject]@{
        IsCandidate = $false
        Left = 0
        Top = 0
        Right = 0
        Bottom = 0
        Width = 0
        Height = 0
        OriginalWidth = 0
        OriginalHeight = 0
        Reason = ""
    }

    $bitmap = $null
    try {
        $source = [System.Drawing.Image]::FromFile($Path)
        try {
            $bitmap = New-Object System.Drawing.Bitmap($source)
        }
        finally {
            $source.Dispose()
        }

        $result.OriginalWidth = $bitmap.Width
        $result.OriginalHeight = $bitmap.Height

        if ($bitmap.Width -lt 80 -or $bitmap.Height -lt 80) {
            return $result
        }

        # Very conservative: a border row/column must be at least 98% near-black.
        # This avoids treating ordinary dark artwork as a black bar.
        # A candidate also requires black bars on two opposing sides.
        $darkThreshold = 18
        $requiredPercent = 98.0
        $minimumBar = 40
        $maxScanX = [int][math]::Floor($bitmap.Width * 0.25)
        $maxScanY = [int][math]::Floor($bitmap.Height * 0.25)

        $left = 0
        while ($left -lt $maxScanX -and (Test-DarkBorderColumn $bitmap $left $darkThreshold $requiredPercent)) {
            $left++
        }

        $right = 0
        while ($right -lt $maxScanX -and (Test-DarkBorderColumn $bitmap ($bitmap.Width - 1 - $right) $darkThreshold $requiredPercent)) {
            $right++
        }

        $top = 0
        while ($top -lt $maxScanY -and (Test-DarkBorderRow $bitmap $top $darkThreshold $requiredPercent)) {
            $top++
        }

        $bottom = 0
        while ($bottom -lt $maxScanY -and (Test-DarkBorderRow $bitmap ($bitmap.Height - 1 - $bottom) $darkThreshold $requiredPercent)) {
            $bottom++
        }

        if ($left -lt $minimumBar) { $left = 0 }
        if ($right -lt $minimumBar) { $right = 0 }
        if ($top -lt $minimumBar) { $top = 0 }
        if ($bottom -lt $minimumBar) { $bottom = 0 }

        # A black bar must occur on TWO OPPOSING SIDES.
        # Horizontal letterboxing = top + bottom.
        # Vertical pillarboxing = left + right.
        # A single dark edge is not enough to make an image a candidate.
        $horizontalBars = ($top -gt 0 -and $bottom -gt 0)
        $verticalBars   = ($left -gt 0 -and $right -gt 0)

        if (-not $horizontalBars -and -not $verticalBars) {
            return $result
        }

        # Only crop the opposing pair(s) that actually form a bar pattern.
        if (-not $horizontalBars) {
            $top = 0
            $bottom = 0
        }
        if (-not $verticalBars) {
            $left = 0
            $right = 0
        }

        $newWidth = $bitmap.Width - $left - $right
        $newHeight = $bitmap.Height - $top - $bottom

        if ($newWidth -lt 40 -or $newHeight -lt 40) {
            return $result
        }

        if ($left -eq 0 -and $right -eq 0 -and $top -eq 0 -and $bottom -eq 0) {
            return $result
        }

        $result.IsCandidate = $true
        $result.Left = $left
        $result.Top = $top
        $result.Right = $right
        $result.Bottom = $bottom
        $result.Width = $newWidth
        $result.Height = $newHeight
        $result.Reason = "Black bars detected: left=$left, top=$top, right=$right, bottom=$bottom"
        return $result
    }
    catch {
        return $result
    }
    finally {
        if ($bitmap) { try { $bitmap.Dispose() } catch { } }
    }
}

function New-CroppedImageTemp {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Crop
    )

    $source = $null
    $cropped = $null
    $graphics = $null
    $tempPath = $null
    $resultPath = $null

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Source image does not exist: $Path"
        }

        if ($null -eq $Crop) {
            throw "Black-bar crop data is null for: $Path"
        }

        $width  = [int]$Crop.Width
        $height = [int]$Crop.Height
        $left   = [int]$Crop.Left
        $top    = [int]$Crop.Top

        if ($width -le 0 -or $height -le 0) {
            throw "Invalid crop dimensions for '$Path': ${width}x${height}"
        }

        $source = [System.Drawing.Image]::FromFile($Path)
        $cropped = [System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($cropped)
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage(
            $source,
            ([System.Drawing.Rectangle]::new(0,0,$width,$height)),
            ([System.Drawing.Rectangle]::new($left,$top,$width,$height)),
            [System.Drawing.GraphicsUnit]::Pixel
        )

        $directory = [System.IO.Path]::GetDirectoryName($Path)
        $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

        switch ($ext) {
            ".png"  { $format = [System.Drawing.Imaging.ImageFormat]::Png }
            ".jpg"  { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            ".jpeg" { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            ".bmp"  { $format = [System.Drawing.Imaging.ImageFormat]::Bmp }
            ".gif"  { $format = [System.Drawing.Imaging.ImageFormat]::Gif }
            ".tif"  { $format = [System.Drawing.Imaging.ImageFormat]::Tiff }
            ".tiff" { $format = [System.Drawing.Imaging.ImageFormat]::Tiff }
            default { throw "Image format cannot be safely rewritten: $ext" }
        }

        # Keep the real image extension on the temporary file. This makes the
        # preview load reliably and still lets the final replacement preserve
        # the source image's original encoding.
        $tempName = "." + [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".RCCUCropTemp" + $ext
        $tempPath = Join-Path $directory $tempName

        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction Stop
        }

        $cropped.Save($tempPath,$format)

        if (-not (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
            throw "Cropped preview was not created: $tempPath"
        }

        $resultPath = [string]$tempPath
    }
    finally {
        if ($graphics) { try { $graphics.Dispose() } catch { } }
        if ($cropped) { try { $cropped.Dispose() } catch { } }
        if ($source) { try { $source.Dispose() } catch { } }
    }

    if ([string]::IsNullOrWhiteSpace($resultPath)) {
        throw "Cropped preview path was null for: $Path"
    }

    return $resultPath
}

function Replace-WithCroppedImage {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Crop
    )

    $tempPath = New-CroppedImageTemp -Path $Path -Crop $Crop
    try {
        [System.IO.File]::Copy($tempPath,$Path,$true)
    }
    catch {
        # File.Replace is safest on NTFS; fall back to a same-directory move if needed.
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            try { Remove-Item -LiteralPath $tempPath -Force } catch { }
        }
    }
}

function Show-BlackBarCropDialog {
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory=$true)]$Crop,
        [Parameter(Mandatory=$true)][string]$PreviewPath
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Icon = $script:RazorIcon
    $form.Text = "Black Bar Crop Review"
    $form.Size = [System.Drawing.Size]::new(1180,760)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MinimumSize = [System.Drawing.Size]::new(1000,650)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $form.Tag = "NO"

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Black bars detected"
    $title.Font = [System.Drawing.Font]::new("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
    $title.Location = [System.Drawing.Point]::new(18,14)
    $title.Size = [System.Drawing.Size]::new(500,32)
    $form.Controls.Add($title)

    $name = New-Object System.Windows.Forms.Label
    $name.Text = $File.FullName
    $name.Location = [System.Drawing.Point]::new(18,48)
    $name.Size = [System.Drawing.Size]::new(1120,28)
    $name.AutoEllipsis = $true
    $form.Controls.Add($name)

    $beforeLabel = New-Object System.Windows.Forms.Label
    $beforeLabel.Text = "BEFORE"
    $beforeLabel.Font = [System.Drawing.Font]::new("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $beforeLabel.Location = [System.Drawing.Point]::new(18,82)
    $beforeLabel.Size = [System.Drawing.Size]::new(540,26)
    $form.Controls.Add($beforeLabel)

    $afterLabel = New-Object System.Windows.Forms.Label
    $afterLabel.Text = "AFTER"
    $afterLabel.Font = [System.Drawing.Font]::new("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $afterLabel.Location = [System.Drawing.Point]::new(585,82)
    $afterLabel.Size = [System.Drawing.Size]::new(540,26)
    $form.Controls.Add($afterLabel)

    $before = New-Object System.Windows.Forms.PictureBox
    $before.Location = [System.Drawing.Point]::new(18,112)
    $before.Size = [System.Drawing.Size]::new(545,500)
    $before.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $before.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $before.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $before.Image = [System.Drawing.Image]::FromFile($File.FullName)
    $form.Controls.Add($before)

    $after = New-Object System.Windows.Forms.PictureBox
    $after.Location = [System.Drawing.Point]::new(585,112)
    $after.Size = [System.Drawing.Size]::new(545,500)
    $after.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $after.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $after.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $after.Image = [System.Drawing.Image]::FromFile($PreviewPath)
    $form.Controls.Add($after)

    $question = New-Object System.Windows.Forms.Label
    $question.Text = "Replace this image with the cropped version?"
    $question.Font = [System.Drawing.Font]::new("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $question.Location = [System.Drawing.Point]::new(18,622)
    $question.Size = [System.Drawing.Size]::new(520,28)
    $question.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $form.Controls.Add($question)

    $yes = New-Object System.Windows.Forms.Button
    $yes.Text = "YES"
    $yes.Location = [System.Drawing.Point]::new(565,620)
    $yes.Size = [System.Drawing.Size]::new(110,46)
    $yes.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $yes.Add_Click({ $form.Tag = "YES"; $form.Close() })
    $form.Controls.Add($yes)

    $no = New-Object System.Windows.Forms.Button
    $no.Text = "NO"
    $no.Location = [System.Drawing.Point]::new(683,620)
    $no.Size = [System.Drawing.Size]::new(110,46)
    $no.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $no.Add_Click({ $form.Tag = "NO"; $form.Close() })
    $form.Controls.Add($no)

    $delete = New-Object System.Windows.Forms.Button
    $delete.Text = "DELETE"
    $delete.Location = [System.Drawing.Point]::new(801,620)
    $delete.Size = [System.Drawing.Size]::new(105,46)
    $delete.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $delete.Add_Click({ $form.Tag = "DELETE"; $form.Close() })
    $form.Controls.Add($delete)

    $all = New-Object System.Windows.Forms.Button
    $all.Text = "YES TO ALL"
    $all.Location = [System.Drawing.Point]::new(914,620)
    $all.Size = [System.Drawing.Size]::new(120,46)
    $all.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $all.Add_Click({ $form.Tag = "YESALL"; $form.Close() })
    $form.Controls.Add($all)

    $noAll = New-Object System.Windows.Forms.Button
    $noAll.Text = "NO TO ALL"
    $noAll.Location = [System.Drawing.Point]::new(1042,620)
    $noAll.Size = [System.Drawing.Size]::new(120,46)
    $noAll.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $noAll.Add_Click({ $form.Tag = "NOALL"; $form.Close() })
    $form.Controls.Add($noAll)

    $form.Add_Resize({
        $bottom = $form.ClientSize.Height - 18
        $before.Height = [int][math]::Max(260,$bottom - $before.Top - 76)
        $after.Height = $before.Height
        $after.Left = [int][math]::Max(585,$form.ClientSize.Width - $after.Width - 18)
        $before.Width = [int][math]::Max(400,[math]::Floor(($form.ClientSize.Width - 51) / 2))
        $after.Width = $before.Width
        $after.Left = $form.ClientSize.Width - $after.Width - 18
        $afterLabel.Left = $after.Left
        $afterLabel.Width = $after.Width
        $question.Top = $form.ClientSize.Height - 138
        $yes.Top = $form.ClientSize.Height - 140
        $no.Top = $yes.Top
        $delete.Top = $yes.Top
        $all.Top = $yes.Top
        $noAll.Top = $yes.Top
        $noAll.Left = $form.ClientSize.Width - $noAll.Width - 18
        $all.Left = $noAll.Left - $all.Width - 8
        $delete.Left = $all.Left - $delete.Width - 8
        $no.Left = $delete.Left - $no.Width - 8
        $yes.Left = $no.Left - $yes.Width - 8
    })

    Set-DarkThemeForForm $form
    $form.ShowDialog() | Out-Null

    try { $before.Image.Dispose() } catch { }
    try { $after.Image.Dispose() } catch { }
    $before.Image = $null
    $after.Image = $null
    $form.Dispose()
    return [string]$form.Tag
}

function Invoke-BlackBarCropReview {
    Write-Host ""
    Write-Host "Stage 4 black-bar scan starting..."
    Add-Content -LiteralPath $UniformLog -Value ""
    Add-Content -LiteralPath $UniformLog -Value "BLACK-BAR CROP REVIEW - $(Get-Date)"

    $images = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsRccuRecoveryPath $_.FullName) -and
            -not (Test-IsRccuXmlNamedFile $_) -and
            ($ImageExtensions -contains $_.Extension.ToLowerInvariant())
        }
    )

    $total = $images.Count
    $checked = 0
    $candidates = New-Object System.Collections.Generic.List[object]

    Write-Host "Black-bar analysis workers: $Stage3Threads"

    # CPU-heavy black-bar detection runs in a runspace pool.  The UI/review
    # portion remains single-threaded so only the analysis is parallel.
    $darkRowFn = ${function:Test-DarkBorderRow}.ToString()
    $darkColFn = ${function:Test-DarkBorderColumn}.ToString()
    $cropFn = ${function:Get-BlackBarCrop}.ToString()
    $workerScript = {
        param([string]$ImagePath, [string]$DarkRowFunction, [string]$DarkColumnFunction, [string]$CropFunction)
        Set-Item -Path Function:Test-DarkBorderRow -Value ([scriptblock]::Create($DarkRowFunction))
        Set-Item -Path Function:Test-DarkBorderColumn -Value ([scriptblock]::Create($DarkColumnFunction))
        Set-Item -Path Function:Get-BlackBarCrop -Value ([scriptblock]::Create($CropFunction))
        $crop = Get-BlackBarCrop -Path $ImagePath
        [pscustomobject]@{ Path=$ImagePath; Crop=$crop }
    }

    $pool = [runspacefactory]::CreateRunspacePool(1,$Stage3Threads)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $next = 0
    try {
        while (($next -lt $total) -or $jobs.Count -gt 0) {
            if ($script:StopRequested -or $script:StageSkipRequested[4]) { break }
            while ($next -lt $total -and $jobs.Count -lt $Stage3Threads) {
                $file = $images[$next]
                $ps = [powershell]::Create()
                $ps.RunspacePool = $pool
                [void]$ps.AddScript($workerScript)
                [void]$ps.AddArgument($file.FullName)
                [void]$ps.AddArgument($darkRowFn)
                [void]$ps.AddArgument($darkColFn)
                [void]$ps.AddArgument($cropFn)
                [void]$jobs.Add([pscustomobject]@{PowerShell=$ps;AsyncResult=$ps.BeginInvoke();File=$file})
                $next++
            }
            $finished = @($jobs | Where-Object { $_.AsyncResult.IsCompleted })
            if ($finished.Count -eq 0) {
                [System.Windows.Forms.Application]::DoEvents()
                [System.Threading.Thread]::Sleep(10)
                continue
            }
            foreach ($job in $finished) {
                try {
                    $out = @($job.PowerShell.EndInvoke($job.AsyncResult))
                    foreach ($item in $out) {
                        if ($item.Crop -and $item.Crop.IsCandidate) {
                            [void]$candidates.Add([pscustomobject]@{File=$job.File;Crop=$item.Crop})
                        }
                    }
                } catch {
                    Write-Host "BLACK-BAR ANALYSIS FAILED: $($job.File.FullName) - $($_.Exception.Message)"
                } finally {
                    $job.PowerShell.Dispose()
                    [void]$jobs.Remove($job)
                    $checked++
                    $percent = if ($total -gt 0) { [int][math]::Round(($checked / [double]$total) * 100) } else { 100 }
                    Update-Stage 4 $percent "Checking black bars $checked of $total"
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    finally {
        foreach ($job in @($jobs)) { try { $job.PowerShell.Stop() } catch {}; try { $job.PowerShell.Dispose() } catch {} }
        try { $pool.Close(); $pool.Dispose() } catch {}
    }

    if ($script:StopRequested -or $script:StageSkipRequested[4]) {
        Write-Host "Black-bar crop review stopped by user."
        return $true
    }

    Write-Host "Black-bar scan complete. Candidates found: $($candidates.Count)"
    $yesAll = $false
    $noAll = $false
    $croppedCount = 0
    $deletedCount = 0
    $skippedCount = 0
    $failedCount = 0

    foreach ($candidate in $candidates) {
        if ($script:StopRequested -or $script:StageSkipRequested[4]) { break }

        $tempPreview = $null
        try {
            $tempPreview = New-CroppedImageTemp -Path $candidate.File.FullName -Crop $candidate.Crop

            if ($script:AutomaticYesAll) {
                Write-Host "[DANGER] AUTOMATIC: CROP -> $($candidate.File.FullName)"
                # Preserve the original, uncropped image before replacing it.
                # If the recycle/recovery operation fails, the original remains untouched.
                Move-FileToRecycleBin -Path $candidate.File.FullName
                [System.IO.File]::Copy($tempPreview,$candidate.File.FullName,$true)
                Remove-Item -LiteralPath $tempPreview -Force
                $tempPreview = $null
                $croppedCount++
                Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR AUTO-CROPPED | ORIGINAL RECYCLED | $($candidate.File.FullName) | $($candidate.Crop.OriginalWidth)x$($candidate.Crop.OriginalHeight) -> $($candidate.Crop.Width)x$($candidate.Crop.Height)"
                continue
            }

            if (-not $yesAll -and -not $noAll) {
                $decision = Show-BlackBarCropDialog -File $candidate.File -Crop $candidate.Crop -PreviewPath $tempPreview

                if ($decision -eq "STOP") {
                    $script:StopRequested = $true
                    $script:StageSkipRequested[4] = $true
                    break
                }

                if ($decision -eq "DELETE") {
                    try {
                        Move-FileToRecycleBin -Path $candidate.File.FullName
                        $deletedCount++
                        Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR DELETED | $($candidate.File.FullName)"
                        continue
                    }
                    catch {
                        $failedCount++
                        Write-Host "FAILED BLACK-BAR DELETE: $($candidate.File.FullName)"
                        Write-Host $_.Exception.Message
                        Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR DELETE FAILED | $($candidate.File.FullName) | $($_.Exception.Message)"
                        continue
                    }
                }

                if ($decision -eq "YESALL") {
                    $yesAll = $true
                }

                if ($decision -eq "NOALL") {
                    $noAll = $true
                }
                 
                if ($decision -eq "NO" -or $decision -eq "NOALL") {
                    $skippedCount++
                    Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR SKIPPED | $($candidate.File.FullName)"
                    continue
                }
            }

            if ($noAll) {
                $skippedCount++
                Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR SKIPPED BY NO TO ALL | $($candidate.File.FullName)"
                continue
            }

            # YES and YES TO ALL both replace the original only after the preview exists.
            try {
                # Use an explicit overwrite copy to avoid the PowerShell 5.1
                # File.Replace overload error on some systems/filesystems.
                [System.IO.File]::Copy($tempPreview,$candidate.File.FullName,$true)
                Remove-Item -LiteralPath $tempPreview -Force
            }
            catch {
                throw
            }
            $tempPreview = $null
            $croppedCount++
            Write-Host "Cropped black bars and replaced image: $($candidate.File.FullName)"
            Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR CROPPED | $($candidate.File.FullName) | $($candidate.Crop.OriginalWidth)x$($candidate.Crop.OriginalHeight) -> $($candidate.Crop.Width)x$($candidate.Crop.Height)"
        }
        catch {
            $failedCount++
            Write-Host "FAILED BLACK-BAR CROP: $($candidate.File.FullName)"
            Write-Host $_.Exception.Message
            Add-Content -LiteralPath $UniformLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | BLACK-BAR FAILED | $($candidate.File.FullName) | $($_.Exception.Message)"
        }
        finally {
            if (-not [string]::IsNullOrWhiteSpace($tempPreview)) {
                if (Test-Path -LiteralPath $tempPreview) { try { Remove-Item -LiteralPath $tempPreview -Force } catch { } }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    Write-Host "Black-bar crop results: Cropped=$croppedCount, Deleted=$deletedCount, Skipped=$skippedCount, Failed=$failedCount"
    return $true
}

# ============================================================
# STAGE 4 - STALE XML AUDIT
# ============================================================

function Invoke-StaleXmlAudit {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 6 - STALE XML AUDIT"
    Write-Host "============================================================"

    if (-not (Test-Path -LiteralPath $XmlChangesLog -PathType Leaf)) {
        Set-Content -LiteralPath $XmlChangesLog -Value "RetroBat XML Changes - $(Get-Date)"
        Add-Content -LiteralPath $XmlChangesLog -Value "System root: $Root"
        Add-Content -LiteralPath $XmlChangesLog -Value "Working XML: $TestXml"
        Add-Content -LiteralPath $XmlChangesLog -Value ""
    }

    if (-not (Test-Path -LiteralPath $TestXml -PathType Leaf)) {
        Write-Host "No gamelist_TEST.xml found."
        Update-Stage 6 100 "No gamelist_TEST.xml found. Nothing to audit."
        return $true
    }

    $Xml = Load-XmlSafe $TestXml

    if ($null -eq $Xml) {
        Update-Stage 6 100 "Could not load gamelist_TEST.xml."
        return $false
    }

    # Automatically remove game entries whose source file has already been removed.
    # This keeps FINAL VERIFICATION from failing over stale <game> nodes.
    $preVerifyGames = @(Get-XmlGameNodes $Xml)
    $autoRemovedStale = 0
    foreach ($game in $preVerifyGames) {
        $pathNode = $game.SelectSingleNode("./*[local-name()='path']")
        $removeEntry = $false
        $stalePathText = ""

        if ($null -eq $pathNode) {
            $removeEntry = $true
            $stalePathText = "<missing <path> element>"
        }
        else {
            $stalePathText = ([string]$pathNode.InnerText).Trim()
            if ([string]::IsNullOrWhiteSpace($stalePathText)) {
                $removeEntry = $true
            }
            else {
                $staleFull = Resolve-XmlPath $stalePathText
                if ($null -eq $staleFull -or -not (Test-Path -LiteralPath $staleFull -PathType Leaf)) {
                    $removeEntry = $true
                }
            }
        }

        if ($removeEntry) {
            $staleName = Get-XmlNodeText $game "name"
            if ([string]::IsNullOrWhiteSpace($staleName)) { $staleName = "<unnamed>" }
            Add-Content -LiteralPath $VerificationLog -Value "AUTO-REMOVED STALE GAME ENTRY | GAME=$staleName | PATH=$stalePathText | REASON=Source file is not present on disk."
            [void]$game.ParentNode.RemoveChild($game)
            $autoRemovedStale++
        }
    }

    if ($autoRemovedStale -gt 0) {
        Save-XmlSafe $Xml $TestXml
        Add-Content -LiteralPath $VerificationLog -Value "AUTO-REMOVED STALE GAME ENTRIES: $autoRemovedStale"
        Write-Host "Automatically removed $autoRemovedStale stale game entries from gamelist_TEST.xml."
        $Xml = Load-XmlSafe $TestXml
    }

    $games = @(Get-XmlGameNodes $Xml)
    $total = $games.Count

    if ($total -eq 0) {
        Update-Stage 6 100 "SAFETY STOP: gamelist_TEST.xml contains 0 game entries. The TEST XML was not allowed to replace the real gamelist."
        Write-Host "SAFETY STOP: gamelist_TEST.xml contains 0 game entries."
        Write-Host "The real gamelist.xml is left untouched."
        return $false
    }

    $stale = New-Object System.Collections.ArrayList

    $index = 0

    foreach ($game in $games) {

        if ($script:StageSkipRequested[6]) {
            Write-Host "STAGE 6 skipped by user."
            Set-StageSkipped 6 "STAGE 6 skipped by user. Stale XML audit was stopped."
            return $true
        }

        $index++

        $percent = [int](($index / $total) * 100)

        Update-Stage 6 $percent "Checking XML game path $index of $total"

        $pathNode = $game.SelectSingleNode("./*[local-name()='path']")

        if ($null -eq $pathNode) {
            [void]$stale.Add($game)
            continue
        }

        $xmlPath = [string]$pathNode.InnerText
        $full = Resolve-XmlPath $xmlPath

        if ($null -eq $full -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
            [void]$stale.Add($game)
        }
    }

    Write-Host "Stale XML entries found: $($stale.Count)"

    if ($stale.Count -eq 0) {
        Update-Stage 6 100 "No stale XML game entries found."
        return $true
    }

    $message = "Found $($stale.Count) XML entries whose game/source files no longer exist.`r`n`r`nCheck the stale entries you want removed. Nothing is removed until RECYCLE is pressed."

    $staleReviewItems = foreach ($game in $stale) {
        $stalePath = Get-XmlNodeText $game "path"
        $staleName = Get-XmlNodeText $game "name"
        [pscustomobject]@{
            RelativePath = if ([string]::IsNullOrWhiteSpace($stalePath)) { $staleName } else { $stalePath }
            Reason = if ([string]::IsNullOrWhiteSpace($staleName)) { "Stale/missing game source" } else { "$staleName | Stale/missing game source" }
            Game = $game
        }
    }

    $deleteReview = Show-DeletionReviewDialog "Stale XML Entries" $message @($staleReviewItems)

    if ($deleteReview.Action -ne "RECYCLE") {
        Write-Host "User skipped removal of stale entries."
        Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | SKIPPED | STALE XML ENTRIES | Count=$($stale.Count)"
        Update-Stage 6 100 "Found $($stale.Count) stale entries. None removed."
        return $true
    }

    $selectedDisplays = @($deleteReview.Items)
    $removedCount = 0
    foreach ($item in $staleReviewItems) {
        $display = "$($item.RelativePath) | $($item.Reason)"
        if ($selectedDisplays -notcontains $display) { continue }
        $stalePath = Get-XmlNodeText $item.Game "path"
        $staleName = Get-XmlNodeText $item.Game "name"
        Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | REMOVED | GAME=$staleName | TAG=<game> | PATH=$stalePath | REASON=Stale/missing game source"
        [void]$item.Game.ParentNode.RemoveChild($item.Game)
        $removedCount++
    }

    Save-XmlSafe $Xml $TestXml

    Write-Host "Stale entries removed from TEST XML: $removedCount."

    Update-Stage 6 100 "Removed $removedCount stale XML entries from gamelist_TEST.xml."

    return $true
}

# ============================================================
# MEDIA DISCOVERY
# ============================================================

function Get-MediaFiles {

    $result = New-Object System.Collections.ArrayList

    $directories = @(
        Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsRccuRecoveryPath $_.FullName) -and
            $MediaTagMap.ContainsKey($_.Name.ToLowerInvariant())
        }
    )

    foreach ($dir in $directories) {

        $category = $dir.Name.ToLowerInvariant()
        $tag = $MediaTagMap[$category]

        $files = @(
            Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                -not (Test-IsRccuRecoveryPath $_.FullName) -and
                -not (Test-IsRccuXmlNamedFile $_) -and
                $_.Extension -ine '.m3u'
            }
        )

        foreach ($file in $files) {

            if (Test-IsRccuXmlNamedFile $file) {
                continue
            }

            # M3U playlists are handled by Stage 2 duplicate review.  They are
            # never media candidates here, so an unmatched M3U can never be
            # reported as undefined/abandoned media in Stage 7.
            if ($file.Extension -ieq '.m3u') {
                continue
            }

            [void]$result.Add(
                [PSCustomObject]@{
                    File = $file
                    Category = $category
                    Tag = $tag
                    RelativePath = Get-RelativePath $Root $file.FullName
                }
            )
        }
    }

    return @(
        $result |
        Sort-Object RelativePath -Unique
    )
}

function Get-MediaBaseName {
    param(
        [System.IO.FileInfo]$File
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)

    foreach ($suffix in $IgnoredSuffixes) {
        if ($name.ToLowerInvariant().EndsWith($suffix)) {
            $name = $name.Substring(0,$name.Length - $suffix.Length)
            break
        }
    }

    # Media files normally use a hyphen before the media role.  Keep that
    # convention strict so titles such as "Back" or "Cover" are not damaged.
    # The two known exceptions below are supported because some collections
    # contain videos/manuals named "Game Namevideo.mp4" / "Game Namemanual.pdf".
    $knownSuffixes = @(
        "-screenmarqueesmall",
        "-screenshotlille",
        "-box2dback",
        "-box2dfront",
        "-box2dside",
        "-boxtexture",
        "-screenmarquee",
        "-screenshot",
        "-wheelcarbon",
        "-wheelsteel",
        "-clearlogo",
        "-thumbnail",
        "-marquee",
        "-fanart",
        "-boxback",
        "-box3d",
        "-video",
        "-manual",
        "-image",
        "-thumb",
        "-wheel",
        "-cover",
        "-front",
        "-back",
        "-logo",
        "-snap",
        "-title",
        "-artwork"
    )

    foreach ($suffix in $knownSuffixes) {
        if ($name.ToLowerInvariant().EndsWith($suffix)) {
            $name = $name.Substring(0,$name.Length - $suffix.Length)
            break
        }
    }

    # Explicitly support the known no-hyphen forms where the game title is
    # immediately followed by the media role, e.g. "Game (USA)video.mp4".
    # Requiring the title to end in ')' prevents legitimate titles ending in
    # words such as "Manual" or "Video" from being stripped accidentally.
    foreach ($suffix in @('video','manual')) {
        if ($name -match "\)$suffix$") {
            $name = $name.Substring(0,$name.Length - $suffix.Length).TrimEnd(' ','-','_')
            break
        }
    }

    # Numbered media pages/shots are part of the game title, not a different
    # game.  Collections commonly contain forms such as:
    #   "Mario 3-01.jpg"
    #   "Mario 3-011.jpg"
    #   "Mario 3-02.jpg"
    # Also tolerate whitespace before the sequence marker and repeated markers.
    # Strip only a trailing hyphen + 2 or more digits so normal title numbers
    # such as "Mario 3" remain untouched.
    do {
        $oldNumberedName = $name
        $name = $name -replace '\s*-\s*\d{2,}$',''
    } while ($name -ne $oldNumberedName)

    # Strip trailing release/dump metadata from the media matching key.
    # This is deliberately broader than a fixed list because TOSEC-style
    # collections use many flags: [m ...], [f ...], [cr ...], [beta], [v1.01],
    # etc.  A trailing square-bracket group is metadata for this collection.
    # This changes the matching key only; the physical filename is untouched.
    do {
        $oldMetaName = $name

        # First remove trailing square-bracket metadata, including stacked tags.
        $name = $name -replace '\s*\[[^\]]*\]\s*$',''

        # Then remove trailing parenthesized release/format flags.  Preserve
        # ANY parenthesized group containing DISC or DISK because those identify
        # a disc/disk and can be significant to the actual game identity.
        # Remove common flag-like groups such as (AGA), (SW), (SW-R), (PD),
        # (FW), (M4), (PL), and (preview), but do not remove descriptive groups
        # such as (Burlock, Craig) or (1995).
        if ($name -notmatch '\s*\([^)]*\b(?:disc|disk)\b[^)]*\)\s*$') {
            $name = $name -replace '\s*\((?:(?:[A-Z][A-Z0-9-]{0,7})|(?:preview|demo|sample|beta|proto(?:type)?))\)\s*$',''
        }

        # Manuals and some other supplied media use a filename-only region
        # suffix such as "_(eu)" or "_(us)".  It is not part of the game key.
        $name = $name -replace '[ _-]+\((?:eu|us|uk|sp|de|fr|it|es|pt|nl|se|no|dk|fi|cus)\)\s*$',''

        $name = $name.Trim(' ','.','-','_')
    } while ($name -ne $oldMetaName)

    # Strict media key: preserve region/revision information.  This lets
    # "Game (USA)-image.png" prefer "Game (USA).xip" over every regional copy.
    return ($name -replace '\s{2,}',' ').Trim().ToLowerInvariant()
}

function Get-XmlReferencedFileKeys {
    param(
        [xml]$Xml
    )

    $referenced = @{}

    if ($null -eq $Xml -or $null -eq $Xml.DocumentElement) {
        return $referenced
    }

    foreach ($game in @(Get-XmlGameNodes $Xml)) {
        foreach ($child in @($game.ChildNodes)) {
            if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) {
                continue
            }

            $value = ([string]$child.InnerText).Trim()
            if ([string]::IsNullOrWhiteSpace($value)) {
                continue
            }

            try {
                $resolved = Resolve-XmlPath $value
                if ($null -ne $resolved -and (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                    $key = [System.IO.Path]::GetFullPath($resolved).TrimEnd('\').ToLowerInvariant()
                    $referenced[$key] = $true
                }
            }
            catch {
                # An invalid/non-file XML value is not a physical reference.
            }
        }
    }

    return $referenced
}

function Get-RccuMediaTitleKey {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return "" }
    $n = [System.IO.Path]::GetFileNameWithoutExtension($Name)

    do {
        $old = $n
        $n = $n -replace '\s*-\s*\d{2,}$',''
        $n = $n -replace '\s*\[[^\]]*\]\s*$',''
        $n = $n -replace '[ _-]+\((?:eu|us|uk|sp|de|fr|it|es|pt|nl|se|no|dk|fi|cus)\)\s*$',''
        $n = $n -replace '\s*\([^)]*\)\s*$',''
        $n = $n.Trim(' ','.','-','_')
    } while ($n -ne $old)

    $n = $n.ToLowerInvariant()
    $n = $n -replace '[^\p{L}\p{N}]+',' '
    $n = $n -replace '\s+',' '
    return $n.Trim()
}


function Get-RccuPunctuationInsensitiveKey {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return "" }

    # Start from RCCU's existing conservative normalization so release/region
    # metadata is handled exactly as before.  Then remove punctuation ONLY.
    # Letters and numbers are deliberately retained, so 2.1 != 21 and
    # Game 3 != Game.
    $n = Get-NormalName $Name
    if ([string]::IsNullOrWhiteSpace($n)) { return "" }

    $n = $n -replace "[^\p{L}\p{N}]+", " "
    $n = $n -replace '\s+', ' '
    return $n.Trim().ToLowerInvariant()
}

# ============================================================
# STAGE 6 - MEDIA AUDIT
# ============================================================

function Invoke-MediaAudit {

    param(
        [xml]$RepairXml
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 7 - MEDIA AUDIT"
    Write-Host "============================================================"

    $gameFiles = @(Get-GameFiles)
    $mediaFiles = @(Get-MediaFiles)

    # --------------------------------------------------------
    # PROTECT EVERY PHYSICAL FILE REFERENCED BY THE WORKING XML
    # --------------------------------------------------------
    # The XML tag name is deliberately irrelevant here.  Manuals, PDFs,
    # custom media tags, maps, screenshots, videos, and future RetroBat tags
    # are all protected when their XML value resolves to an existing file.
    # --------------------------------------------------------
    $xmlReferencedMedia = Get-XmlReferencedFileKeys $RepairXml

    Write-Host "XML-referenced media protected from abandonment: $($xmlReferencedMedia.Count)"

    Write-Host "Actual game/source files: $($gameFiles.Count)"
    Write-Host "Recognized media files: $($mediaFiles.Count)"

    if ($mediaFiles.Count -eq 0) {

        Update-Stage 7 100 "No recognized media files found."

        return [PSCustomObject]@{
            Deleted = @()
            Unmatched = @()
            Ambiguous = @()
            Recognized = @()
        }
    }

    # Build strict, conservative, and XML-title-aware indexes.  XML title
    # aliases are important because TOSEC media filenames often contain dates,
    # publishers, dump flags and region suffixes that are absent from the game.
    $gameMap = @{}
    $normalizedGameMap = @{}
    $xmlTitleGameMap = @{}
    $punctuationInsensitiveGameMap = @{}

    foreach ($game in $gameFiles) {
        $strictKey = ([System.IO.Path]::GetFileNameWithoutExtension($game.Name) -replace '\s{2,}',' ').Trim().ToLowerInvariant()
        $normalizedKey = Get-NormalName $game.Name
        $titleKey = Get-RccuMediaTitleKey $game.Name

        foreach ($entry in @(
            [pscustomobject]@{ Map=$gameMap; Key=$strictKey }
            [pscustomobject]@{ Map=$normalizedGameMap; Key=$normalizedKey }
            [pscustomobject]@{ Map=$xmlTitleGameMap; Key=$titleKey }
            [pscustomobject]@{ Map=$punctuationInsensitiveGameMap; Key=(Get-RccuPunctuationInsensitiveKey $game.Name) }
        )) {
            if ([string]::IsNullOrWhiteSpace($entry.Key)) { continue }
            if (-not $entry.Map.ContainsKey($entry.Key)) {
                $entry.Map[$entry.Key] = New-Object System.Collections.ArrayList
            }
            [void]$entry.Map[$entry.Key].Add($game)
        }
    }

    # Add clean XML <name> values as aliases for the physical source file.
    foreach ($xmlGame in @(Get-XmlGameNodes $RepairXml)) {
        $pathText = Get-XmlNodeText $xmlGame 'path'
        $nameText = Get-XmlNodeText $xmlGame 'name'
        if ([string]::IsNullOrWhiteSpace($nameText)) { continue }

        $candidateGame = $null
        if (-not [string]::IsNullOrWhiteSpace($pathText)) {
            try {
                $sourceFull = Resolve-XmlPath $pathText
                $candidateGame = @($gameFiles | Where-Object { $_.FullName -ieq $sourceFull }) | Select-Object -First 1
            } catch { }
        }
        if ($null -eq $candidateGame) {
            $sourceName = [System.IO.Path]::GetFileName($pathText)
            if (-not [string]::IsNullOrWhiteSpace($sourceName)) {
                $candidateGame = @($gameFiles | Where-Object { $_.Name -ieq $sourceName }) | Select-Object -First 1
            }
        }

        if ($null -ne $candidateGame) {
            $xmlTitleKey = Get-RccuMediaTitleKey $nameText
            if (-not [string]::IsNullOrWhiteSpace($xmlTitleKey)) {
                if (-not $xmlTitleGameMap.ContainsKey($xmlTitleKey)) {
                    $xmlTitleGameMap[$xmlTitleKey] = New-Object System.Collections.ArrayList
                }
                $already = @($xmlTitleGameMap[$xmlTitleKey] | Where-Object { $_.FullName -ieq $candidateGame.FullName })
                if ($already.Count -eq 0) { [void]$xmlTitleGameMap[$xmlTitleKey].Add($candidateGame) }
            }
        }
    }

    $unmatched = New-Object System.Collections.ArrayList
    $ambiguous = New-Object System.Collections.ArrayList
    $recognized = New-Object System.Collections.ArrayList

    $index = 0
    $total = $mediaFiles.Count

    foreach ($media in $mediaFiles) {

        if ($script:StageSkipRequested[7]) {
            Write-Host "STAGE 7 skipped by user."
            Set-StageSkipped 7 "STAGE 7 skipped by user. Media audit was stopped."

            return [PSCustomObject]@{
                Deleted = @()
                Unmatched = @()
                Ambiguous = @()
                Recognized = @()
            }
        }

        $index++

        $percent = [int](($index / $total) * 100)

        Update-Stage 7 $percent "Matching media $index of $total - $($media.File.Name)"

        $key = Get-MediaBaseName $media.File
        $matches = @()
        $matchType = ""

        # Tier 1: strict filename match.
        if ($gameMap.ContainsKey($key)) {
            $matches = @($gameMap[$key])
            $matchType = "STRICT"
        }
        else {
            # Tier 2: existing conservative normalization.
            $normalizedKey = Get-NormalName $key
            if ($normalizedGameMap.ContainsKey($normalizedKey)) {
                $matches = @($normalizedGameMap[$normalizedKey])
                $matchType = "NORMALIZED"
            }
            else {
                # Tier 3: punctuation-insensitive matching.  This is a fallback
                # only; punctuation is ignored, but every letter and number is
                # preserved.  This catches apostrophe/dash/period differences
                # without collapsing distinct numbered titles.
                $punctuationKey = Get-RccuPunctuationInsensitiveKey $key
                if ($punctuationInsensitiveGameMap.ContainsKey($punctuationKey)) {
                    $matches = @($punctuationInsensitiveGameMap[$punctuationKey])
                    $matchType = "PUNCTUATION"
                }
                else {
                    # Tier 4: XML-title-aware matching for TOSEC-style media names.
                    # Multiple games with the same title key remain ambiguous.
                    $titleKey = Get-RccuMediaTitleKey $key
                    if ($xmlTitleGameMap.ContainsKey($titleKey)) {
                        $matches = @($xmlTitleGameMap[$titleKey])
                        $matchType = "XML TITLE"
                    }
                }
            }
        }

        if ($matches.Count -eq 1 -and ($matchType -eq "NORMALIZED" -or $matchType -eq "PUNCTUATION")) {
            Write-Host "Normalized media match:"
            Write-Host "  Media: $($media.File.FullName)"
            Write-Host "  Game : $($matches[0].FullName)"
        }

        if ($matches.Count -eq 0) {
            # Never recycle a media file that is already referenced by the XML,
            # even if its filename does not match an actual game/source file.
            $mediaKey = $null
            try {
                $mediaKey = [System.IO.Path]::GetFullPath($media.File.FullName).TrimEnd('\').ToLowerInvariant()
            } catch { }

            if ($null -ne $mediaKey -and $xmlReferencedMedia.ContainsKey($mediaKey)) {
                Write-Host "Protected XML-referenced media: $($media.File.FullName)"
                continue
            }

            # Auxiliary media such as -bezel is not permanently exempt.
            # If it is not XML-referenced and no game/source match exists,
            # send it to the normal review list for the user to decide.
            [void]$unmatched.Add($media)
            continue
        }

        if ($matches.Count -gt 1) {

            [void]$ambiguous.Add(
                [PSCustomObject]@{
                    Media = $media
                    Games = $matches
                }
            )

            continue
        }

        [void]$recognized.Add(
            [PSCustomObject]@{
                Media = $media
                Game = $matches[0]
                MatchType = $matchType
            }
        )
    }

    Write-Host "Recognized: $($recognized.Count)"
    Write-Host "Unmatched: $($unmatched.Count)"
    Write-Host "Ambiguous: $($ambiguous.Count)"

    if ($unmatched.Count -gt 0) {
        Write-Host ""
        Write-Host "POTENTIAL ABANDONED MEDIA (no exact or normalized game/source match yet):"
        foreach ($item in $unmatched) {
            Write-Host "  $($item.File.FullName)"
        }
    }

    foreach ($item in $ambiguous) {

        Write-Host ""
        Write-Host "AMBIGUOUS MEDIA: $($item.Media.File.FullName)"

        foreach ($game in $item.Games) {
            Write-Host "  Possible game: $($game.FullName)"
        }
    }

    # Deletion/recycle is intentionally deferred until AFTER STAGE 7 XML repair.
    # STAGE 7 only classifies media and reports candidates.
    $deleted = New-Object System.Collections.ArrayList


    if ($script:StageSkipRequested[7]) {
        Set-StageSkipped 7 "STAGE 7 skipped by user. Recognized $($recognized.Count), unmatched $($unmatched.Count), ambiguous $($ambiguous.Count), deleted $($deleted.Count)."

        return [PSCustomObject]@{
            Deleted = @($deleted)
            Unmatched = @($unmatched)
            Ambiguous = @($ambiguous)
            Recognized = @($recognized)
        }
    }

    $summary = "Complete. Recognized $($recognized.Count), unmatched $($unmatched.Count), ambiguous $($ambiguous.Count). Recycle review deferred until after XML repair."

    Update-Stage 7 100 $summary

    return [PSCustomObject]@{
        Deleted = @($deleted)
        Unmatched = @($unmatched)
        Ambiguous = @($ambiguous)
        Recognized = @($recognized)
    }
}

# ============================================================
# XML HELPERS
# ============================================================

function Get-GameNodeKey {
    param(
        $GameNode
    )

    if ($null -eq $GameNode) {
        return ""
    }

    $pathNode = $GameNode.SelectSingleNode(
        "./*[translate(local-name(),'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='path']"
    )

    if ($null -eq $pathNode) {
        return ""
    }

    $p = ([string]$pathNode.InnerText).Trim()

    if ([string]::IsNullOrWhiteSpace($p)) {
        return ""
    }

    $full = Resolve-XmlPath $p

    # Resolve-XmlPath can only return $null for an empty/invalid XML path.
    # Never pass a null value to Test-Path.
    if ($null -ne $full -and (Test-Path -LiteralPath $full -PathType Leaf)) {
        return Get-NormalName (
            [System.IO.Path]::GetFileName($full)
        )
    }

    return Get-NormalName (
        [System.IO.Path]::GetFileName($p)
    )
}

function Get-ExistingMediaRefs {
    param(
        $GameNode
    )

    $refs = New-Object System.Collections.ArrayList

    foreach ($child in @($GameNode.ChildNodes)) {

        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) {
            continue
        }

        if (
            $child.Name -eq "path" -or
            $child.Name -eq "name"
        ) {
            continue
        }

        $value = [string]$child.InnerText

        if (
            $value.StartsWith("./") -or
            $value.Contains("/")
        ) {

            [void]$refs.Add(
                [PSCustomObject]@{
                    Tag = $child.Name.ToLowerInvariant()
                    Path = $value
                    Node = $child
                }
            )
        }
    }

    return @($refs)
}

# ============================================================
# STAGE 7 - XML REPAIR
# ============================================================

function Invoke-XmlRepair {

    param(
        [xml]$SourceXml,
        $MediaAudit
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 8 - XML REPAIR"
    Write-Host "============================================================"

    Set-Content -LiteralPath $XmlChangesLog -Value "RetroBat XML Changes - $(Get-Date)"
    Add-Content -LiteralPath $XmlChangesLog -Value "System root: $Root"
    Add-Content -LiteralPath $XmlChangesLog -Value "Working XML: $TestXml"
    Add-Content -LiteralPath $XmlChangesLog -Value ""

    if ($null -eq $SourceXml) {
        Update-Stage 8 100 "XML repair stopped because the working TEST XML was not available."
        return $null
    }

    $sourceGameCount = @(Get-XmlGameNodes $SourceXml).Count

    if ($sourceGameCount -eq 0) {
        throw "STAGE 8 safety stop: gamelist_TEST.xml contains 0 game entries. No empty XML may replace the working library."
    }

    Save-XmlSafe $SourceXml $TestXml

    $Xml = Load-XmlSafe $TestXml

    if ($null -eq $Xml -or $null -eq $Xml.DocumentElement) {
        throw "STAGE 8 could not reload gamelist_TEST.xml after saving it."
    }

    $loadedGameCount = @(Get-XmlGameNodes $Xml).Count

    if ($loadedGameCount -ne $sourceGameCount) {
        throw "STAGE 8 XML validation failed after save: expected $sourceGameCount game entries but reloaded $loadedGameCount."
    }

    # --------------------------------------------------------
    # REMOVE XML MEDIA REFERENCES TO FILES THAT NO LONGER EXIST
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Checking XML for references to deleted/missing media..."

    $removedBrokenRefs = 0
    $gameNodesForCleanup = @(Get-XmlGameNodes $Xml)

    foreach ($node in $gameNodesForCleanup) {

        if ($script:StageSkipRequested[8]) {
            Write-Host "STAGE 8 skipped by user during XML cleanup."
            Save-XmlSafe $Xml $TestXml
            Set-StageSkipped 8 "STAGE 8 skipped by user during XML repair. Changes made before the skip were saved."
            return $Xml
        }

        foreach ($child in @($node.ChildNodes)) {

            if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) {
                continue
            }

            if (
                $child.Name -eq "path" -or
                $child.Name -eq "name" -or
                $child.Name -eq "desc" -or
                $child.Name -eq "rating" -or
                $child.Name -eq "releasedate" -or
                $child.Name -eq "developer" -or
                $child.Name -eq "publisher" -or
                $child.Name -eq "genre" -or
                $child.Name -eq "players" -or
                $child.Name -eq "playcount" -or
                $child.Name -eq "lastplayed" -or
                $child.Name -eq "favorite" -or
                $child.Name -eq "kidgame"
            ) {
                continue
            }

            $value = [string]$child.InnerText

            if (-not $value.StartsWith("./")) {
                continue
            }

            $mediaRelative = $value.Substring(2)

            $mediaFull = Resolve-XmlPath $value

            if (-not (Test-Path -LiteralPath $mediaFull -PathType Leaf)) {

                Write-Host "Removing broken XML media reference:"
                Write-Host "  Game: $($node.name)"
                Write-Host "  <$($child.Name)> $value"
                Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | REMOVED | GAME=$($node.name) | TAG=<$($child.Name)> | PATH=$value | REASON=Broken/missing media reference"

                [void]$node.RemoveChild($child)

                $removedBrokenRefs++
            }
        }
    }

    Write-Host "Broken XML media references removed: $removedBrokenRefs"

    $gameNodes = @(Get-XmlGameNodes $Xml)

    $nodeMap = @{}

    foreach ($node in $gameNodes) {

        $key = Get-GameNodeKey $node

        if ($key -ne "") {
            $nodeMap[$key] = $node
        }
    }

    # --------------------------------------------------------
    # ADD GAME ENTRIES THAT EXIST ON DISK BUT ARE MISSING FROM XML
    # --------------------------------------------------------
    #
    # Stage 4 removes stale XML entries whose source files are gone.
    # STAGE 8 now performs the complementary repair: every real game/source
    # file currently in the selected root that is absent from the TEST XML
    # receives a minimal, valid <game> entry.
    #
    # The new entry deliberately contains only information we can know safely:
    #   <path>./actual-file.ext</path>
    #   <name>actual-file-without-extension</name>
    #
    # Recognized media is added immediately afterward by the existing media
    # repair logic, so a newly-created game entry can receive its image/video
    # tags in the same run.
    # --------------------------------------------------------

    $actualGameFiles = @(Get-GameFiles)
    $newGameEntries = 0

    foreach ($gameFile in $actualGameFiles) {

        if ($script:StageSkipRequested[8]) {
            Save-XmlSafe $Xml $TestXml

            Write-Host "STAGE 8 skipped by user while adding missing game entries."

            Set-StageSkipped 8 "STAGE 8 skipped by user. Removed $removedBrokenRefs broken XML media refs and added $newGameEntries missing game entries before the skip."

            return $Xml
        }

        $key = Get-NormalName $gameFile.Name

        if ($nodeMap.ContainsKey($key)) {
            continue
        }

        $relativeGamePath = "./" + (Get-RelativePath $Root $gameFile.FullName)
        $gameName = [System.IO.Path]::GetFileNameWithoutExtension($gameFile.Name)

        # Use the same parent that contains existing <game> nodes whenever
        # possible.  This preserves the XML's existing structure.
        $parentNode = $null
        if ($gameNodes.Count -gt 0) {
            $parentNode = $gameNodes[0].ParentNode
        }
        if ($null -eq $parentNode) {
            $parentNode = $Xml.DocumentElement
        }

        $newGame = $Xml.CreateElement("game")

        $pathElement = $Xml.CreateElement("path")
        $pathElement.InnerText = $relativeGamePath
        [void]$newGame.AppendChild($pathElement)

        $nameElement = $Xml.CreateElement("name")
        $nameElement.InnerText = $gameName
        [void]$newGame.AppendChild($nameElement)

        [void]$parentNode.AppendChild($newGame)

        $nodeMap[$key] = $newGame
        $newGameEntries++

        Write-Host "Added missing game entry:"
        Write-Host "  Game: $gameName"
        Write-Host "  Path: $relativeGamePath"

        Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | ADDED GAME | GAME=$gameName | TAG=<game> | PATH=$relativeGamePath | REASON=Game/source file exists on disk but was missing from XML"
    }

    if ($newGameEntries -gt 0) {
        Write-Host "Missing game entries added to TEST XML: $newGameEntries"
    }
    else {
        Write-Host "No missing game entries were found."
    }

    # Rebuild the node map from the XML after adding entries so recognized
    # media can be attached to newly-created game nodes as well.
    $gameNodes = @(Get-XmlGameNodes $Xml)
    $nodeMap = @{}

    foreach ($node in $gameNodes) {
        $key = Get-GameNodeKey $node
        if ($key -ne "") {
            $nodeMap[$key] = $node
        }
    }

    $recognized = @($MediaAudit.Recognized)

    $total = $recognized.Count
    $added = 0
    $conflicts = 0
    $index = 0

    foreach ($item in $recognized) {

        if ($script:StageSkipRequested[8]) {
            Save-XmlSafe $Xml $TestXml

            Write-Host "STAGE 8 skipped by user."

            Set-StageSkipped 8 "STAGE 8 skipped by user. Removed $removedBrokenRefs broken XML media refs and added $added media references before the skip."

            return $Xml
        }

        $index++

        if ($total -gt 0) {
            $percent = [int](($index / $total) * 100)
        }
        else {
            $percent = 100
        }

        Update-Stage 8 $percent "Checking XML media $index of $total"

        $media = $item.Media
        $game = $item.Game

        $key = Get-NormalName $game.Name

        if (-not $nodeMap.ContainsKey($key)) {

            $candidate = @(
                $gameNodes |
                Where-Object {
                    (Get-GameNodeKey $_) -eq $key
                }
            )

            if ($candidate.Count -eq 1) {
                $node = $candidate[0]
            }
            else {
                continue
            }
        }
        else {
            $node = $nodeMap[$key]
        }

        $tag = $media.Tag.ToLowerInvariant()

        $existing = @(
            Get-ExistingMediaRefs $node |
            Where-Object {
                $_.Tag -eq $tag
            }
        )

        $relative = "./" + $media.RelativePath

        $alreadyExists = $false

        foreach ($ref in $existing) {

            if (
                $ref.Path.Replace('\','/').ToLowerInvariant() -eq
                $relative.ToLowerInvariant()
            ) {
                $alreadyExists = $true
                break
            }
        }

        if ($alreadyExists) {
            continue
        }

        if ($existing.Count -gt 0) {

            $conflicts++

            Write-Host ""
            Write-Host "MEDIA CONFLICT:"
            Write-Host "  Game: $($game.Name)"
            Write-Host "  Tag : <$tag>"
            Write-Host "  Existing: $($existing[0].Path)"
            Write-Host "  New     : $relative"
            Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | CONFLICT | GAME=$($game.Name) | TAG=<$tag> | EXISTING=$($existing[0].Path) | NEW=$relative"

            continue
        }

        $newNode = $Xml.CreateElement($tag)

        $newNode.InnerText = $relative

        [void]$node.AppendChild($newNode)

        $added++

        Write-Host "Added <$tag> to $($game.Name): $relative"
        Add-Content -LiteralPath $XmlChangesLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | ADDED | GAME=$($game.Name) | TAG=<$tag> | PATH=$relative"
    }

    Save-XmlSafe $Xml $TestXml

    $summary = "Complete. Removed $removedBrokenRefs broken XML media refs. Added $newGameEntries game entries. Added $added media references. Conflicts: $conflicts."

    Write-Host $summary

    Update-Stage 8 100 $summary

    return $Xml
}

# ============================================================
# POST-STAGE 6 - FINAL MEDIA ABANDONMENT REVIEW
# ============================================================

function Invoke-PostXmlMediaCleanup {
    param(
        $MediaAudit,
        [xml]$RepairedXml
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "POST-STAGE 6 - FINAL MEDIA ABANDONMENT REVIEW"
    Write-Host "============================================================"

    $deleted = New-Object System.Collections.ArrayList

    if ($null -eq $MediaAudit) {
        Write-Host "No Stage 6 media audit is available. Recycle review skipped."
        return [PSCustomObject]@{ Deleted=@(); Remaining=@() }
    }

    $unmatched = @($MediaAudit.Unmatched)

    if ($unmatched.Count -eq 0) {
        Write-Host "No unmatched media remains eligible for review."
        return [PSCustomObject]@{ Deleted=@(); Remaining=@() }
    }

    if ($null -eq $RepairedXml) {
        Write-Host "Repaired XML is unavailable. SAFETY STOP: no media will be recycled."
        return [PSCustomObject]@{ Deleted=@(); Remaining=@($unmatched) }
    }

    # Re-read the repaired TEST XML immediately before deletion.  This is the
    # final protection check, and the XML tag name is intentionally irrelevant.
    $xmlReferencedMedia = Get-XmlReferencedFileKeys $RepairedXml

    Write-Host "Repaired XML physical file references protected: $($xmlReferencedMedia.Count)"

    $stillUnmatched = New-Object System.Collections.ArrayList

    foreach ($item in $unmatched) {
        $mediaKey = $null

        try {
            $mediaKey = [System.IO.Path]::GetFullPath($item.File.FullName).TrimEnd('\').ToLowerInvariant()
        }
        catch {
        }

        if ($null -ne $mediaKey -and $xmlReferencedMedia.ContainsKey($mediaKey)) {
            Write-Host "Protected by repaired XML: $($item.File.FullName)"
            Add-Content -LiteralPath $MediaLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | PROTECTED BY XML | $($item.RelativePath)"
            continue
        }

        [void]$stillUnmatched.Add($item)
    }

    Write-Host "Still unmatched and unreferenced: $($stillUnmatched.Count)"

    # Always write a plain-text report of the final files that survived both
    # checks.  This makes it easy to inspect/report problematic names without
    # having to reproduce the GUI review list.
    $UnreferencedLog = Join-Path $Root "000-UnreferencedMedia.txt"
    try {
        $reportLines = New-Object System.Collections.Generic.List[string]
        [void]$reportLines.Add("RCCU UNREFERENCED MEDIA REPORT")
        [void]$reportLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$reportLines.Add("Root: $Root")
        [void]$reportLines.Add("Count: $($stillUnmatched.Count)")
        [void]$reportLines.Add("")

        foreach ($item in $stillUnmatched) {
            $baseName = Get-MediaBaseName $item.File
            $normalizedName = Get-NormalName $baseName
            [void]$reportLines.Add("FILE: $($item.RelativePath)")
            [void]$reportLines.Add("MEDIA KEY: $baseName")
            [void]$reportLines.Add("NORMALIZED KEY: $normalizedName")
            [void]$reportLines.Add("")
        }

        [System.IO.File]::WriteAllLines($UnreferencedLog, $reportLines)
        Write-Host "Unreferenced media report: $UnreferencedLog"
    }
    catch {
        Write-Host "WARNING: Could not write unreferenced media report: $($_.Exception.Message)"
    }

    if ($stillUnmatched.Count -eq 0) {
        Write-Host "Nothing remains eligible for recycle."
        return [PSCustomObject]@{ Deleted=@(); Remaining=@() }
    }

    $reviewItems = foreach ($item in $stillUnmatched) {
        [PSCustomObject]@{
            RelativePath = [string]$item.RelativePath
            Reason = "Still unmatched after XML repair"
            File = $item.File
        }
    }

    $message = "Stage 7 XML repair is complete. The files below are STILL unmatched to a game/source file AND are STILL not referenced anywhere in the repaired XML.`r`n`r`nOnly files that survive both checks are shown. Review the list before recycling anything."

    $deleteReview = Show-DeletionReviewDialog "Final Abandoned Media Review" $message @($reviewItems)

    if ($deleteReview.Action -ne "RECYCLE") {
        Write-Host "User skipped final deletion of unmatched media."
        Add-Content -LiteralPath $MediaLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | SKIPPED FINAL MEDIA DELETION | Count=$($stillUnmatched.Count)"
        return [PSCustomObject]@{
            Deleted = @()
            Remaining = @($stillUnmatched)
        }
    }

    $selectedDisplays = @($deleteReview.Items)

    foreach ($item in $stillUnmatched) {
        $display = "$($item.RelativePath) | Still unmatched after XML repair"
        if ($selectedDisplays -notcontains $display) {
            continue
        }

        if ($script:StopRequested -or $script:StageSkipRequested[7] -or $script:StageSkipRequested[8]) {
            Write-Host "Final media deletion stopped by user."
            break
        }

        # One final file-level XML protection check immediately before recycle.
        # This protects against anything that changed between the review and action.
        $latestXml = $null
        try {
            $latestXml = Load-XmlSafe $TestXml
        }
        catch {
            $latestXml = $null
        }

        if ($null -eq $latestXml) {
            Write-Host "SAFETY STOP: Could not reload repaired XML. No further media will be recycled."
            break
        }

        $latestRefs = Get-XmlReferencedFileKeys $latestXml
        $mediaKey = $null
        try {
            $mediaKey = [System.IO.Path]::GetFullPath($item.File.FullName).TrimEnd('\').ToLowerInvariant()
        }
        catch {
        }

        if ($null -ne $mediaKey -and $latestRefs.ContainsKey($mediaKey)) {
            Write-Host "Protected at final recycle check: $($item.File.FullName)"
            Add-Content -LiteralPath $MediaLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | FINAL PROTECTION | $($item.RelativePath)"
            continue
        }

        try {
            Move-FileToRecycleBin -Path $item.File.FullName
            [void]$deleted.Add($item.File.FullName)
            Write-Host "Recycled abandoned media: $($item.File.FullName)"
            Add-Content -LiteralPath $MediaLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | RECYCLED | $($item.RelativePath) | FINAL POST-XML REVIEW"
        }
        catch {
            Write-Host "FAILED TO DELETE MEDIA: $($item.File.FullName)"
            Write-Host $_.Exception.Message
            Add-Content -LiteralPath $MediaLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | FAILED DELETE | $($item.RelativePath) | $($_.Exception.Message)"
        }
    }

    $remaining = @(
        $stillUnmatched |
        Where-Object { $deleted -notcontains $_.File.FullName }
    )

    return [PSCustomObject]@{
        Deleted = @($deleted)
        Remaining = $remaining
    }
}

# ============================================================
# STAGE 5 - VIDEO NORMALIZATION
# ============================================================

function Find-VideoTool {
    param([Parameter(Mandatory=$true)][string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }

    $candidates = @(
        (Join-Path $PSScriptRoot $Name),
        (Join-Path $PSScriptRoot ("tools\\" + $Name)),
        "C:\\ffmpeg\\bin\\$Name",
        "C:\\Program Files\\ffmpeg\\bin\\$Name",
        "C:\\Program Files (x86)\\ffmpeg\\bin\\$Name"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Invoke-ExternalCapture {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Windows PowerShell 5.1 does not expose ProcessStartInfo.ArgumentList,
    # so build one correctly quoted command line instead of requiring PowerShell 7.
    $quotedArguments = foreach ($arg in $Arguments) {
        if ($null -eq $arg) { '""' }
        else { '"' + ([string]$arg).Replace('"','\"') + '"' }
    }
    $psi.Arguments = ($quotedArguments -join ' ')

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Get-VideoProbe {
    param(
        [Parameter(Mandatory=$true)][string]$Ffprobe,
        [Parameter(Mandatory=$true)][string]$VideoPath
    )

    $result = Invoke-ExternalCapture -FilePath $Ffprobe -Arguments @(
        '-v','error',
        '-print_format','json',
        '-show_streams',
        '-show_format',
        $VideoPath
    )

    if ($result.ExitCode -ne 0) {
        throw "ffprobe failed for '$VideoPath': $($result.StdErr.Trim())"
    }

    try {
        return ($result.StdOut | ConvertFrom-Json)
    }
    catch {
        throw "Could not parse ffprobe output for '$VideoPath': $($_.Exception.Message)"
    }
}

function Get-RationalNumber {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq '0/0') { return $null }
    if ($Value -match '^(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)$') {
        $den = [double]$Matches[2]
        if ($den -eq 0) { return $null }
        return ([double]$Matches[1] / $den)
    }
    try { return [double]$Value } catch { return $null }
}

function Get-BestCropFromDetect {
    param(
        [Parameter(Mandatory=$true)][string]$Ffmpeg,
        [Parameter(Mandatory=$true)][string]$VideoPath,
        [int]$FfmpegThreads = 1
    )

    $result = Invoke-ExternalCapture -FilePath $Ffmpeg -Arguments @(
        '-hide_banner','-nostats','-threads',[string]$FfmpegThreads,'-i',$VideoPath,
        '-vf','cropdetect=limit=20:round=2:reset=0:skip=2',
        '-an','-f','null','NUL'
    )

    $all = ($result.StdErr + "`r`n" + $result.StdOut)
    $matches = [regex]::Matches($all,'crop=(\d+):(\d+):(\d+):(\d+)')
    if ($matches.Count -eq 0) {
        return $null
    }

    # Use the largest detected picture area.  This avoids a later logo or
    # dark scene shrinking the crop after the stable letterbox has been found.
    $best = $null
    $bestArea = 0L
    foreach ($m in $matches) {
        $w = [int]$m.Groups[1].Value
        $h = [int]$m.Groups[2].Value
        $x = [int]$m.Groups[3].Value
        $y = [int]$m.Groups[4].Value
        $area = [int64]$w * [int64]$h
        if ($area -gt $bestArea) {
            $bestArea = $area
            $best = [PSCustomObject]@{ Width=$w; Height=$h; X=$x; Y=$y }
        }
    }
    return $best
}

function Get-BlackTrim {
    param(
        [Parameter(Mandatory=$true)][string]$Ffmpeg,
        [Parameter(Mandatory=$true)][string]$VideoPath,
        [Parameter(Mandatory=$true)][double]$Duration,
        [int]$FfmpegThreads = 1
    )

    if ($Duration -le 0) { return [PSCustomObject]@{ Start=0.0; End=$Duration } }

    $result = Invoke-ExternalCapture -FilePath $Ffmpeg -Arguments @(
        '-hide_banner','-nostats','-threads',[string]$FfmpegThreads,'-i',$VideoPath,
        '-vf','blackdetect=d=0.35:pix_th=0.10',
        '-an','-f','null','NUL'
    )

    $all = ($result.StdErr + "`r`n" + $result.StdOut)
    $matches = [regex]::Matches($all,'black_start:\s*([0-9\.]+)\s+black_end:\s*([0-9\.]+)')
    if ($matches.Count -eq 0) {
        return [PSCustomObject]@{ Start=0.0; End=$Duration }
    }

    $startTrim = 0.0
    $endTrim = $Duration

    # Remove only leading/trailing black intervals.  Internal black scenes are
    # left intact so RCCU does not destroy intentional cuts/fades.
    foreach ($m in $matches) {
        $bs = [double]$m.Groups[1].Value
        $be = [double]$m.Groups[2].Value
        if ($bs -le 0.15 -and $be -gt $startTrim) {
            $startTrim = $be
        }
    }

    for ($i = $matches.Count - 1; $i -ge 0; $i--) {
        $m = $matches[$i]
        $bs = [double]$m.Groups[1].Value
        $be = [double]$m.Groups[2].Value
        if ($be -ge ($Duration - 0.15) -and $bs -lt $endTrim) {
            $endTrim = $bs
        }
    }

    if ($endTrim -le $startTrim + 0.05) {
        return [PSCustomObject]@{ Start=0.0; End=$Duration }
    }

    return [PSCustomObject]@{ Start=$startTrim; End=$endTrim }
}

function Get-VideoEncoderSettings {
    param(
        [Parameter(Mandatory=$true)]$Probe,
        [Parameter(Mandatory=$true)][string]$Extension
    )

    $v = @($Probe.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
    $a = @($Probe.streams | Where-Object { $_.codec_type -eq 'audio' }) | Select-Object -First 1
    if ($null -eq $v) { throw 'No video stream found.' }

    $codec = [string]$v.codec_name
    $args = New-Object System.Collections.Generic.List[string]

    switch ($codec.ToLowerInvariant()) {
        'h264' { [void]$args.Add('libx264'); break }
        'hevc' { [void]$args.Add('libx265'); break }
        'mpeg4' { [void]$args.Add('mpeg4'); break }
        'mpeg2video' { [void]$args.Add('mpeg2video'); break }
        'vp8' { [void]$args.Add('libvpx'); break }
        'vp9' { [void]$args.Add('libvpx-vp9'); break }
        'av1' { [void]$args.Add('libaom-av1'); break }
        'wmv3' { [void]$args.Add('wmv3'); break }
        'wmv2' { [void]$args.Add('wmv2'); break }
        default { [void]$args.Add('libx264') }
    }

    $encoder = $args[0]
    $bitrate = Get-RationalNumber ([string]$v.bit_rate)
    if ($bitrate -and $bitrate -gt 0) {
        [void]$args.Add('-b:v'); [void]$args.Add(('{0}k' -f [math]::Max(1,[math]::Round($bitrate / 1000))))
    }
    else {
        # CRF is used only when the source does not expose a bitrate.  This
        # keeps the source's codec family instead of imposing a resolution cap.
        if ($encoder -eq 'libx264' -or $encoder -eq 'libx265') {
            [void]$args.Add('-crf'); [void]$args.Add('18')
        }
    }

    $fps = Get-RationalNumber ([string]$v.avg_frame_rate)
    if ($fps -and $fps -gt 0) {
        [void]$args.Add('-r'); [void]$args.Add(('{0:0.######}' -f $fps))
    }

    [void]$args.Add('-pix_fmt')
    [void]$args.Add('yuv420p')

    return [PSCustomObject]@{
        VideoEncoder=$encoder
        VideoArgs=@($args)
        AudioStream=$a
        SourceCodec=$codec
    }
}

function Invoke-FinalVideoNormalization {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 5 - VIDEO NORMALIZATION"
    Write-Host "============================================================"

    $ffmpeg = Find-VideoTool 'ffmpeg.exe'
    $ffprobe = Find-VideoTool 'ffprobe.exe'
    if (-not $ffmpeg -or -not $ffprobe) {
        $message = "STAGE 5 cannot run because FFmpeg and/or FFprobe was not found. Install FFmpeg and put ffmpeg.exe/ffprobe.exe in PATH, or place them beside RCCU."
        Set-Content -LiteralPath $VideoNormalizationLog -Value $message
        Update-Stage 5 100 $message
        Write-Host $message
        return $false
    }

    Set-Content -LiteralPath $VideoNormalizationLog -Value "RCCU Video Normalization - $(Get-Date)"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "System: $Root"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "FFmpeg: $ffmpeg"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "FFprobe: $ffprobe"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "Parallel FFmpeg jobs: $Stage9Threads"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "FFmpeg threads per job: $Stage9FfmpegThreadsPerJob"
    Add-Content -LiteralPath $VideoNormalizationLog -Value "Normalization: H.264 + AAC, yuv420p, constant 30 FPS (CFR), source resolution preserved."
    Add-Content -LiteralPath $VideoNormalizationLog -Value "Black-bar and black-frame scanning: DISABLED."
    Add-Content -LiteralPath $VideoNormalizationLog -Value ""

    $videoExtensions = @('.mp4','.mkv','.avi','.mov','.m4v','.wmv','.webm','.mpg','.mpeg','.ts','.m2ts','.3gp')
    $videoFiles = @(
        Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { ($_.Name -ieq 'videos' -or $_.Name -ieq 'video') -and -not (Test-IsRccuRecoveryPath $_.FullName) } |
        ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -File -ErrorAction SilentlyContinue |
            Where-Object {
                $videoExtensions -contains $_.Extension.ToLowerInvariant() -and
                -not (Test-IsRccuRecoveryPath $_.FullName) -and
                -not (Test-IsRccuXmlNamedFile $_)
            }
        }
    )
    $videoFiles = @($videoFiles | Sort-Object FullName -Unique)
    if ($videoFiles.Count -eq 0) {
        Add-Content -LiteralPath $VideoNormalizationLog -Value "No video files found in videos/video folders."
        Update-Stage 5 100 "No video files found in videos/video folders."
        return $true
    }

    Write-Host "Video normalization workers: $Stage9Threads ($Stage9FfmpegThreadsPerJob FFmpeg thread(s) per job)"
    Write-Host "Normalization target: H.264 / AAC / yuv420p / constant 30 FPS"
    $total = $videoFiles.Count
    $success = 0
    $failed = 0
    $completed = 0
    $percent = 0

    # This stage intentionally does NOT inspect black bars or black frames.
    # Its sole job is to make every video use a predictable playback format:
    # H.264 video, AAC audio, yuv420p pixel format, and constant 30 FPS.
    $workerScript = {
        param([string]$VideoPath,[string]$Ffmpeg,[string]$Ffprobe,[int]$FfmpegThreads)

        $temp = $null
        try {
            $probeArgs = @('-v','error','-print_format','json','-show_streams','-show_format',$VideoPath)
            $probeResult = & $Ffprobe @probeArgs 2>&1
            if ($LASTEXITCODE -ne 0) { throw "FFprobe failed: $($probeResult -join ' ')" }
            $probe = ($probeResult -join "`n") | ConvertFrom-Json
            $v = @($probe.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
            if ($null -eq $v) { throw 'No video stream found.' }

            $dir = [System.IO.Path]::GetDirectoryName($VideoPath)
            $ext = [System.IO.Path]::GetExtension($VideoPath)
            $temp = Join-Path $dir ('.RCCU_Normalize_' + [guid]::NewGuid().ToString('N') + $ext)

            $args = @(
                '-hide_banner','-y',
                '-threads',[string]$FfmpegThreads,
                '-i',$VideoPath,
                '-map','0:v:0',
                '-map','0:a:0?',
                '-sn',
                '-c:v','libx264',
                '-preset','medium',
                '-crf','20',
                '-pix_fmt','yuv420p',
                '-r','30',
                '-fps_mode','cfr',
                '-c:a','aac',
                '-b:a','160k',
                '-ar','48000',
                '-map_metadata','0',
                $temp
            )

            $stderrFile = Join-Path $env:TEMP ('RCCU_FFmpeg_' + [guid]::NewGuid().ToString('N') + '.log')
            try {
                # PowerShell 5.1's Start-Process -ArgumentList does not reliably
                # preserve spaces in individual arguments when given an array.
                # Quote every argument explicitly so video paths such as
                # "Super Mario World (USA).mp4" are passed to FFmpeg intact.
                $quotedArgs = ($args | ForEach-Object {
                    '"' + ([string]$_).Replace('"','\"') + '"'
                }) -join ' '
                $proc = Start-Process -FilePath $Ffmpeg -ArgumentList $quotedArgs -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrFile
                $exitCode = $proc.ExitCode
                $stderr = if (Test-Path -LiteralPath $stderrFile) { Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue } else { '' }
            }
            finally {
                if (Test-Path -LiteralPath $stderrFile -PathType Leaf) { Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue }
            }

            if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $temp -PathType Leaf)) {
                throw "FFmpeg normalization failed (exit $exitCode): $($stderr.Trim())"
            }

            $verifyArgs = @('-v','error','-print_format','json','-show_streams','-show_format',$temp)
            $verifyResult = & $Ffprobe @verifyArgs 2>&1
            if ($LASTEXITCODE -ne 0) { throw "FFprobe verification failed: $($verifyResult -join ' ')" }
            $verify = ($verifyResult -join "`n") | ConvertFrom-Json
            $verifyVideo = @($verify.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
            if ($null -eq $verifyVideo -or ([int]$verifyVideo.width -le 0) -or ([int]$verifyVideo.height -le 0)) {
                throw 'FFmpeg produced an invalid video stream.'
            }

            [pscustomobject]@{
                Success=$true
                Path=$VideoPath
                Temp=$temp
                Width=[int]$verifyVideo.width
                Height=[int]$verifyVideo.height
                Error=$null
            }
            $temp = $null
        }
        catch {
            [pscustomobject]@{Success=$false;Path=$VideoPath;Temp=$temp;Width=0;Height=0;Error=$_.Exception.Message}
        }
        finally {
            if ($temp -and (Test-Path -LiteralPath $temp -PathType Leaf)) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        }
    }

    $pool = [runspacefactory]::CreateRunspacePool(1,$Stage9Threads)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $next = 0
    try {
        while (($next -lt $total) -or $jobs.Count -gt 0) {
            if ($script:StopRequested -or $script:StageSkipRequested[5]) { break }

            while ($next -lt $total -and $jobs.Count -lt $Stage9Threads) {
                $video = $videoFiles[$next]
                $ps = [powershell]::Create(); $ps.RunspacePool = $pool
                [void]$ps.AddScript($workerScript)
                [void]$ps.AddArgument($video.FullName)
                [void]$ps.AddArgument($ffmpeg)
                [void]$ps.AddArgument($ffprobe)
                [void]$ps.AddArgument($Stage9FfmpegThreadsPerJob)
                $fileNumber = $next + 1
                Write-Host "Queued video $fileNumber of ${total}: $($video.FullName)"
                [void]$jobs.Add([pscustomobject]@{PowerShell=$ps;AsyncResult=$ps.BeginInvoke();File=$video})
                $next++
                Update-Stage 5 0 "Normalizing video $fileNumber of $total - $($video.Name)"
            }

            $finished = @($jobs | Where-Object { $_.AsyncResult.IsCompleted })
            if ($finished.Count -eq 0) {
                [System.Windows.Forms.Application]::DoEvents()
                [System.Threading.Thread]::Sleep(25)
                continue
            }

            foreach ($job in $finished) {
                $result = $null
                try {
                    $result = @($job.PowerShell.EndInvoke($job.AsyncResult)) | Select-Object -Last 1
                } catch {
                    $result = [pscustomobject]@{Success=$false;Path=$job.File.FullName;Temp=$null;Error=$_.Exception.Message}
                }

                $completed++
                $percent = [int][math]::Floor(($completed / [double]$total) * 100)

                try {
                    if ($result.Success -and $result.Temp -and (Test-Path -LiteralPath $result.Temp -PathType Leaf)) {
                        $rootDrive = [System.IO.Path]::GetPathRoot($job.File.FullName)
                        $driveInfo = [System.IO.DriveInfo]::new($rootDrive)
                        $isRemovable = ($driveInfo.DriveType -eq [System.IO.DriveType]::Removable)

                        if ($isRemovable) {
                            Remove-Item -LiteralPath $job.File.FullName -Force -ErrorAction Stop
                            Move-Item -LiteralPath $result.Temp -Destination $job.File.FullName -Force -ErrorAction Stop
                            $disposition = 'ORIGINAL OVERWRITTEN (REMOVABLE MEDIA - NO RECYCLE COPY)'
                        } else {
                            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($job.File.FullName,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                            Move-Item -LiteralPath $result.Temp -Destination $job.File.FullName -Force -ErrorAction Stop
                            $disposition = 'ORIGINAL SENT TO WINDOWS RECYCLE BIN'
                        }

                        Add-Content -LiteralPath $VideoNormalizationLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | OK | $($job.File.FullName) | H264 | AAC | yuv420p | CFR=30 | ${result.Width}x${result.Height} | $disposition"
                        $success++
                        Write-Host "NORMALIZED: $($job.File.Name) -> H.264/AAC 30 FPS (${result.Width}x${result.Height})"
                    } else {
                        $failed++
                        Add-Content -LiteralPath $VideoNormalizationLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | FAILED | $($job.File.FullName) | $($result.Error)"
                        Write-Host "FAILED VIDEO NORMALIZATION: $($job.File.FullName)"
                        Write-Host $result.Error
                    }
                }
                catch {
                    $failed++
                    Add-Content -LiteralPath $VideoNormalizationLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | FAILED REPLACEMENT | $($job.File.FullName) | $($_.Exception.Message)"
                    Write-Host "FAILED REPLACEMENT: $($job.File.FullName)"
                    Write-Host $_.Exception.Message
                    if ($result.Temp -and (Test-Path -LiteralPath $result.Temp -PathType Leaf)) { Remove-Item -LiteralPath $result.Temp -Force -ErrorAction SilentlyContinue }
                }
                finally {
                    if ($result.Temp -and (Test-Path -LiteralPath $result.Temp -PathType Leaf)) { Remove-Item -LiteralPath $result.Temp -Force -ErrorAction SilentlyContinue }
                    $job.PowerShell.Dispose()
                    [void]$jobs.Remove($job)
                    Write-Host "Completed video $completed of ${total}: $($job.File.FullName)"
                    Update-Stage 5 $percent "Completed video $completed of $total - $($job.File.Name)"
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    finally {
        foreach ($job in @($jobs)) { try { $job.PowerShell.Stop() } catch {}; try { $job.PowerShell.Dispose() } catch {} }
        try { $pool.Close(); $pool.Dispose() } catch {}
    }

    if ($script:StageSkipRequested[5]) {
        Set-StageSkipped 5 "STAGE 5 skipped by user. Normalized $success of $total video(s); $failed failed."
        return $false
    }
    if ($script:StopRequested) {
        Update-Stage 5 $percent "Stopped. Normalized $success of $total video(s); $failed failed."
        return $false
    }
    $summary = "Video normalization complete. $success succeeded, $failed failed. All processed videos were re-encoded to H.264/AAC, yuv420p, constant 30 FPS, with source resolution preserved."
    Add-Content -LiteralPath $VideoNormalizationLog -Value ""
    Add-Content -LiteralPath $VideoNormalizationLog -Value $summary
    Update-Stage 5 100 $summary
    return ($failed -eq 0)
}
function Invoke-FinalVerification {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 9 - FINAL VERIFICATION"
    Write-Host "============================================================"

    Set-Content -LiteralPath $VerificationLog -Value "RetroBat Final Verification Audit - $(Get-Date)"
    Add-Content -LiteralPath $VerificationLog -Value "System: $Root"
    Add-Content -LiteralPath $VerificationLog -Value "TEST XML: $TestXml"
    Add-Content -LiteralPath $VerificationLog -Value ""

    if (-not (Test-Path -LiteralPath $TestXml -PathType Leaf)) {
        $message = "VERIFICATION FAILED`r`n`r`ngamelist_TEST.xml does not exist.`r`n`r`nWHERE: $TestXml`r`nHOW: STAGE 9 could not load the working XML, so promotion is blocked."
        Write-Host $message
        Add-Content -LiteralPath $VerificationLog -Value $message
        Update-Stage 9 100 "VERIFICATION FAILED. gamelist_TEST.xml does not exist. See 000-VerificationAudit.txt."
        return $false
    }

    try {
        $Xml = Load-XmlSafe $TestXml
    }
    catch {
        $message = "VERIFICATION FAILED`r`n`r`nCould not parse gamelist_TEST.xml.`r`n`r`nWHERE: $TestXml`r`nHOW: XML parsing failed: $($_.Exception.Message)"
        Write-Host $message
        Add-Content -LiteralPath $VerificationLog -Value $message
        Update-Stage 9 100 "VERIFICATION FAILED. XML could not be parsed. See 000-VerificationAudit.txt."
        return $false
    }

    if ($null -eq $Xml -or $null -eq $Xml.DocumentElement) {
        $message = "VERIFICATION FAILED`r`n`r`nThe working XML loaded but has no document root.`r`n`r`nWHERE: $TestXml`r`nHOW: The file is not a usable XML document."
        Write-Host $message
        Add-Content -LiteralPath $VerificationLog -Value $message
        Update-Stage 9 100 "VERIFICATION FAILED. Working XML has no document root. See 000-VerificationAudit.txt."
        return $false
    }

    $games = @(Get-XmlGameNodes $Xml)
    $total = $games.Count

    # The working TEST XML must never lose the entire game list between stages.
    # Compare it with the real baseline before doing any final verification.
    $realBaseline = Load-XmlSafe $RealXml
    $realGameCount = @(Get-XmlGameNodes $realBaseline).Count

    Add-Content -LiteralPath $VerificationLog -Value "XML root element     : $($Xml.DocumentElement.Name)"
    Add-Content -LiteralPath $VerificationLog -Value "Real baseline games  : $realGameCount"
    Add-Content -LiteralPath $VerificationLog -Value "XML game nodes found : $total"
    Add-Content -LiteralPath $VerificationLog -Value ""

    $missingGames = New-Object System.Collections.ArrayList
    $duplicatePaths = New-Object System.Collections.ArrayList
    $brokenMedia = New-Object System.Collections.ArrayList

    $seenPaths = @{}
    $pathOwners = @{}

    if ($total -eq 0) {
        $message = "VERIFICATION FAILED`r`n`r`nNo <game> elements were found in the working XML.`r`n`r`nWHERE: $TestXml`r`nHOW: The TEST XML is valid XML, but its game list disappeared before final verification. The real gamelist.xml was not touched and the TEST XML was not promoted."
        Write-Host $message
        Add-Content -LiteralPath $VerificationLog -Value $message
        Update-Stage 9 100 "VERIFICATION FAILED. No <game> entries found in the working XML. See 000-VerificationAudit.txt."
        return $false
    }

    # Additional game entries are now an intentional repair result.
    # STAGE 9 therefore does NOT reject TEST XML simply because it contains
    # more entries than the old baseline.  Instead, it verifies that every
    # actual game/source file currently on disk has an XML entry.
    Add-Content -LiteralPath $VerificationLog -Value "Additional game entries beyond baseline: $([math]::Max(0,$total - $realGameCount))"
    Add-Content -LiteralPath $VerificationLog -Value "Additional game entries are allowed when their source files exist."
    Add-Content -LiteralPath $VerificationLog -Value ""

    $index = 0

    foreach ($game in $games) {

        if ($script:StageSkipRequested[9]) {
            Write-Host "STAGE 9 skipped by user."
            Set-StageSkipped 9 "STAGE 9 skipped by user. Promotion is blocked because final verification was not completed."
            return $false
        }

        $index++
        $percent = [int](($index / $total) * 100)
        Update-Stage 9 $percent "Verifying XML game $index of $total"

        $gameName = Get-XmlNodeText $game "name"
        if ([string]::IsNullOrWhiteSpace($gameName)) {
            $gameName = "<unnamed game entry #$index>"
        }

        $pathNode = $game.SelectSingleNode("./*[local-name()='path']")

        if ($null -eq $pathNode) {
            [void]$missingGames.Add(
                [PSCustomObject]@{
                    Game = $gameName
                    XmlPath = "<missing <path> element>"
                    FullPath = "<cannot determine>"
                    How = "The XML game entry has no <path> element."
                }
            )
            continue
        }

        $relative = ([string]$pathNode.InnerText).Trim()

        if ([string]::IsNullOrWhiteSpace($relative)) {
            [void]$missingGames.Add(
                [PSCustomObject]@{
                    Game = $gameName
                    XmlPath = "<empty <path> element>"
                    FullPath = "<cannot determine>"
                    How = "The XML game entry has a <path> element, but it is empty."
                }
            )
            continue
        }

        if ($relative.StartsWith("./")) {
            $relative = $relative.Substring(2)
        }

        $normalizedPath = $relative.Replace('\','/').ToLowerInvariant()

        if ($seenPaths.ContainsKey($normalizedPath)) {
            $firstOwner = $pathOwners[$normalizedPath]
            [void]$duplicatePaths.Add(
                [PSCustomObject]@{
                    Path = $relative
                    Game = $gameName
                    FirstGame = $firstOwner.Game
                    FirstXmlPath = $firstOwner.XmlPath
                }
            )
        }
        else {
            $seenPaths[$normalizedPath] = $true
            $pathOwners[$normalizedPath] = [PSCustomObject]@{
                Game = $gameName
                XmlPath = $relative
            }
        }

        $fullGame = Resolve-XmlPath $relative

        if (-not (Test-Path -LiteralPath $fullGame -PathType Leaf)) {
            [void]$missingGames.Add(
                [PSCustomObject]@{
                    Game = $gameName
                    XmlPath = $relative
                    FullPath = $fullGame
                    How = "The XML <path> points to a game/source file that does not exist."
                }
            )
        }

        foreach ($child in @($game.ChildNodes)) {

            if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) {
                continue
            }

            $childName = $child.Name.ToLowerInvariant()

            if (
                $childName -eq "path" -or
                $childName -eq "name" -or
                $childName -eq "desc" -or
                $childName -eq "rating" -or
                $childName -eq "releasedate" -or
                $childName -eq "developer" -or
                $childName -eq "publisher" -or
                $childName -eq "genre" -or
                $childName -eq "players" -or
                $childName -eq "playcount" -or
                $childName -eq "lastplayed" -or
                $childName -eq "favorite" -or
                $childName -eq "kidgame"
            ) {
                continue
            }

            $value = ([string]$child.InnerText).Trim()

            if (-not $value.StartsWith("./")) {
                continue
            }

            $mediaRelative = $value.Substring(2)
            $mediaFull = Resolve-XmlPath $value

            if (-not (Test-Path -LiteralPath $mediaFull -PathType Leaf)) {
                [void]$brokenMedia.Add(
                    [PSCustomObject]@{
                        Game = $gameName
                        GameXmlPath = $relative
                        Tag = $child.Name
                        XmlReference = $value
                        FullPath = $mediaFull
                        How = "The XML contains a media reference, but the referenced file does not exist."
                    }
                )
            }
        }
    }

    # --------------------------------------------------------
    # VERIFY THAT EVERY ACTUAL GAME/SOURCE FILE HAS AN XML ENTRY
    # --------------------------------------------------------
    $missingXmlEntries = New-Object System.Collections.ArrayList

    foreach ($actualGame in @(Get-GameFiles)) {

        $actualRelative = Get-RelativePath $Root $actualGame.FullName
        $actualKey = $actualRelative.Replace('\','/').ToLowerInvariant()

        if (-not $seenPaths.ContainsKey($actualKey)) {
            [void]$missingXmlEntries.Add(
                [PSCustomObject]@{
                    Game = [System.IO.Path]::GetFileNameWithoutExtension($actualGame.Name)
                    XmlPath = "./$actualRelative"
                    FullPath = $actualGame.FullName
                    How = "A real game/source file exists on disk, but the TEST XML contains no <game> entry for it."
                }
            )
        }
    }

    Write-Host ""
    Write-Host "XML root element     : $($Xml.DocumentElement.Name)"
    Write-Host "XML game entries     : $($games.Count)"
    Write-Host "Missing game paths   : $($missingGames.Count)"
    Write-Host "Missing XML entries  : $($missingXmlEntries.Count)"
    Write-Host "Duplicate XML paths  : $($duplicatePaths.Count)"
    Write-Host "Broken media refs    : $($brokenMedia.Count)"
    Write-Host "Unreferenced media   : NOT A VERIFICATION FAILURE"

    Add-Content -LiteralPath $VerificationLog -Value "XML root element     : $($Xml.DocumentElement.Name)"
    Add-Content -LiteralPath $VerificationLog -Value "XML game entries     : $($games.Count)"
    Add-Content -LiteralPath $VerificationLog -Value "Missing game paths   : $($missingGames.Count)"
    Add-Content -LiteralPath $VerificationLog -Value "Missing XML entries  : $($missingXmlEntries.Count)"
    Add-Content -LiteralPath $VerificationLog -Value "Duplicate XML paths  : $($duplicatePaths.Count)"
    Add-Content -LiteralPath $VerificationLog -Value "Broken media refs    : $($brokenMedia.Count)"
    Add-Content -LiteralPath $VerificationLog -Value "Unreferenced media   : NOT A VERIFICATION FAILURE"
    Add-Content -LiteralPath $VerificationLog -Value ""

    if ($missingGames.Count -gt 0) {
        Write-Host ""
        Write-Host "MISSING GAME PATHS:"
        Add-Content -LiteralPath $VerificationLog -Value "MISSING GAME PATHS:"

        foreach ($item in $missingGames) {
            Write-Host ""
            Write-Host "  WHAT: Missing/invalid game source"
            Write-Host "  GAME: $($item.Game)"
            Write-Host "  XML : $($item.XmlPath)"
            Write-Host "  FULL: $($item.FullPath)"
            Write-Host "  HOW : $($item.How)"

            Add-Content -LiteralPath $VerificationLog -Value ""
            Add-Content -LiteralPath $VerificationLog -Value "  WHAT: Missing/invalid game source"
            Add-Content -LiteralPath $VerificationLog -Value "  GAME: $($item.Game)"
            Add-Content -LiteralPath $VerificationLog -Value "  XML : $($item.XmlPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  FULL: $($item.FullPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  HOW : $($item.How)"
        }

        Add-Content -LiteralPath $VerificationLog -Value ""
    }

    if ($missingXmlEntries.Count -gt 0) {
        Write-Host ""
        Write-Host "MISSING XML GAME ENTRIES:"
        Add-Content -LiteralPath $VerificationLog -Value "MISSING XML GAME ENTRIES:"

        foreach ($item in $missingXmlEntries) {
            Write-Host ""
            Write-Host "  WHAT: Game/source exists on disk but has no XML entry"
            Write-Host "  GAME: $($item.Game)"
            Write-Host "  XML : $($item.XmlPath)"
            Write-Host "  FULL: $($item.FullPath)"
            Write-Host "  HOW : $($item.How)"

            Add-Content -LiteralPath $VerificationLog -Value ""
            Add-Content -LiteralPath $VerificationLog -Value "  WHAT: Game/source exists on disk but has no XML entry"
            Add-Content -LiteralPath $VerificationLog -Value "  GAME: $($item.Game)"
            Add-Content -LiteralPath $VerificationLog -Value "  XML : $($item.XmlPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  FULL: $($item.FullPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  HOW : $($item.How)"
        }

        Add-Content -LiteralPath $VerificationLog -Value ""
    }

    if ($duplicatePaths.Count -gt 0) {
        Write-Host ""
        Write-Host "DUPLICATE XML PATHS:"
        Add-Content -LiteralPath $VerificationLog -Value "DUPLICATE XML PATHS:"

        foreach ($item in $duplicatePaths) {
            Write-Host ""
            Write-Host "  WHAT       : Duplicate XML game path"
            Write-Host "  PATH       : $($item.Path)"
            Write-Host "  GAME       : $($item.Game)"
            Write-Host "  FIRST GAME : $($item.FirstGame)"
            Write-Host "  FIRST PATH : $($item.FirstXmlPath)"
            Write-Host "  HOW        : More than one XML game entry points to the same normalized ROM/source path."

            Add-Content -LiteralPath $VerificationLog -Value ""
            Add-Content -LiteralPath $VerificationLog -Value "  WHAT       : Duplicate XML game path"
            Add-Content -LiteralPath $VerificationLog -Value "  PATH       : $($item.Path)"
            Add-Content -LiteralPath $VerificationLog -Value "  GAME       : $($item.Game)"
            Add-Content -LiteralPath $VerificationLog -Value "  FIRST GAME : $($item.FirstGame)"
            Add-Content -LiteralPath $VerificationLog -Value "  FIRST PATH : $($item.FirstXmlPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  HOW        : More than one XML game entry points to the same normalized ROM/source path."
        }

        Add-Content -LiteralPath $VerificationLog -Value ""
    }

    if ($brokenMedia.Count -gt 0) {
        Write-Host ""
        Write-Host "BROKEN MEDIA REFERENCES:"
        Add-Content -LiteralPath $VerificationLog -Value "BROKEN MEDIA REFERENCES:"

        foreach ($item in $brokenMedia) {
            Write-Host ""
            Write-Host "  WHAT : Broken media reference"
            Write-Host "  GAME : $($item.Game)"
            Write-Host "  GAME XML PATH: $($item.GameXmlPath)"
            Write-Host "  TAG  : <$($item.Tag)>"
            Write-Host "  XML  : $($item.XmlReference)"
            Write-Host "  FULL : $($item.FullPath)"
            Write-Host "  HOW  : $($item.How)"

            Add-Content -LiteralPath $VerificationLog -Value ""
            Add-Content -LiteralPath $VerificationLog -Value "  WHAT : Broken media reference"
            Add-Content -LiteralPath $VerificationLog -Value "  GAME : $($item.Game)"
            Add-Content -LiteralPath $VerificationLog -Value "  GAME XML PATH: $($item.GameXmlPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  TAG  : <$($item.Tag)>"
            Add-Content -LiteralPath $VerificationLog -Value "  XML  : $($item.XmlReference)"
            Add-Content -LiteralPath $VerificationLog -Value "  FULL : $($item.FullPath)"
            Add-Content -LiteralPath $VerificationLog -Value "  HOW  : $($item.How)"
        }

        Add-Content -LiteralPath $VerificationLog -Value ""
    }

    Add-Content -LiteralPath $VerificationLog -Value "NOTE: Unreferenced media files are intentionally not treated as verification failures."
    Add-Content -LiteralPath $VerificationLog -Value "NOTE: Abandoned media means Stage 5 found no exact or name-normalized actual game/source match."
    Add-Content -LiteralPath $VerificationLog -Value "NOTE: Recognized media that matches a game is handled by Stage 6 XML Repair."
    Add-Content -LiteralPath $VerificationLog -Value "Only broken XML references, missing game/source files, missing XML game entries, and duplicate XML paths block promotion."

    $clean = (
        $missingGames.Count -eq 0 -and
        $missingXmlEntries.Count -eq 0 -and
        $duplicatePaths.Count -eq 0 -and
        $brokenMedia.Count -eq 0
    )

    if ($clean) {
        $summary = "VERIFICATION CLEAN. $($games.Count) games. 0 missing sources. 0 missing XML entries. 0 duplicate paths. 0 broken media references."
        Write-Host $summary
        Add-Content -LiteralPath $VerificationLog -Value ""
        Add-Content -LiteralPath $VerificationLog -Value $summary
        Update-Stage 9 100 "$summary See 000-VerificationAudit.txt."
        return $true
    }

    $summary = "VERIFICATION FAILED. Missing sources: $($missingGames.Count). Missing XML entries: $($missingXmlEntries.Count). Duplicate paths: $($duplicatePaths.Count). Broken media: $($brokenMedia.Count). See 000-VerificationAudit.txt for WHAT, WHERE, and HOW."
    Write-Host ""
    Write-Host $summary
    Add-Content -LiteralPath $VerificationLog -Value ""
    Add-Content -LiteralPath $VerificationLog -Value $summary
    Update-Stage 9 100 $summary

    return $false
}

# ============================================================
# BACKUP NAME
# ============================================================

function Get-NextBackupName {

    $candidate = Join-Path $Root "gamelist.backup.xml"

    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $n = 1

    while ($true) {

        $candidate = Join-Path $Root "gamelist$n.backup.xml"

        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }

        $n++
    }
}

# ============================================================
# STAGE 9 - FINAL VERIFICATION & PROMOTION
# ============================================================

function Invoke-FinalPromotion {

    param(
        [bool]$VerificationClean
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "STAGE 9 - FINAL VERIFICATION & PROMOTION"
    Write-Host "============================================================"

    if ($script:StageSkipRequested[9]) {

        Write-Host "STAGE 9 skipped by user."

        Set-StageSkipped 9 "STAGE 9 skipped by user. Real gamelist.xml was left untouched."

        return $true
    }

    if (-not $VerificationClean) {

        Update-Stage 9 100 "Promotion skipped because verification was not clean."

        return $false
    }

    if (-not (Test-Path -LiteralPath $TestXml)) {

        Update-Stage 9 100 "Promotion skipped because gamelist_TEST.xml does not exist."

        return $false
    }

    $message = "Verification is clean.`r`n`r`nPromote gamelist_TEST.xml to gamelist.xml?"

    if (-not (Show-YesNo "Promote XML" $message)) {

        Write-Host "User chose not to promote TEST XML."

        Update-Stage 9 100 "Promotion declined. Real gamelist.xml was left untouched."

        return $true
    }

    Update-Stage 9 20 "Preparing backup..."

    $backup = Get-NextBackupName

    Write-Host "Backup target: $backup"

    try {

        if (Test-Path -LiteralPath $RealXml) {

            Move-Item `
                -LiteralPath $RealXml `
                -Destination $backup `
                -Force:$false

            Write-Host "Original gamelist.xml backed up to:"
            Write-Host $backup
        }

        if ($script:StageSkipRequested[8]) {
            Write-Host "STAGE 9 skipped by user before promotion."
            Set-StageSkipped 9 "STAGE 9 skipped by user. Real gamelist.xml was left untouched."
            return $true
        }

        Update-Stage 9 60 "Original XML backed up. Promoting TEST XML..."

        Move-Item `
            -LiteralPath $TestXml `
            -Destination $RealXml `
            -Force:$false

        Update-Stage 9 100 "Promotion complete. gamelist_TEST.xml is now gamelist.xml."

        Write-Host "PROMOTION COMPLETE."

        return $true
    }
    catch {

        Write-Host ""
        Write-Host "PROMOTION FAILED:"
        Write-Host $_.Exception.Message

        Update-Stage 9 70 "Promotion failed. Attempting restoration..."

        try {

            if (
                (Test-Path -LiteralPath $backup) -and
                (-not (Test-Path -LiteralPath $RealXml))
            ) {

                Move-Item `
                    -LiteralPath $backup `
                    -Destination $RealXml `
                    -Force:$false

                Write-Host "Original gamelist.xml restored."

                Update-Stage 9 100 "Promotion failed. Original gamelist.xml restored."
            }
            else {

                Update-Stage 9 100 "Promotion failed. Manual review required."
            }
        }
        catch {

            Write-Host "RESTORE FAILED:"
            Write-Host $_.Exception.Message

            Update-Stage 9 100 "Promotion and automatic restoration failed."
        }

        return $false
    }
}

# ============================================================
# DARK MODE
# ============================================================

function Set-DarkMode {
    param([bool]$Enabled)

    $script:MainDarkModeState = $Enabled

    if ($Enabled) {
        Apply-DarkThemeToControl $Form $true
        $OutputBox.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
        $OutputBox.ForeColor = [System.Drawing.Color]::WhiteSmoke
        Set-DarkTitleBar $Form $true
    }
    else {
        Apply-DarkThemeToControl $Form $false
        # The live output pane intentionally remains dark in both modes.
        $OutputBox.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
        $OutputBox.ForeColor = [System.Drawing.Color]::WhiteSmoke
        Set-DarkTitleBar $Form $false
    }

    [System.Windows.Forms.Application]::DoEvents()
}

$DarkModeCheck.Add_CheckedChanged({ Set-DarkMode $this.Checked })
Set-DarkMode $true

# ============================================================
# WINDOW LAYOUT / MAXIMIZE BEHAVIOR
# ============================================================

$script:LayoutUpdating = $false

function Update-MainLayout {

    if ($script:LayoutUpdating) {
        return
    }

    $script:LayoutUpdating = $true

    try {
        $leftWidth = $MainSplit.Panel1.ClientSize.Width
        $leftHeight = $MainSplit.Panel1.ClientSize.Height
        $rightWidth = $MainSplit.Panel2.ClientSize.Width
        $rightHeight = $MainSplit.Panel2.ClientSize.Height

        # Keep the cleanup UI responsive inside the left pane.  The stage
        # controls are resized as a group so labels, progress bars and SKIP
        # buttons never sit outside the visible pane.
        $StagePanel.Width = [int][math]::Max(430, $leftWidth - 30)
        $StagePanel.Height = [int][math]::Max(250, $leftHeight - 236)

        $stageWidth = [int][math]::Max(410, $StagePanel.ClientSize.Width - 12)
        foreach ($stageNumber in $script:Stages.Keys) {
            $stage = $script:Stages[$stageNumber]
            $stage.Panel.Width = $stageWidth
            $stage.Panel.Height = 100

            $skipWidth = 115
            $percentWidth = 60
            $rightMargin = 10

            $stage.Percent.Width = $percentWidth
            $stage.Percent.Height = 30
            $stage.Percent.AutoSize = $false
            $stage.Percent.Left = [int][math]::Max(250, $stageWidth - $percentWidth - $rightMargin)
            $stage.Run.Left = 8
            $stage.Run.Top = 6
            $stage.Run.Width = 22
            $stage.Run.Height = 28
            $stage.Label.Left = 38
            $stage.Label.Width = [int][math]::Max(180, $stage.Percent.Left - 80)
            $stage.Label.Height = 30
            $stage.Label.AutoEllipsis = $false

            $stage.Skip.Width = $skipWidth
            $stage.Skip.Height = 32
            $stage.Skip.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $stage.Skip.Left = [int][math]::Max(250, $stageWidth - $skipWidth - $rightMargin)

            $stage.Bar.Left = 10
            $stage.Bar.Width = [int][math]::Max(220, $stage.Skip.Left - 20)
            $stage.Bar.Top = 40
            $stage.Bar.Height = 20

            $stage.Info.Left = 10
            $stage.Info.Top = 73
            $stage.Info.Width = [int][math]::Max(250, $stageWidth - 20)
            $stage.Info.AutoEllipsis = $true
            $stage.Info.Height = 22
            $stage.Info.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        }

        $OutputLabel.Location = [System.Drawing.Point]::new(
            20,
            [int][math]::Max(0, $leftHeight - 176)
        )
        $OutputLabel.Size = [System.Drawing.Size]::new(180,26)

        $StatusLabel.Location = [System.Drawing.Point]::new(
            20,
            [int][math]::Max(0, $leftHeight - 146)
        )
        $StatusLabel.Width = [int][math]::Max(300, $leftWidth - 40)
        $StatusLabel.Height = [int][math]::Max(45, 50)

        # Bottom controls: fixed order with real gaps.  Keep Dark mode on the
        # row above so it cannot overlap START OVER.
        $buttonY = [int][math]::Max(0, $leftHeight - 45)
        $PauseButton.Location = [System.Drawing.Point]::new(
            [int][math]::Max(20, $leftWidth - 490), $buttonY
        )
        $StartButton.Location = [System.Drawing.Point]::new(
            [int][math]::Max(20, $leftWidth - 370), $buttonY
        )
        $StopButton.Location = [System.Drawing.Point]::new(
            [int][math]::Max(20, $leftWidth - 250), $buttonY
        )
        $StartOverButton.Location = [System.Drawing.Point]::new(
            [int][math]::Max(20, $leftWidth - 130), $buttonY
        )
        $OpenSourceLabel.Location = [System.Drawing.Point]::new(20,$buttonY)
        $DarkModeCheck.Location = [System.Drawing.Point]::new(
            [int][math]::Max(20, $leftWidth - 130),
            [int][math]::Max(0, $leftHeight - 80)
        )

        # Keep the output pane readable at any window size.
        $OutputBox.Location = [System.Drawing.Point]::new(10,44)
        $OutputBox.Size = [System.Drawing.Size]::new(
            [int][math]::Max(200, $rightWidth - 20),
            [int][math]::Max(100, $rightHeight - 74)
        )
        $OutputHint.Location = [System.Drawing.Point]::new(12,[int][math]::Max(0,$rightHeight - 28))
        $OutputHint.Size = [System.Drawing.Size]::new([int][math]::Max(200,$rightWidth - 24),25)

        $StagePanel.PerformLayout()
        $MainSplit.PerformLayout()
        [System.Windows.Forms.Application]::DoEvents()
    }
    finally {
        $script:LayoutUpdating = $false
    }
}

# Use the entire working area for the single utility window.
# There is intentionally no separate output-window resize/position logic.
$Form.Add_Resize({
    # Do not touch the layout while Windows is minimizing the window.
    # Changing child control sizes during this transition can interfere with
    # the shell's normal taskbar restore state.
    if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        return
    }
    if ($script:LayoutUpdating) {
        return
    }
    Update-MainLayout
    $Form.Refresh()
})

# Keep normal WinForms minimize/restore behavior untouched.
# Windows owns the taskbar restore operation; do not override WindowState
# from Activated/ResizeEnd handlers because doing so can fight the shell
# and prevent a normal taskbar click from restoring the window.

$Form.Add_Shown({
    Update-MainLayout
})


# ============================================================
# OUTPUT LOG INITIALIZATION
# ============================================================

Set-Content -LiteralPath $OutputLog -Value "RCCU — RetroBat Collection Cleanup Utility - Full Output - $(Get-Date)"
Add-Content -LiteralPath $OutputLog -Value "System root: $Root"
Add-Content -LiteralPath $OutputLog -Value "Root directory selected by user: $Root"
Add-Content -LiteralPath $OutputLog -Value ""

# ============================================================
# MAIN
# ============================================================

$script:MaintenanceFinished = $false
$script:ForceClose = $false
$script:StartRequested = $false
$script:StopRequested = $false
$script:MaintenanceRunning = $false
$script:Paused = $false
$script:StartOverRequested = $false

$Form.Add_FormClosing({
    param($sender,$e)
    # Before START is pressed, or after cleanup has finished, the X closes the utility normally.
    # Only protect the window while an active maintenance operation is running.
    if ($script:MaintenanceRunning -and -not $script:ForceClose) {
        $e.Cancel = $true
        $script:StopRequested = $true
        foreach ($n in 1..9) { $script:StageSkipRequested[$n] = $true }
        $StatusLabel.Text = "Stopping..."
    }
})

$Form.Add_FormClosed({
    if ($script:RazorIcon) { try { $script:RazorIcon.Dispose() } catch { } }
    if ($razorBitmap) { try { $razorBitmap.Dispose() } catch { } }
})

try {

    Write-Host ""
    $separator = "=" * 60
    Write-Host $separator
    Write-Host "RETROBAT COLLECTION CLEANUP UTILITY"
    Write-Host $separator
    Write-Host "System root:"
    Write-Host $Root
    Write-Host ""

    # Give Windows a real restored size before maximizing.  v35 set the
    # normal Size to the entire working area and then maximized it, which can
    # make the taskbar restore state look like another maximized window.
    # Windows now owns the maximize/minimize/restore transition normally.
    $Form.StartPosition = "CenterScreen"
    $Form.Size = [System.Drawing.Size]::new(1400,900)
    $Form.ShowInTaskbar = $true

    $Form.Show()
    $Form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    $Form.PerformLayout()
    $MainSplit.PerformLayout()
    $splitWidth = [int]$MainSplit.ClientSize.Width
    if ($splitWidth -gt 0) {
        $safeDistance = [int][math]::Round($splitWidth * 0.57)
        $safeDistance = [int][math]::Max(300, [math]::Min($splitWidth - 300, $safeDistance))
        if ($safeDistance -gt 0 -and $safeDistance -lt $splitWidth) {
            $MainSplit.SplitterDistance = $safeDistance
        }
    }
    Update-MainLayout
    $Form.PerformLayout()
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    [System.Threading.Thread]::Sleep(150)
    [System.Windows.Forms.Application]::DoEvents()
    $Form.Activate()
    $Form.BringToFront()
    [RetroBatWindowApi]::SetForegroundWindow($Form.Handle) | Out-Null
    [System.Windows.Forms.Application]::DoEvents()

    $StartButton.Add_Click({
        if ($script:MaintenanceRunning) { return }
        $script:StartRequested = $true
        $script:MaintenanceRunning = $true
        $script:StopRequested = $false
        $script:Paused = $false
        $StartButton.Enabled = $false
        $StartOverButton.Enabled = $false
        $StopButton.Enabled = $true
        $PauseButton.Enabled = $true
        $PauseButton.Text = "PAUSE"
        foreach ($n in 1..9) { $script:Stages[$n].Run.Enabled = $false }
        $StatusLabel.Text = "Starting..."
        [System.Windows.Forms.Application]::DoEvents()

        foreach ($n in 1..9) {
            $script:StageSkipRequested[$n] = -not (Test-StageSelected $n)
        }

        try {
            $rootsToProcess = New-Object System.Collections.Generic.List[string]
            if ($script:AutomaticRecursiveRoot) {
                # Process the selected root itself when it has a gamelist, then every
                # descendant directory that has its own gamelist.xml. This prevents
                # media/art subdirectories from becoming accidental roots.
                if (Test-Path -LiteralPath (Join-Path $Root "gamelist.xml") -PathType Leaf) {
                    [void]$rootsToProcess.Add([System.IO.Path]::GetFullPath($Root))
                }
                foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { -not (Test-IsRccuRecoveryPath $_.FullName) } |
                    Sort-Object FullName)) {
                    if (Test-Path -LiteralPath (Join-Path $dir.FullName "gamelist.xml") -PathType Leaf) {
                        [void]$rootsToProcess.Add([System.IO.Path]::GetFullPath($dir.FullName))
                    }
                }
                if ($rootsToProcess.Count -eq 0) {
                    throw "[DANGER] AUTOMATIC RECURSIVE ROOT found no directories containing gamelist.xml under: $Root"
                }
                Write-Host "[DANGER] AUTOMATIC RECURSIVE ROOT: $($rootsToProcess.Count) library director$(if($rootsToProcess.Count -eq 1){'y'}else{'ies'}) queued."
            }
            else {
                [void]$rootsToProcess.Add([System.IO.Path]::GetFullPath($Root))
            }

            foreach ($processingRoot in @($rootsToProcess)) {
                if ($script:StopRequested) { break }
                $Root = [System.IO.Path]::GetFullPath($processingRoot)
                $RealXml = Join-Path $Root "gamelist.xml"
                $TestXml = Join-Path $Root "gamelist_TEST.xml"
                $DuplicateLog = Join-Path $Root "000-Duplicates.txt"
                $UniformLog = Join-Path $Root "000-UniformImages.txt"
                $MediaLog = Join-Path $Root "000-MediaAudit.txt"
                $VerificationLog = Join-Path $Root "000-VerificationAudit.txt"
                $OutputLog = Join-Path $Root "000-Output.txt"
                $XmlChangesLog = Join-Path $Root "000-XMLChanges.txt"
                $NormalizedGameListLog = Join-Path $Root "000-GameList.txt"
                $VideoNormalizationLog = Join-Path $Root "000-VideoNormalization.txt"
                Initialize-RecycleStrategy -RootPath $Root
                $PathLabel.Text = "System: $Root"
                Write-Host ""
                Write-Host "============================================================"
                Write-Host "PROCESSING ROOT: $Root"
                Write-Host "============================================================"
                Set-Content -LiteralPath $OutputLog -Value "RCCU — RetroBat Collection Cleanup Utility - Full Output - $(Get-Date)"
                Add-Content -LiteralPath $OutputLog -Value "System root: $Root"
                Add-Content -LiteralPath $OutputLog -Value "Automatic recursive root: $($script:AutomaticRecursiveRoot)"
                Add-Content -LiteralPath $OutputLog -Value "Automatic yes-to-all: $($script:AutomaticYesAll)"
                Add-Content -LiteralPath $OutputLog -Value ""
                foreach ($n in 1..9) { $script:StageSkipRequested[$n] = -not (Test-StageSelected $n) }

            if (Test-StageSelected 1) {
                if (-not (Invoke-FileFolderPermissions)) { throw "Cleanup stopped after Stage 1." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else {
                Set-StageSkipped 1 "Stage 1 not selected. Checking that current user already has required Modify access before Stage 2."
                if (-not (Test-RccuPermissionsPrerequisite)) {
                    throw "Stage 2 cannot commence because the current Windows user does not have the required ownership and Modify access throughout the working directory. Select Stage 1 - File & Folder Permissions and run it first."
                }
                Write-Host "Stage 1 not selected; permission prerequisite check passed for the current user."
            }

            if (Test-StageSelected 2) {
                if (-not (Invoke-DuplicateReview)) { throw "Cleanup stopped after Stage 2." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 2 "Stage 2 not selected." }

            if (Test-StageSelected 3) {
                if (-not (Invoke-UniformImageReview)) { throw "Cleanup stopped after Stage 3." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 3 "Stage 3 not selected." }

            if (-not (Test-Path -LiteralPath $RealXml -PathType Leaf)) { throw "No gamelist.xml exists. Nothing can be safely processed." }
            Copy-Item -LiteralPath $RealXml -Destination $TestXml -Force
            Write-Host "Copied real gamelist.xml to gamelist_TEST.xml."
            Write-Host "XML path base: $Root"
            $realBaselineXml = Load-XmlSafe $RealXml
            $testBaselineXml = Load-XmlSafe $TestXml
            if ($null -eq $realBaselineXml -or $null -eq $testBaselineXml) { throw "Could not load the real gamelist.xml and/or the freshly copied gamelist_TEST.xml." }
            $realBaselineGames = @(Get-XmlGameNodes $realBaselineXml)
            $testBaselineGames = @(Get-XmlGameNodes $testBaselineXml)
            if ($realBaselineGames.Count -eq 0) { throw "The real gamelist.xml contains 0 game entries. Refusing to process an empty library." }
            if ($testBaselineGames.Count -ne $realBaselineGames.Count) { throw "TEST XML baseline validation failed: real gamelist.xml has $($realBaselineGames.Count) game entries but the freshly copied gamelist_TEST.xml has $($testBaselineGames.Count). No processing will continue." }
            Write-Host "TEST XML baseline verified: $($testBaselineGames.Count) game entries copied from the real gamelist.xml."

            if (Test-StageSelected 4) {
                if (-not (Invoke-BlackBarCropReview)) { throw "Cleanup stopped after Stage 4." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 4 "Stage 4 not selected." }

            if (Test-StageSelected 5) {
                if (-not (Invoke-FinalVideoNormalization)) { throw "Cleanup stopped after Stage 5." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 5 "Stage 5 not selected." }

            if (Test-StageSelected 6) {
                if (-not (Invoke-StaleXmlAudit)) { throw "Cleanup stopped after Stage 6." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 6 "Stage 6 not selected." }

            $RepairXml = Load-XmlSafe $TestXml
            if ($null -eq $RepairXml) { throw "Could not load gamelist_TEST.xml." }

            if (Test-StageSelected 7) {
                $mediaAudit = Invoke-MediaAudit $RepairXml
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else {
                Set-StageSkipped 7 "Stage 7 not selected."
                $mediaAudit = @{ Recognized=@(); Unmatched=@(); Ambiguous=@(); Deleted=@() }
            }

            if (Test-StageSelected 8) {
                $RepairXml = Invoke-XmlRepair $RepairXml $mediaAudit
                if ($null -eq $RepairXml) { throw "Cleanup stopped because XML repair failed." }
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else { Set-StageSkipped 8 "Stage 8 not selected." }

            if ((Test-StageSelected 8) -and (Test-StageSelected 7) -and -not $script:StageSkipRequested[7] -and -not $script:StageSkipRequested[8] -and -not $script:StopRequested) {
                $postXmlCleanup = Invoke-PostXmlMediaCleanup $mediaAudit $RepairXml
                $mediaAudit.Deleted = @($postXmlCleanup.Deleted)
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            }

            if (Test-StageSelected 9) {
                $verificationClean = Invoke-FinalVerification
                if ($script:StopRequested) { throw "Cleanup stopped by user." }

                # Stage 9 now owns both final verification and final promotion.
                # Promotion is attempted only when verification is clean.
                [void](Invoke-FinalPromotion $verificationClean)
                if ($script:StopRequested) { throw "Cleanup stopped by user." }
            } else {
                Set-StageSkipped 9 "Stage 9 not selected. Final verification and promotion were skipped."
                $verificationClean = $false
            }

            # Always create the normalized game-title list after Stage 9 has completed or been skipped.
            try {
                Save-NormalizedGameList $NormalizedGameListLog
            }
            catch {
                Write-Host "WARNING: Could not save normalized game list: $($_.Exception.Message)"
            }

            Write-Host ""
            Write-Host "============================================================"
            Write-Host "RCCU — RETROBAT COLLECTION CLEANUP UTILITY FINISHED"
            Write-Host "============================================================"
            if ($verificationClean) { Write-Host "Final verification: CLEAN" } else { Write-Host "Final verification: NOT RUN or FAILED" }
            Write-Host ""
            Write-Host "TEST XML:"
            Write-Host $TestXml
            Write-Host ""
                $StatusLabel.Text = "Finished: $Root"
            } # foreach processingRoot
        }
        catch {
            Write-Host ""
            Write-Host "============================================================"
            Write-Host "RCCU — RETROBAT COLLECTION CLEANUP UTILITY STOPPED / ERROR"
            Write-Host "============================================================"
            Write-Host $_.Exception.Message
            if ($script:StopRequested) { $StatusLabel.Text = "Stopped." } else { $StatusLabel.Text = "ERROR: $($_.Exception.Message)" }
        }
        finally {
            $script:MaintenanceRunning = $false
            $script:Paused = $false
            $script:MaintenanceFinished = $true
            $StopButton.Enabled = $false
            $PauseButton.Enabled = $false
            $StartOverButton.Enabled = $true
            $PauseButton.Text = "PAUSE"
            [System.Windows.Forms.Application]::DoEvents()
        }
    })

    $PauseButton.Add_Click({
        if (-not $script:MaintenanceRunning) { return }

        if (-not $script:Paused) {
            $script:Paused = $true
            $PauseButton.Text = "RESUME"
            $StatusLabel.Text = "Paused."
            Write-Host "PAUSE requested by user."
        }
        else {
            $script:Paused = $false
            $PauseButton.Text = "PAUSE"
            $StatusLabel.Text = "Resuming..."
            Write-Host "RESUME requested by user."
        }

        [System.Windows.Forms.Application]::DoEvents()
    })

    $StartOverButton.Add_Click({
        if ($script:MaintenanceRunning) { return }

        $script:StartOverRequested = $true
        $script:ForceClose = $true
        $script:MaintenanceFinished = $true
        $StartOverButton.Enabled = $false
        $StatusLabel.Text = "Closing and restarting RCCU..."
        [System.Windows.Forms.Application]::DoEvents()

        # Launch a fresh RCCU instance so the directory-selection dialog is
        # shown again with a completely clean run state.
        if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) {
            $psExe = Join-Path $PSHOME "powershell.exe"
            Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath) | Out-Null
        }

        $Form.Close()
    })

    $StopButton.Add_Click({
        if (-not $script:MaintenanceRunning) { return }
        $script:StopRequested = $true
        foreach ($n in 1..9) { $script:StageSkipRequested[$n] = $true }
        $StatusLabel.Text = "Stopping..."
        [System.Windows.Forms.Application]::DoEvents()
    })

    while ($Form.Visible -and -not $script:StartRequested) {
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(50)
    }

    while ($Form.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(50)
    }
}
catch {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "FATAL ERROR"
    Write-Host "============================================================"
    Write-Host $_.Exception.Message
    Write-Host $_.ScriptStackTrace
    if ($StatusLabel) { $StatusLabel.Text = "ERROR: $($_.Exception.Message)" }
    $script:MaintenanceFinished = $true
    [System.Windows.Forms.MessageBox]::Show($Form,"The RCCU — RetroBat Collection Cleanup Utility encountered an error:`r`n`r`n$($_.Exception.Message)","RCCU - RetroBat Collection Cleanup Utility",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    while ($Form.Visible) { [System.Windows.Forms.Application]::DoEvents(); [System.Threading.Thread]::Sleep(50) }
}
