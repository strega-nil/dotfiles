#Requires -Version 7
using module "./nicole-git.psm1"

Set-StrictMode -Version 2

function Split-PathToArray {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory)]
		[String]$Path
	)

	if ($IsWindows) {
		$Path -split '[\\/]'
	}
 else {
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
	}
 else {
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
		}
		else {
			$prompt += Join-PathFromArray $drive '..' $path[-3] $path[-2] $path[-1]
		}
	}

	"$prompt> "
}

if ($IsWindows -and -not (Test-Path Env:/SKIP_DEVELOPER_PROMPT)) {
	if (Test-Path Env:/DEVELOPER_PROMPT_HOST_ARCHITECTURE) {
		$hostArchToUse = "$Env:DEVELOPER_PROMPT_HOST_ARCHITECTURE"
	} elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_IDENTIFIER -match "ARMv[8,9] \(64-bit\)") {
		$hostArchToUse = 'x64'
	} else {
		$hostArchToUse = 'x64'
	}

	if (Test-Path Env:/DEVELOPER_PROMPT_ARCHITECTURE) {
		$archToUse = "$Env:DEVELOPER_PROMPT_ARCHITECTURE"
	} elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_IDENTIFIER -match "ARMv[8,9] \(64-bit\)") {
		$archToUse = 'arm64'
	} else {
		$archToUse = 'x64'
	}

	$vswherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
	if (Test-Path $vswherePath) {
		$installed = & $vswherePath -products * -format json -prerelease | ConvertFrom-Json | Sort-Object 'installationVersion'
		if ($null -ne $installed) {
			$vs = $installed[-1]

			$installPath = $vs.installationPath
			cmd /c "`"$installPath\Common7\Tools\VsDevCmd.bat`" -host_arch=$hostArchToUse -arch=$archToUse -no_logo & set" | ForEach-Object {
				$name, $value = $_ -split '='
				if ($null -ne $name -and $null -ne $value) {
					Set-Item "Env:/$name" -Value $value
				}
			}
		}
		else {
			Write-Warning 'no installed versions of Visual Studio were found; not opening a developer shell.'
		}
	}
	else {
		Write-Warning 'vswhere was not found at its place; not opening a developer shell.'
	}
}
