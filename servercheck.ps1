Function Get-PendingServerUpdates { Param ($Server)
 gwmi -ComputerName $Server -query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\clientSDK'
 }

Out-File .\unreachable.txt
Out-File .\pendingupdates.txt

#region choose server text files
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
[System.Windows.MessageBox]::Show("Please select text file where servers are saved", "Select File", 1, 0)
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') }
$null = $FileBrowser.ShowDialog()
$actualfile = $FileBrowser.FileName
#endregion 

[System.Windows.MessageBox]::Show("Please select the Reboot Time from the Maintenance Schedule", "Select Reboot Time", 1, 0)


 #region GUI Date Picker
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form -Property @{
    StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    Size          = New-Object Drawing.Size 243, 230
    Text          = 'Select a Date'
    Topmost       = $true
}

$calendar = New-Object Windows.Forms.MonthCalendar -Property @{
    ShowTodayCircle   = $false
    MaxSelectionCount = 1
}
$form.Controls.Add($calendar)

$okButton = New-Object Windows.Forms.Button -Property @{
    Location     = New-Object Drawing.Point 38, 165
    Size         = New-Object Drawing.Size 75, 23
    Text         = 'OK'
    DialogResult = [Windows.Forms.DialogResult]::OK
}
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object Windows.Forms.Button -Property @{
    Location     = New-Object Drawing.Point 113, 165
    Size         = New-Object Drawing.Size 75, 23
    Text         = 'Cancel'
    DialogResult = [Windows.Forms.DialogResult]::Cancel
}
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$result = $form.ShowDialog()

if ($result -eq [Windows.Forms.DialogResult]::OK) {
    $PatchDate = $calendar.SelectionStart
    Write-Host "Date selected: $($PatchDate.ToShortDateString())"
}

$PatchDateminus1 = $PatchDate.AddDays(-1).ToShortDateString() | Get-Date -Format 'yyyyMMdd'
#endregion 

$unreachableservers = @()


$serverlist = Get-Content -Path $actualfile
$unreachableservers = $serverlist | where {$_ -match “[G][C][0-9][0-9]$”}
$serverlist = $serverlist | where {$_ -notmatch “[G][C][0-9][0-9]$”}

$unreachableservers | Add-Content .\unreachable.txt


Write-Host "Checking $($serverlist.Count + $unreachableservers.Count) servers"

$pendingservers = @()
$goodservers = @()
$errorservers = @()

foreach ($item in $serverlist)
{
Write-Host "Checking patches for $($item)..."
   "-----------------------------------------------------------------------------------------------------------------------"

try{gwmi -ComputerName $item -query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\clientSDK' -ErrorAction Stop | select -Property ArticleID, PSComputerName  -Last 1 -ErrorAction Stop} 
catch
{Write-Host -BackgroundColor Black -ForegroundColor Yellow "Unable to grab pending updates for server - adding to unreachable"
$errorservers += $item
$unreachableservers += $item
$item | Add-Content .\unreachable.txt}

    If (Get-PendingServerUpdates $item -ne $null -And $item -notin $unreachableservers){
        $pendingservers += $item
        Write-Host -BackgroundColor Black -ForegroundColor Yellow "$($item) has pending updates..."
        $item | Add-Content .\pendingupdates.txt
        " "
        }
    Elseif ($item -notin $unreachableservers) {
        $goodservers += $item
        Write-Host "$($item) has no pending  updates..."
        " "
        }
}

#region pick validated servers
$validatedservers = @()
$NotValidatedServers = @()
$NoBootValidation = @()
#output as you go to show what servers are good - might try to commentthis out to clear out redundancy


foreach ($goodserver in $goodservers){
$tastingdate = Get-CimInstance -ClassName win32_operatingsystem -ComputerName $goodserver | Select-Object -Property LastBootupTime 
$LastBootTimeDate = $tastingdate.LastBootupTime.ToShortDateString()| Get-Date -Format 'yyyyMMdd'
$PrettyBootTime = $tastingdate.LastBootupTime.ToShortDateString()
$LastUpdate = get-hotfix -computer $goodserver | sort installedon | select -last 1
$LastUpdateTime = $LastUpdate.InstalledOn.ToShortDateString() #| Get-Date -Format 'yyyyMMdd'

try {Get-CimInstance -ClassName win32_operatingsystem -ComputerName $goodserver -ErrorAction Stop} #| Select-Object -Property LastBootupTime -ErrorAction Stop}
catch{Write-Host -BackgroundColor Black -ForegroundColor Yellow "Cannot verify last boot time for $($goodserver) but no pending patches - adding to unverified"
$NoBootValidation += $goodserver}

   if ($LastBootTimeDate -ge $PatchDateminus1 -and $goodserver -notin $NoBootValidation) {
   "-----------------------------------------------------------------------------------------------------------------------"
   Write-Host "Checking $goodserver boot time and patches..."
   $validatedservers += $goodserver
   #"$($goodserver) has rebooted within patch window..."
   " "
   }
   else
   { 
    "-----------------------------------------------------------------------------------------------------------------------"
   Write-Host "UNABLE TO VALIDATE $goodserver..."
   "Please check $($goodserver) - last rebooted $($PrettyBootTime) and last update installed $($LastUpdateTime)"
   $NotValidatedServers += $goodserver
   " "
   }

}



$NotValidatedServers += $pendingservers


" "
Write-Host "$($serverlist.Count + $unreachableservers.Count - $errorservers.count) servers intially selected at the start"
Write-Host "$($unreachableservers.Count + $NotValidatedServers.Count + $validatedservers.Count) servers checked"
" "
Write-Host -ForegroundColor Yellow "Unable to validate the following $($NotValidatedServers.Count) servers:".ToUpper()
$($NotValidatedServers)
" "
"More info below for each server:"
"--------------------------------------------------"
" "
foreach ($nonvalidation in $NotValidatedServers){
   "Please confirm $($nonvalidation) last boot time"
   "Pending Server Updates (May bug out and be blank): " + (Get-PendingServerUpdates -Server $nonvalidation).Count
   "-----------------------------------------------------------------------------------------------------------------------"
   }

Write-Host -ForegroundColor Green "The following $($validatedservers.Count) servers have validated successfully:".ToUpper()
" "
foreach ($valid in $validatedservers){
"$($valid) Last rebooted: $($PrettyBootTime) - Last update installed: $($LastUpdateTime) and no pending updates"
   "-----------------------------------------------------------------------------------------------------------------------"
}
" "
Write-Host -BackgroundColor Black -ForegroundColor Yellow "The following $($unreachableservers.count) servers could not be reached:".ToUpper()
" "
$unreachableservers 
" "


