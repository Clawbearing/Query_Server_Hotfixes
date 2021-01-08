Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyNamePresentationFramework
[System.Windows.MessageBox]::Show('Please select text file where servers are saved')
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') }
$null = $FileBrowser.ShowDialog()
$actualfile = $FileBrowser.FileName


$serverlist = Get-Content -Path $actualfile
$servers = Get-Content -Path $actualfile | Measure-Object -Line | Select-Object Lines
$servercount = $servers.Lines

"Checking $servercount servers"

$pendingservers = @()
$goodservers = @()

foreach ($item in $serverlist){
Write-Output "Checking $item..."
get-hotfix -computer $item | sort installedon | select -last 2
Get-CimInstance -ClassName win32_operatingsystem -ComputerName $item | select csname, lastbootuptime
If (Get-PendingServerUpdates $item -ne $null){
    $pendingservers += $item
    Write-Warning "$item has pending updates"
    Write-Host " "
    Write-Host " "
    Write-Host "------------------------------------------------------------"

    }
    else {
    $goodservers += $item
    Write-Output "No pending updates for $item"
    Write-Host " "
    Write-Host " "
    Write-Host "------------------------------------------------------------"


    }

}
" "
"$servercount total servers checked"
"$($goodservers.Count) good servers"
"$($pendingservers.Count) servers pending updates"
" "
"No pending updates for the following servers: " 
$goodservers
" "
"----------"
" "
Write-Warning "Please check the following servers:" 
$pendingservers