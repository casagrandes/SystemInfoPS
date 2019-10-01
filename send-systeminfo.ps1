$deviceUUID = [guid]::NewGuid()

$deviceGuidRegistryPathTest = Test-Path HKLM:\SOFTWARE\InfoPull

if(!$deviceGuidRegistryPathTest) {
  New-Item -Path HKLM:\SOFTWARE\InfoPull
  New-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid -Value $deviceUUID
  $registryKey = Get-ItemProperty HKLM:\SOFTWARE\InfoPull
  if($registryKey) {
    Write-Host "Key created successfully" -ForegroundColor Green 
  }
}

if(Get-ItemProperty -Path HKLM:\SOFTWARE\InfoPull -Name DeviceGuid) {
  Write-Host "Device GUID already exists" -ForegroundColor Green
} else {
  Write-Host "creating Device GUID"
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
$testGuid = "1ffc7983-bd66-45d2-a291-26b863ab91ff"
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

$deviceGuidFromRegistry

$uri = 'http://127.0.0.1:4000/api/ps/update'
$headers = @{
  'api_key' = 'x9laz16obki5xt9f6t9t07'
}
Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $sysInfoHashTable -ContentType "application/x-www-form-urlencoded"
