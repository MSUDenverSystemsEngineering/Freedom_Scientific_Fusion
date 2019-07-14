<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
## Suppress PSScriptAnalyzer errors for not using declared variables during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppresses AppVeyor errors on informational variables below")]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Freedom Scientific'
	[string]$appName = 'Fusion'
	[string]$appVersion = '2019'
	[string]$appArch = 'x86'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '3.7.0.1'
	[string]$appScriptDate = '07/14/2019'
	[string]$appScriptAuthor = 'Metropolitan State University of Denver'
	## Add new filename here:
	[string]$fusionfile = 'ZF2019.1906.8.400-Offline.exe'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Fusion, ZoomText, JAWS if needed, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'aisquared.zoomtext.ui,jfw' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		## UNINSTALL FUSION 2018
		If (Test-Path "C:\Program Files (x86)\Freedom Scientific\ZoomText\2018\zt.exe") {
				$exitCode = Execute-Process -Path "$dirFiles\ZF2018.1807.4.400-enu" -Parameters "/Type SilentSharedUninstall" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
				If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
					$mainExitCode = $exitCode.ExitCode
				}
				## Wait for Fusion uinstallation to complete
				Wait-Process -Name "ZF2018.1807.4.400-enu"
				## Uninstall Freedom Scientific JAWS Training Table Of Contents DAISY Files
				$exitCode = Execute-MSI -Action 'Uninstall' -Path "{4B78A505-4DE7-4212-95C1-32138456D4D4}"
		    If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
					$mainExitCode = $exitCode.ExitCode
				}
				## Uninstall Freedom Scientific FSReader 3.0
				$exitCode = Execute-MSI -Action 'Uninstall' -Path "{771ACF6D-1A05-4195-9739-3EBBDE3A2AA3}"
				If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
					$mainExitCode = $exitCode.ExitCode
				}
			}
		## UININSTALL OLDER ZOOMTEXTS AND JAWS

		## Uninstall ZoomText 10.1 if exist
		If (Test-Path "C:\Program Files (x86)\InstallShield Installation Information\{F7F20305-1476-4421-B909-BB5B90D1F222}\setup.exe") {
			Execute-Process -Path "C:\Program Files (x86)\InstallShield Installation Information\{F7F20305-1476-4421-B909-BB5B90D1F222}\setup.exe" -Parameters "-runfromtemp -l0x0009 -ir -niuninst" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		}
		## Uninstall JAWS 18 if exist
		If (Test-Path "C:\Program Files\Freedom Scientific Installation Information\356DE2A8-01EB-464e-9C33-0EEA3F923000-18.0\UninstallJAWS.exe") {
			Execute-Process -Path "C:\Program Files\Freedom Scientific Installation Information\356DE2A8-01EB-464e-9C33-0EEA3F923000-18.0\UninstallJAWS.exe" -Parameters "/type silentremoveshared" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		}
		## Wait for JAWS 18 uninstallation to complete
		Wait-Process -Name "UninstallJAWS.exe"
		## Uninstall FSReader 3.0 if exist
		If (Test-Path "C:\Program Files\Freedom Scientific\FSReader\3.0\UninstallFSReader.exe") {
			Execute-Process -Path "C:\Program Files\Freedom Scientific\FSReader\3.0\UninstallFSReader.exe" -Parameters "/type silent" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		}
		## Wait for FSReader 3.0 uninstallation to complete
		Wait-Process -Name "UninstallFSReader.exe"


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		## Install Fusion 2019 silently

		$exitCode = Execute-Process -Path "$dirFiles\$fusionfile" -Parameters "/Type Silent" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}
		## Wait for Fusion 2018 installation to complete
		Wait-Process -Name "$fusionfile"

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		## Remvoe Desktop Shortcuts of Fusion 2019
		Remove-File -Path "$env:Public\Desktop\FSReader 3.0.lnk"
		Remove-File -Path "$env:Public\Desktop\Fusion 2019.lnk"
		Remove-File -Path "$env:Public\Desktop\JAWS 2019.lnk"
		Remove-File -Path "$env:Public\Desktop\ZoomText 2019.lnk"
		## Set LSHOST Environment Variable for Network Licensing
		[Environment]::SetEnvironmentVariable('LSHOST', 'VMWAS22', 'Machine')
		## Prompt SCCM to restart via passthru
		If ($exitCode.ExitCode -eq "0") {
			$mainExitCode = "3010"
		}

		## Display a message at the end of the install
		If (-not $useDefaultMsi) {

		}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Fusion 2018, ZoomText, and JAWS with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'aisquared.zoomtext.ui,jfw' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>

		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>

		## Uninstall Fusion 2018 and shared components
		$exitCode = Execute-Process -Path "$dirFiles\$fusionfile" -Parameters "/Type SilentSharedUninstall" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}
		## Wait for Fusion uinstallation to complete
		Wait-Process -Name "$fusionfile"
		## Uninstall Freedom Scientific JAWS Training Table Of Contents DAISY Files
		$exitCode = Execute-MSI -Action 'Uninstall' -Path "{C1D0C0DB-F2A6-46AC-95F0-80ED72F1C844}"
    If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}
		## Uninstall Freedom Scientific FSReader 3.0
		$exitCode = Execute-MSI -Action 'Uninstall' -Path "{771ACF6D-1A05-4195-9739-3EBBDE3A2AA3}"
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
		## Prompt SCCM to restart via passthru
		If ($exitCode.ExitCode -eq "0") {
			$mainExitCode = "3010"
		}

	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}

# SIG # Begin signature block
# MIIfagYJKoZIhvcNAQcCoIIfWzCCH1cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCt6km2n8/c1kSx
# Y52knyfwxWD/37WCyBcMgRV39OCDH6CCGdcwggQUMIIC/KADAgECAgsEAAAAAAEv
# TuFS1zANBgkqhkiG9w0BAQUFADBXMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xv
# YmFsU2lnbiBudi1zYTEQMA4GA1UECxMHUm9vdCBDQTEbMBkGA1UEAxMSR2xvYmFs
# U2lnbiBSb290IENBMB4XDTExMDQxMzEwMDAwMFoXDTI4MDEyODEyMDAwMFowUjEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMT
# H0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCU72X4tVefoFMNNAbrCR+3Rxhqy/Bb5P8npTTR94ka
# v56xzRJBbmbUgaCFi2RaRi+ZoI13seK8XN0i12pn0LvoynTei08NsFLlkFvrRw7x
# 55+cC5BlPheWMEVybTmhFzbKuaCMG08IGfaBMa1hFqRi5rRAnsP8+5X2+7UulYGY
# 4O/F69gCWXh396rjUmtQkSnF/PfNk2XSYGEi8gb7Mt0WUfoO/Yow8BcJp7vzBK6r
# kOds33qp9O/EYidfb5ltOHSqEYva38cUTOmFsuzCfUomj+dWuqbgz5JTgHT0A+xo
# smC8hCAAgxuh7rR0BcEpjmLQR7H68FPMGPkuO/lwfrQlAgMBAAGjgeUwgeIwDgYD
# VR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFEbYPv/c
# 477/g+b0hZuw3WrWFKnBMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAzBgNVHR8E
# LDAqMCigJqAkhiJodHRwOi8vY3JsLmdsb2JhbHNpZ24ubmV0L3Jvb3QuY3JsMB8G
# A1UdIwQYMBaAFGB7ZhpFDZfKiVAvfQTNNKj//P1LMA0GCSqGSIb3DQEBBQUAA4IB
# AQBOXlaQHka02Ukx87sXOSgbwhbd/UHcCQUEm2+yoprWmS5AmQBVteo/pSB204Y0
# 1BfMVTrHgu7vqLq82AafFVDfzRZ7UjoC1xka/a/weFzgS8UY3zokHtqsuKlYBAIH
# MNuwEl7+Mb7wBEj08HD4Ol5Wg889+w289MXtl5251NulJ4TjOJuLpzWGRCCkO22k
# aguhg/0o69rvKPbMiF37CjsAq+Ah6+IvNWwPjjRFl+ui95kzNX7Lmoq7RU3nP5/C
# 2Yr6ZbJux35l/+iS4SwxovewJzZIjyZvO+5Ndh95w+V/ljW8LQ7MAbCOf/9RgICn
# ktSzREZkjIdPFmMHMUtjsN/zMIIEnzCCA4egAwIBAgISESHWmadklz7x+EJ+6RnM
# U0EUMA0GCSqGSIb3DQEBBQUAMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBD
# QSAtIEcyMB4XDTE2MDUyNDAwMDAwMFoXDTI3MDYyNDAwMDAwMFowYDELMAkGA1UE
# BhMCU0cxHzAdBgNVBAoTFkdNTyBHbG9iYWxTaWduIFB0ZSBMdGQxMDAuBgNVBAMT
# J0dsb2JhbFNpZ24gVFNBIGZvciBNUyBBdXRoZW50aWNvZGUgLSBHMjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALAXrqLTtgQwVh5YD7HtVaTWVMvY9nM6
# 7F1eqyX9NqX6hMNhQMVGtVlSO0KiLl8TYhCpW+Zz1pIlsX0j4wazhzoOQ/DXAIlT
# ohExUihuXUByPPIJd6dJkpfUbJCgdqf9uNyznfIHYCxPWJgAa9MVVOD63f+ALF8Y
# ppj/1KvsoUVZsi5vYl3g2Rmsi1ecqCYr2RelENJHCBpwLDOLf2iAKrWhXWvdjQIC
# KQOqfDe7uylOPVOTs6b6j9JYkxVMuS2rgKOjJfuv9whksHpED1wQ119hN6pOa9PS
# UyWdgnP6LPlysKkZOSpQ+qnQPDrK6Fvv9V9R9PkK2Zc13mqF5iMEQq8CAwEAAaOC
# AV8wggFbMA4GA1UdDwEB/wQEAwIHgDBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0
# MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0
# b3J5LzAJBgNVHRMEAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEIGA1UdHwQ7
# MDkwN6A1oDOGMWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vZ3MvZ3N0aW1lc3Rh
# bXBpbmdnMi5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjhodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RpbWVzdGFtcGluZ2cyLmNy
# dDAdBgNVHQ4EFgQU1KKESjhaGH+6TzBQvZ3VeofWCfcwHwYDVR0jBBgwFoAURtg+
# /9zjvv+D5vSFm7DdatYUqcEwDQYJKoZIhvcNAQEFBQADggEBAI+pGpFtBKY3IA6D
# lt4j02tuH27dZD1oISK1+Ec2aY7hpUXHJKIitykJzFRarsa8zWOOsz1QSOW0zK7N
# ko2eKIsTShGqvaPv07I2/LShcr9tl2N5jES8cC9+87zdglOrGvbr+hyXvLY3nKQc
# MLyrvC1HNt+SIAPoccZY9nUFmjTwC1lagkQ0qoDkL4T2R12WybbKyp23prrkUNPU
# N7i6IA7Q05IqW8RZu6Ft2zzORJ3BOCqt4429zQl3GhC+ZwoCNmSIubMbJu7nnmDE
# Rqi8YTNsz065nLlq8J83/rU9T5rTTf/eII5Ol6b9nwm8TcoYdsmwTYVQ8oDSHQb1
# WAQHsRgwggV3MIIEX6ADAgECAhAT6ihwW/Ts7Qw2YwmAYUM2MA0GCSqGSIb3DQEB
# DAUAMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQKEwtBZGRUcnVzdCBBQjEmMCQGA1UE
# CxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5ldHdvcmsxIjAgBgNVBAMTGUFkZFRy
# dXN0IEV4dGVybmFsIENBIFJvb3QwHhcNMDAwNTMwMTA0ODM4WhcNMjAwNTMwMTA0
# ODM4WjCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNV
# BAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# LjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCAEmUXNg7D2wiz0KxXDXbt
# zSfTTK1Qg2HiqiBNCS1kCdzOiZ/MPans9s/B3PHTsdZ7NygRK0faOca8Ohm0X6a9
# fZ2jY0K2dvKpOyuR+OJv0OwWIJAJPuLodMkYtJHUYmTbf6MG8YgYapAiPLz+E/CH
# FHv25B+O1ORRxhFnRghRy4YUVD+8M/5+bJz/Fp0YvVGONaanZshyZ9shZrHUm3gD
# wFA66Mzw3LyeTP6vBZY1H1dat//O+T23LLb2VN3I5xI6Ta5MirdcmrS3ID3KfyI0
# rn47aGYBROcBTkZTmzNg95S+UzeQc0PzMsNT79uq/nROacdrjGCT3sTHDN/hMq7M
# kztReJVni+49Vv4M0GkPGw/zJSZrM233bkf6c0Plfg6lZrEpfDKEY1WJxA3Bk1Qw
# GROs0303p+tdOmw1XNtB1xLaqUkL39iAigmTYo61Zs8liM2EuLE/pDkP2QKe6xJM
# lXzzawWpXhaDzLhn4ugTncxbgtNMs+1b/97lc6wjOy0AvzVVdAlJ2ElYGn+SNuZR
# kg7zJn0cTRe8yexDJtC/QV9AqURE9JnnV4eeUB9XVKg+/XRjL7FQZQnmWEIuQxpM
# tPAlR1n6BB6T1CZGSlCBst6+eLf8ZxXhyVeEHg9j1uliutZfVS7qXMYoCAQlObgO
# K6nyTJccBz8NUvXt7y+CDwIDAQABo4H0MIHxMB8GA1UdIwQYMBaAFK29mHo0tCb3
# +sQmVO8DveAky1QaMB0GA1UdDgQWBBRTeb9aqitKz1SA4dibwJ3ysgNmyzAOBgNV
# HQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zARBgNVHSAECjAIMAYGBFUdIAAw
# RAYDVR0fBD0wOzA5oDegNYYzaHR0cDovL2NybC51c2VydHJ1c3QuY29tL0FkZFRy
# dXN0RXh0ZXJuYWxDQVJvb3QuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcw
# AYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAQEA
# k2X2N4OVD17Dghwf1nfnPIrAqgnw6Qsm8eDCanWhx3nJuVJgyCkSDvCtA9YJxHbf
# 5aaBladG2oJXqZWSxbaPAyJsM3fBezIXbgfOWhRBOgUkG/YUBjuoJSQOu8wqdd25
# cEE/fNBjNiEHH0b/YKSR4We83h9+GRTJY2eR6mcHa7SPi8BuQ33DoYBssh68U4V9
# 3JChpLwt70ZyVzUFv7tGu25tN5m2/yOSkcZuQPiPKVbqX9VfFFOs8E9h6vcizKdW
# C+K4NB8m2XsZBWg/ujzUOAai0+aPDuO0cW1AQsWEtECVK/RloEh59h2BY5adT3Xg
# +HzkjqnR8q2Ks4zHIc3C7zCCBa4wggSWoAMCAQICEAcDcdEPeVpAcZkrlAdim+Iw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1JMRIwEAYD
# VQQHEwlBbm4gQXJib3IxEjAQBgNVBAoTCUludGVybmV0MjERMA8GA1UECxMISW5D
# b21tb24xJTAjBgNVBAMTHEluQ29tbW9uIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcN
# MTgwNjIxMDAwMDAwWhcNMjEwNjIwMjM1OTU5WjCBuTELMAkGA1UEBhMCVVMxDjAM
# BgNVBBEMBTgwMjA0MQswCQYDVQQIDAJDTzEPMA0GA1UEBwwGRGVudmVyMRgwFgYD
# VQQJDA8xMjAxIDV0aCBTdHJlZXQxMDAuBgNVBAoMJ01ldHJvcG9saXRhbiBTdGF0
# ZSBVbml2ZXJzaXR5IG9mIERlbnZlcjEwMC4GA1UEAwwnTWV0cm9wb2xpdGFuIFN0
# YXRlIFVuaXZlcnNpdHkgb2YgRGVudmVyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAy1eJKMQONg0Ehhew+cUYfBmq9LmWBE1JpCOzLGAuwYjrIssMKlpj
# LcIHA3WifhCdjMRCmwdX5Mn/crrVm+oDGFHoCfDxONWNoHeQ920omMRSWCJc0rSc
# NHIxVqxnJ5cAtHlJNJ/VLGgy3wcgN3QpMHzKEwTp7MV0XPAHkd7b+PI6zB9iw36f
# iTZD1RxpW1aALNa5rf1qfA29rszga6A87lmQXpeSsbNEeldy1X8WTouao9jqxGbj
# mdJycLUpDc03+3pkEfOYC2BtlrjWjn4C812S/1NUXpLc4Mal/eopbySMW3zYsth1
# mLRXTuWf5L8G0CUZQ86+p6bgSRsy1nkzcwIDAQABo4IB7DCCAegwHwYDVR0jBBgw
# FoAUrjUjF///Bj2cUOCMJGUzHnAQiKIwHQYDVR0OBBYEFKXpiG68+Uil9fM4ir5j
# +aQMY5sPMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBmBgNVHSAEXzBdMFsGDCsGAQQB
# riMBBAMCATBLMEkGCCsGAQUFBwIBFj1odHRwczovL3d3dy5pbmNvbW1vbi5vcmcv
# Y2VydC9yZXBvc2l0b3J5L2Nwc19jb2RlX3NpZ25pbmcucGRmMEkGA1UdHwRCMEAw
# PqA8oDqGOGh0dHA6Ly9jcmwuaW5jb21tb24tcnNhLm9yZy9JbkNvbW1vblJTQUNv
# ZGVTaWduaW5nQ0EuY3JsMH4GCCsGAQUFBwEBBHIwcDBEBggrBgEFBQcwAoY4aHR0
# cDovL2NydC5pbmNvbW1vbi1yc2Eub3JnL0luQ29tbW9uUlNBQ29kZVNpZ25pbmdD
# QS5jcnQwKAYIKwYBBQUHMAGGHGh0dHA6Ly9vY3NwLmluY29tbW9uLXJzYS5vcmcw
# LQYDVR0RBCYwJIEiaXRzc3lzdGVtZW5naW5lZXJpbmdAbXN1ZGVudmVyLmVkdTAN
# BgkqhkiG9w0BAQsFAAOCAQEAhzY9WrsFqZYC6PIJA8ewYINszeLU5jmeu4D9861s
# nqYm9P1Qljj7rWCtwcvNXuinXLSdGFXjn1Osp8co7ja5HJml2cdo6gLTzRx+D/QT
# AUlHLdtgHS+RU/xN5SS9SFu1w9Wh8jU//CH1lPaJhUJ6s44CqK/FaqHwO37yhJuN
# IaE8VbK7ThvxRzNsr/3u5d2ArTM1xcMlSMwqvoJt698tAt9CIU+LNp6P7Z+9H+Nk
# cC/E71bauF3o3DqAWzarc/gIUrT7ICQUIuT73Cyn5GxG9GS91Ymn5qc28Ao7JV8K
# PqzPl1A8AhgjIuHL3N7e1pUqb30NBBlX/A38BM8N+0sabTCCBeswggPToAMCAQIC
# EGXh4uPV3lBFhfMmJIAF4tQwDQYJKoZIhvcNAQENBQAwgYgxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwG
# A1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3Qg
# UlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTE0MDkxOTAwMDAwMFoXDTI0
# MDkxODIzNTk1OVowfDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1JMRIwEAYDVQQH
# EwlBbm4gQXJib3IxEjAQBgNVBAoTCUludGVybmV0MjERMA8GA1UECxMISW5Db21t
# b24xJTAjBgNVBAMTHEluQ29tbW9uIFJTQSBDb2RlIFNpZ25pbmcgQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDAoC+LHnq7anWs+D7co7o5Isrzo3bk
# v30wJ+a605gyViNcBoaXDYDo7aKBNesL9l5+qT5oc/2d1Gd5zqrqaLcZ2xx2OlmH
# XV6Zx6GyuKmEcwzMq4dGHGrH7zklvqfd2iw1cDYdIi4gO93jHA4/NJ/lff5VgFsG
# fIJXhFXzOPvyDDapuV6yxYFHI30SgaDAASg+A/k4l6OtAvICaP3VAav11VFNUNMX
# IkblcxjgOuQ3d1HInn1Sik+A3Ca5wEzK/FH6EAkRelcqc8TgISpswlS9HD6D+Fup
# LPH623jP2YmabaP/Dac/fkxWI9YJvuGlHYsHxb/j31iq76SvgssF+AoJAgMBAAGj
# ggFaMIIBVjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4E
# FgQUrjUjF///Bj2cUOCMJGUzHnAQiKIwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYDVR0gBAowCDAGBgRV
# HSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEFBQcB
# AQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VS
# VHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3Au
# dXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQ0FAAOCAgEARiy2f2pOJWa9nGqmqtCe
# vQ+uTjX88DgnwcedBMmCNNuG4RP3wZaNMEQT0jXtefdXXJOmEldtq3mXwSZk38lc
# y8M2om2TI6HbqjACa+q4wIXWkqJBbK4MOWXFH0wQKnrEXjCcfUxyzhZ4s6tA/L4L
# mRYTmCD/srpz0bVU3AuSX+mj05E+WPEop4WE+D35OLcnMcjFbst3KWN99xxaK40V
# HnX8EkcBkipQPDcuyt1hbOCDjHTq2Ay84R/SchN6WkVPGpW8y0mGc59lul1dlDmj
# VOynF9MRU5ACynTkdQ0JfKHOeVUuvQlo2Qzt52CTn3OZ1NtIZ0yrxm267pXKuK86
# UxI9aZrLkyO/BPO42itvAG/QMv7tzJkGns1hmi74OgZ3WUVk3SNTkixAqCbf7TSm
# ecnrtyt0XB/P/xurcyFOIo5YRvTgVPc5lWn6PO9oKEdYtDyBsI5GAKVpmrUfdqoj
# sl5GRYQQSnpO/hYBWyv+LsuhdTvaA5vwIDM8WrAjgTFx2vGnQjg5dsQIeUOpTixM
# ierCUzCh+bF47i73jX3qoiolCX7xLKSXTpWS2oy7HzgjDdlAsfTwnwton5YNTJxz
# g6NjrUjsUbEIORtJB/eeld5EWbQgGfwaJb5NEOTonZckUtYS1VmaFugWUEuhSWod
# QIq7RA6FT/4AQ6qdj3yPbNExggTpMIIE5QIBATCBkDB8MQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCTUkxEjAQBgNVBAcTCUFubiBBcmJvcjESMBAGA1UEChMJSW50ZXJu
# ZXQyMREwDwYDVQQLEwhJbkNvbW1vbjElMCMGA1UEAxMcSW5Db21tb24gUlNBIENv
# ZGUgU2lnbmluZyBDQQIQBwNx0Q95WkBxmSuUB2Kb4jANBglghkgBZQMEAgEFAKCB
# hDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJ
# BDEiBCAisjXC/xqJ8JedbJhY6Ejp9D1VwS5NFoiLl1tAInx2MjANBgkqhkiG9w0B
# AQEFAASCAQBDxQLbtsqabgOJFzDXAt9928wwwqeK0h46zbEPBqtwG4vjok5mPImG
# NH9y2EywUtvNkOAjURdJhbv1gOFjeXqOKYbfMRwLEULV4A2Ocmq/8mHuMxLIDRfT
# I2YlPVLteFNdYQkQdKuJUkD6gIyc+8Xn2HA1Tc+dEalf+rJ1DEpMpy0TF9Lyiy2I
# IMvM6M+QIdNdEL6vKtgHTMHUAQJAI1iNy7OxZfyuc9IFQoJZTjbCdxO3M32WF2t+
# gwgm7op/qx/7YVr/UTdK4JRrTl28Vx+4cWn5CDbH8XiYIBa4lGS6ol+L7GTI3yq3
# rcksypd/m9n5Z2uZ77Bc/J4MskslgqX+oYICojCCAp4GCSqGSIb3DQEJBjGCAo8w
# ggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh
# 1pmnZJc+8fhCfukZzFNBFDAJBgUrDgMCGgUAoIH9MBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE5MDcxNDIxMzExMlowIwYJKoZIhvcN
# AQkEMRYEFAW1ZYNj40HLy03fhcj0uimlqrBxMIGdBgsqhkiG9w0BCRACDDGBjTCB
# ijCBhzCBhAQUY7gvq2H1g5CWlQULACScUCkz7HkwbDBWpFQwUjELMAkGA1UEBhMC
# QkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNp
# Z24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh1pmnZJc+8fhCfukZzFNBFDANBgkq
# hkiG9w0BAQEFAASCAQBpWLX1i6KoQxGH0u4O79pmXupjgIlcbsEmSPpeLsZ0OZhb
# sln1BXvwRiau37fpEYiE7QMJRJz/5O6FxT49k+dMj7Uc7WdxF4iBOXODFcrDMZU0
# 3aPN+yP+uzah8zY9XRtestKfAOVOFbzc5Gk/zb4hJEbA5r4el91LKSdv1frO9SXF
# Y9dpFEb6tfjUnUV18nXpWi4xjCdpczX5YC4uFK3wE6HCtYb1H2//U+TQkU+gUJb9
# GcTaEOogC7b5E2L3VwzdBZYzfwIE+ImgRVuAphVwsOtbwX0vL96l4i4opZ/Podoz
# n2c1mgpCsTM1m8qYCctA/YRkglEuOV0mpb9Ri3RJ
# SIG # End signature block
