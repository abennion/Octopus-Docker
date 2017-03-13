[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$Msi
  )
  
 
$version = $env:OctopusVersion
$msiFileName = "$($Msi).$($version)-x64.msi"
$downloadUrl = "https://download.octopusdeploy.com/octopus/" + $msiFileName
#$downloadUrlLatest = "https://octopusdeploy.com/downloads/latest/OctopusTentacle"
#http://octopusdeploy.com/downloads/latest/OctopusTentacle

$installBasePath = "C:\Install\"
$installersPath = "C:\Installers\"
$msiPath = $installBasePath + $msiFileName
$msiLogPath = $installBasePath + $msiFileName + '.log'
$installerLogPath = $installBasePath + 'Install-OctopusDeploy.ps1.log'
$OFS = "`r`n"

. ./octopus-common.ps1

function Create-InstallLocation
{
  Write-Log "Create Install Location"

  if (!(Test-Path $installBasePath))
  {
    Write-Log "Creating installation folder at '$installBasePath' ..."
    New-Item -ItemType Directory -Path $installBasePath | Out-Null
    Write-Log "done."
  }
  else
  {
    Write-Log "Installation folder at '$installBasePath' already exists."
  }

  Write-Log ""
}

function Stage-Installer {
gci $installersPath
	Write-Log "Stage Installer"
	$embeddedPath=[System.IO.Path]::Combine($installersPath,$msiFileName);  
	if (Test-Path $embeddedPath) {
		Write-Log "Found correct version installer at '$embeddedPath'. Copying to '$msiPath' ..."
		Copy-Item $embeddedPath $msiPath
		Write-Log "done."
	}
	else {  
		if($version -eq $null){
			$downloadUrl = $downloadUrlLatest
			Write-Log "No version specified for install. Using latest";
		}
		Write-Log "Downloading installer '$downloadUrl' to '$msiPath' ..."
		(New-Object Net.WebClient).DownloadFile($downloadUrl, $msiPath)
		Write-Log "done."
	}
}


function Install-OctopusDeploy
{
  Write-Log "Installing $msiFileName" 
  Write-Verbose "Starting MSI Installer"
  $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msiPath /qn /l*v $msiLogPath" -Wait -Passthru).ExitCode
  Write-Verbose "MSI installer returned exit code $msiExitCode"
  if ($msiExitCode -ne 0) {
    Write-Verbose "-------------"
    Write-Verbose "MSI Log file:"
    Write-Verbose "-------------"
    Get-Content $msiLogPath
    Write-Verbose "-------------"
    throw "Install of $Msi failed, MSIEXEC exited with code: $msiExitCode. View the log at $msiLogPath"
  }
}



function Delete-InstallLocation
{
	Write-Log "Delete $installersPath Directory"
  if (!(Test-Path $installersPath))
  {
    Write-Log "Installers directory didn't exist - skipping delete"
  }
  else
  {
    Remove-Item $installersPath -Recurse -Force
  }
  Write-Log ""
  
  
  Write-Log "Delete Install Location"
  if (!(Test-Path $installBasePath))
  {
    Write-Log "Install location didn't exist - skipping delete"
  }
  else
  {
    Remove-Item $installBasePath -Recurse -Force
  }
  Write-Log ""
}


try
{
  Write-Log "==============================================="
  Write-Log "Installing $Msi version '$version'"
  Write-Log "==============================================="

  Create-InstallLocation
  Stage-Installer
  Install-OctopusDeploy
  Delete-InstallLocation      # removes files we dont need to save space in the image

  "Msi Install complete." | Set-Content "c:\octopus-install.initstate"

  Write-Log "Msi Installed"
  exit 0
}
catch
{
  Write-Log $_
  exit 2
}
