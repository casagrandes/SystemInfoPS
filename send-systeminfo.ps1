$initialSetupRegistryTest = Test-Path HKLM:\SOFTWARE\InfoPull
$dateTimeNow = Get-Date -Format 'MM\/dd\/yyyy HH:mm:ss'

if(!$initialSetupRegistryTest) {
  Write-Host "Running Initial Setup" -ForegroundColor Green
  $deviceUUID = [guid]::NewGuid()
  New-Item -Path HKLM:\SOFTWARE\InfoPull
  New-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid -Value $deviceUUID
  $registryKey = Get-ItemProperty HKLM:\SOFTWARE\InfoPull -Name DeviceGuid
  if($registryKey) {
    Write-Host "Key created successfully" -ForegroundColor Green 
  }
  New-ItemProperty -Name setupDate -Value $dateTimeNow
}

if(Get-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid) {
  Write-Host "Device GUID already exists and does not need to be created" -ForegroundColor Yellow
} else {
  Write-Host "creating Device GUID" -ForegroundColor Yellow
  New-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid -Value ([guid]::NewGuid())
}

$initialSetupComplete = Get-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name setupComplete

if($initialSetupComplete) {
  Write-Host "Device has already been registered and setup" -ForegroundColor Yellow
  $firstTimeRun = $false
} else {
  Write-Host "Creating new entry in database" -ForegroundColor Yellow
  New-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name setupComplete -Value 0
  $firstTimeRun = $true
}

$deviceGuidFromRegistry = (Get-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid).DeviceGuid
$adminPasswordStatus = $null
$thermalState        = $null
$osInfo              = Get-CimInstance Win32_OperatingSystem
$computerInfo        = Get-CimInstance Win32_ComputerSystem
$diskInfo            = Get-CimInstance Win32_LogicalDisk | Where-Object {($_.DeviceID -contains 'C:')}
$biosInfo            = Get-CimInstance Win32_Bios
$cpuInfo             = Get-CimInstance Win32_Processor
$gpuInfo             = Get-CimInstance Win32_VideoController

Switch ($computerInfo.AdminPasswordStatus) {
  0 {$adminPasswordStatus = 'Disabled'}
  1 {$adminPasswordStatus = 'Enabled'}
  2 {$adminPasswordStatus = 'Not Implemented'} 
  3 {$adminPasswordStatus = 'Unknown'}
  Default {$adminPasswordStatus = 'Unable to determine'}
}

Switch ($computerInfo.ThermalState) {
  1 {$thermalState = 'Other'}
  2 {$thermalState = 'Unknown'}
  3 {$thermalState = 'Safe'}
  4 {$thermalState = 'Warning'} 
  5 {$thermalState = 'Critical'}
  6 {$thermalState = 'Non-recoverable'}
  Default {$thermalState = 'Unable to determine'}
}

switch ($computerInfo.DomainRole) {
  0 {$domainRole = 'Standalone Workstation'}
  1 {$domainRole = 'Domain Workstation'}
  2 {$domainRole = 'Standalone Server'}
  3 {$domainRole = 'Domain Server'}
  4 {$domainRole = 'Backup Domain Controller'}
  5 {$domainRole = 'Primary Domain Controller'}

  Default {$domainRole = 'Workstation'}
}

$totalMemoryGB = [math]::Round($computerInfo.TotalPhysicalMemory / 1073741824)
$diskFreeSpaceInGB = [math]::Round($diskInfo.FreeSpace / 1073741824)

$sysInfoHashTable = @{
  name = $computerInfo.Name
  user = $osInfo.RegisteredUser
  os = $osInfo.Caption
  osVersion = $osInfo.Version
  domain = $computerInfo.Domain
  domainRole = $domainRole
  diskFreeSpaceGB = $diskFreeSpaceInGB
  adminPassStatus = $adminPasswordStatus
  thermalState = $thermalState
  biosName = $biosInfo.Name
  biosStatus = $biosInfo.Status
  biosManufacturer = $biosInfo.Manufacturer
  cpuName = $cpuInfo.Name
  cpuSocket = $cpuInfo.SocketDesignation
  cpuMaxClock = $cpuInfo.MaxClockSpeed
  cpuCores = $cpuInfo.NumberOfCores
  cpuVirtCores = $cpuInfo.NumberOfLogicalProcessors
  gpuName = $gpuInfo.Name
  ramGB = $totalMemoryGB
  deviceGuid = $deviceGuidFromRegistry
}

$headers = @{
  'api_key' = 'x9laz16obki5xt9f6t9t07'
}

if($firstTimeRun) {
  $uri = 'http://127.0.0.1:4000/api/ps/add'
  $sysInfoHashTable.name
  Write-Host "Invoking POST Request" -ForegroundColor Yellow
  try {
    $updateData = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $sysInfoHashTable
    if($updateData.saved) {
      Write-Host "Data saved to database" -ForegroundColor Green
      New-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name dataUpdated -Value $dateTimeNow
    }
  }
  catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    write-host $ErrorMessage -ForegroundColor Red
  }

  Set-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name setupComplete -Value 1
  Write-Host "Writing registry value for setupComplete" -ForegroundColor Green

} else {
  $uri = 'http://127.0.0.1:4000/api/ps/update'
  Write-Host "Invoking PUT Request" -ForegroundColor Yellow
  try {
    $updateData = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $sysInfoHashTable -ContentType "application/x-www-form-urlencoded"

    if($updateData.updateComplete) {
      Write-Host "Data updated successfully" -ForegroundColor Green
      Set-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name dataUpdated-Value $dateTimeNow
  }
  }
  catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    write-host $ErrorMessage -ForegroundColor Red
  }
  
}