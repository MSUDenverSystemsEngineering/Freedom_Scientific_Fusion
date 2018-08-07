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
	[string]$appVersion = '2018'
	[string]$appArch = 'x86'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '3.7.0.1'
	[string]$appScriptDate = '08/07/2018'
	[string]$appScriptAuthor = 'Metropolitan State University of Denver'
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
		## Install Fusion 2018 silently
		$exitCode = Execute-Process -Path "$dirFiles\ZF2018.1807.4.400-enu.exe" -Parameters "/Type Silent" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}
		## Wait for Fusion 2018 installation to complete
		Wait-Process -Name "ZF2018.1807.4.400-enu.exe"

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		## Remvoe Desktop Shortcuts of Fusion 2018
		Remove-File -Path "$env:Public\Desktop\FSReader 3.0.lnk"
		Remove-File -Path "$env:Public\Desktop\Fusion 2018.lnk"
		Remove-File -Path "$env:Public\Desktop\JAWS 2018.lnk"
		Remove-File -Path "$env:Public\Desktop\ZoomText 2018.lnk"
		## Set LSHOST Environment Variable for Network Licensing
		[Environment]::SetEnvironmentVariable('LSHOST', 'VMWAS22', 'Machine')
		## Prompt for restart
		Show-InstallationRestartPrompt -NoCountdown

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
		$exitCode = Execute-Process -Path "$dirFiles\ZF2018.1807.4.400-enu.exe" -Parameters "/Type SilentSharedUninstall" -WindowStyle "Hidden" -PassThru -WaitForMsiExec
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) {
			$mainExitCode = $exitCode.ExitCode
		}
		## Wait for Fusion uinstallation to complete
		Wait-Process -Name "ZF2018.1807.4.400-enu.exe"
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


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
		## Prompt for restart
		Show-InstallationRestartPrompt -NoCountdown

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
