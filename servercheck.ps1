
#region choose server text files
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
[System.Windows.MessageBox]::Show("Please select text file where servers are saved", "Select File", 1, 0)
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') }
$null = $FileBrowser.ShowDialog()
$actualfile = $FileBrowser.FileName
#endregion 

Function Get-PendingServerUpdates { Param ($Server)
 gwmi -ComputerName $Server -query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\clientSDK'
 }
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


$serverlist = Get-Content -Path $actualfile
$servers = Get-Content -Path $actualfile | Measure-Object -Line | Select-Object Lines
$servercount = $servers.Lines

"Checking $servercount servers"

$pendingservers = @()
$goodservers = @()
$unreachableservers = @()

foreach ($item in $serverlist)
{
    try
{
Write-Output "Checking $item..."
get-hotfix -computer $item | sort installedon | select -last 1 -ErrorAction SilentlyContinue
Get-CimInstance -ClassName win32_operatingsystem -ComputerName $item | Select-Object -Property PSComputerName, LastBootupTime -ErrorAction Stop
" "
"-----------------------------------------------------------------------------"
}
    catch
{
    $x = $Error[0].Exception.Message.ToString()
    Write-Warning "$x to $item"
    Write-Warning "Please check domain/privleges for $($item)"
     $unreachableservers += $item
}

If (Get-PendingServerUpdates $item -ne $null -And $item -notin $unreachableservers){
    $pendingservers += $item
    #Write-Warning "$item has pending updates"
    #Write-Host " "
    #Write-Host " "
    #Write-Host "------------------------------------------------------------"

    }
    Elseif ($item -notin $unreachableservers) {
    $goodservers += $item
    #Write-Output "No pending updates for $item"
    #Write-Host " "
    #Write-Host " "
    #Write-Host "------------------------------------------------------------"
    }
 

}

#region pick validated servers
$validatedservers = @()
$NotValidatedServers = @()

foreach ($goodserver in $goodservers){
$tastingdate = Get-CimInstance -ClassName win32_operatingsystem -ComputerName $goodserver | Select-Object -Property LastBootupTime 
$LastBootTimeDate = $tastingdate.LastBootupTime.ToShortDateString()| Get-Date -Format 'yyyyMMdd'
$PrettyBootTime = $tastingdate.LastBootupTime.ToShortDateString()
$LastUpdate = get-hotfix -computer $goodserver | sort installedon | select -last 1
$LastUpdateTime = $LastUpdate.InstalledOn.ToShortDateString() #| Get-Date -Format 'yyyyMMdd'

   if ($LastBootTimeDate -ge $PatchDateminus1) {
   "$($goodserver) sucessfully rebooted within patch window on $($PrettyBootTime).  Last update installed $($LastUpdateTime)"
   $validatedservers += $goodserver
   }
   else
   { 
   Write-Warning "Please check $($goodserver) - last rebooted $($PrettyBootTime) and last update installed $($LastUpdateTime)"
   $NotValidatedServers += $goodserver
   
   }

}


#endregion

$NotValidatedServers += $pendingservers

" "
"$servercount servers selected"
"$($unreachableservers.Count + $NotValidatedServers.Count + $validatedservers.Count) servers checked"
" "
Write-Warning "Unable to validate the following $($NotValidatedServers.Count) servers:".ToUpper()
$($NotValidatedServers)
" "
"More info below for each server:"
"--------------------------------------------------"
" "
foreach ($nonvalidation in $NotValidatedServers){
   "Please check $($nonvalidation):"
   "Last rebooted $($PrettyBootTime) and last update installed $($LastUpdateTime)"
   "Pending Server Updates: " + (Get-PendingServerUpdates -Server $nonvalidation).Count
   "--------------------------------------------------"

}

" "
"Sucessfully validated the following $($validatedservers.Count) servers:".ToUpper()
$($validatedservers)
" "
"--------------------------------------------------"
" "
"The following $($unreachableservers.count) servers could not be reached:".ToUpper()
$unreachableservers
" "
"--------------------------------------------------"

