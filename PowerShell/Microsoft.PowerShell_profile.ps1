#Requires -Module posh-git
#Requires -Version 7
using module "./nicole-git.psm1"

Set-StrictMode -Version 2
Import-Module -Name 'posh-git'

function Split-PathToArray {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory)]
		[String]$Path
	)

	if ($IsWindows) {
		$Path -split '[\\/]'
	} else {
		$Path -split '/'
	}
}

function Join-PathFromArray {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory, ValueFromRemainingArguments)]
		[AllowEmptyString()]
		[String[]]$PathElements
	)

	if ($IsWindows) {
		$PathElements -join '\'
	} else {
		$PathElements -join '/'
	}
}

function Prompt {
	$full_path = Split-PathToArray (Get-Location).Path

	$drive = $full_path[0] # empty on unix
	$path = $full_path[1..($full_path.Length - 1)]

	$prompt = "PS "

	if ($path.Length -ne 0) {
		if ($path.Length -lt 4) {
			$prompt += Join-PathFromArray $drive @path
		} else {
			$prompt += Join-PathFromArray $drive '..' $path[-3] $path[-2] $path[-1]
		}
	}

	"$prompt> "
}

if ($IsWindows) {
	$vswherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
	if (Test-Path $vswherePath) {
		$installed = & $vswherePath -format json | ConvertFrom-Json | Sort-Object 'installedVersion'
		if ($null -ne $installed) {
			$vs = $installed[-1]

			$installPath = $vs.installationPath
			Import-Module "$installPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
			Enter-VsDevShell `
				$vs.instanceId `
				-DevCmdArguments '-arch=amd64 -host_arch=amd64' `
				-SkipAutomaticLocation
		} else {
			Write-Warning 'no installed versions of Visual Studio were found; not opening a developer shell.'
		}
	} else {
		Write-Warning 'vswhere was not found at its place; not opening a developer shell.'
	}
}
