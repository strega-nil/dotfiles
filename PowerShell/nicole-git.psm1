#Requires -Version 7
Set-StrictMode -Version 2

# helper functions
function Invoke-GitCommand {
	[CmdletBinding()]
	Param(
		[Parameter(ValueFromRemainingArguments)]
		[String[]]$Arguments
	)

	$result = git @Arguments
	if (-not $?) {
		throw "git $($Arguments -join ' ') failed with error code: $LASTEXITCODE"
	}
	$result
}
function Get-GitMainBranch {
	[CmdletBinding()]
	Param()

	$testNames = @('main', 'master', 'trunk')
	foreach ($testName in $testNames) {
		$output = Invoke-GitCommand branch --list $testName
		if ($null -ne $output) {
			return $testName
		}
	}
}

<#
.SYNOPSIS
Add-GitChangesToHead amends the latest commit with the specified changes.

.DESCRIPTION
Add-GitChangesToHead takes a set of changes:

- All changes (no parameters), or
- Staged changes (pass the `-Staged` parameter), or
- Named files (pass the names of these files)

It then stages these changes if necessary,
and amends the latest commit with those changes.

.PARAMETER Staged
This switch tells Add-GitChangesToHead to add only currently staged changes.

.PARAMETER Paths
This parameter tells Add-GitChangesToHead to add only those files which
are specified to the current commit.

.EXAMPLE
```
> git commit -m '[foobar] update to 1.3'
> ./vcpkg x-add-version foobar
> Add-GitChangesToHead
```
This is a common usecase in vcpkg,
where you need to commit changes and then add version files on top.

.EXAMPLE
```
> git commit -m 'fix a bug in blah.cpp'
> # oops; typo! change blah.cpp
> ach blah.cpp
```
#>
function Add-GitChangesToHead {
	[CmdletBinding()]
	Param(
		[Parameter(ParameterSetName = 'Staged', Mandatory)]
		[Switch]$Staged,
		[Parameter(ParameterSetName = 'Paths', ValueFromRemainingArguments)]
		[String[]]$Paths
	)

	if (-not $Staged) {
		if ($null -eq $Paths -or $Paths.Length -eq 0) {
			$Paths = Invoke-GitCommand rev-parse --show-toplevel
		}

		Invoke-GitCommand reset | Out-Null
		Invoke-GitCommand add @Paths
	}
	$stagedChanges = Invoke-GitCommand diff --staged --name-only
	if ($null -ne $stagedChanges) {
		Invoke-GitCommand commit --amend --no-edit
	}
}
Set-Alias -Name 'ach' -Value 'Add-GitChangesToHead'
Export-ModuleMember `
	-Function 'Add-GitChangesToHead' `
	-Alias 'ach'

<# NEED DOCS #>
function ConvertTo-GitRepoUrl {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory)]
		[String]$Username,
		[Parameter()]
		[String]$Repository,
		[Parameter()]
		[String]$DomainName
	)

	if ([String]::IsNullOrEmpty($Repository) -or [String]::IsNullOrEmpty($DomainName)) {
		$baseUrl = git remote get-url origin 2> $null
		if (-not $?) {
			$baseUrl = git remote get-url upstream 2> $null
			if (-not $?) {
				Write-Error "Could not find repository name; please pass the Repository and DomainName parameters"
				throw
			}
		}

		if ($baseUrl -match '(?:https://|ssh://|git@)(?<dn>[-_.a-zA-Z0-9]+)[/:][-_/.a-zA-Z0-9]+/(?<repo>[-_a-zA-Z0-9]+)(?:.git)?/?') {
			if ([String]::IsNullOrEmpty($Repository)) {
				$Repository = $Matches['repo']
			}
			if ([String]::IsNullOrEmpty($DomainName)) {
				$DomainName = $Matches['dn']
			}
		} else {
			Write-Error "Could not parse repository url `"$baseUrl`"; please pass the Repository parameter"
			throw
		}
	}

	"https://$DomainName/$Username/$Repository"
}
Set-Alias -Name 'ctru' -Value 'ConvertTo-GitRepoUrl'
Export-ModuleMember `
	-Function 'ConvertTo-GitRepoUrl' `
	-Alias 'ctru'

<# NEED DOCS #>
class GitBranch {
	[String]$Username
	[String]$Branch

	[String]ToString() {
		return "$($this.Username):$($this.Branch)"
	}
	[String]ToLocalBranch() {
		return "$($this.Username)/$($this.Branch)"
	}

	GitBranch([String]$lUsername, [String]$lBranch) {
		if ($lUsername.Contains(':')) {
			throw [System.ArgumentOutOfRangeException]::new(
				'Username',
				'Username must not contain a colon')
		}
		$this.Username = $lUsername
		$this.Branch = $lBranch
	}
	GitBranch([String]$UsernameAndBranch) {
		$lUsername,$lBranch = $UsernameAndBranch -split ':',2
		if ($null -eq $lBranch) {
			throw [System.ArgumentOutOfRangeException]::new(
				'UsernameAndBranch',
				'UsernameAndBranch must be a username and branch separated by a colon')
		}

		# why can't I delegate here :(
		$result = [GitBranch]::new($lUsername, $lBranch)
		$this.Username, $this.Branch = $result.Username, $result.Branch
	}
	static [GitBranch]FromLocalBranch([String]$LocalBranch) {
		$lUsername,$lBranch = $LocalBranch -split '/',2
		if ($null -eq $lBranch) {
			throw [System.ArgumentOutOfRangeException]::new(
				'LocalBranch',
				'LocalBranch must be a username and branch separated by a slash')
		}
		return [GitBranch]::new($lUsername, $lBranch)
	}
}

<# NEED DOCS #>
function New-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory)]
		[GitBranch]$Branch,
		[Parameter()]
		[String]$BaseBranch
	)

	if ([String]::IsNullOrEmpty($BaseBranch)) {
		Invoke-GitCommand switch -c $Branch.ToLocalBranch()
	} else {
		Invoke-GitCommand switch -c $Branch.ToLocalBranch() $BaseBranch
	}
}
Set-Alias -Name 'ngb' -Value 'New-GitBranch'
Export-ModuleMember `
	-Function 'New-GitBranch' `
	-Alias 'ngb'

<# NEED DOCS #>
function Remove-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[GitBranch]$Branch
	)

	$currentBranch = Invoke-GitCommand branch --show-current

	if ($null -eq $Branch) {
		$Branch = [GitBranch]::FromLocalBranch($currentBranch)
	}

	if ($Branch.ToLocalBranch() -eq $currentBranch) {
		Invoke-GitCommand switch (Get-GitMainBranch)
	}

	Invoke-GitCommand branch -D $Branch.ToLocalBranch()
}
Set-Alias -Name 'rgb' -Value 'Remove-GitBranch'
Export-ModuleMember `
	-Function 'Remove-GitBranch' `
	-Alias 'rgb'

<# NEED DOCS #>
function Open-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory)]
		[GitBranch]$Branch
	)

	Invoke-GitCommand switch $Branch.ToLocalBranch()
}
Set-Alias -Name 'opgb' -Value 'Open-GitBranch'
Export-ModuleMember `
	-Function 'Open-GitBranch' `
	-Alias 'opgb'

<# NEED DOCS #>
function Update-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[GitBranch]$Branch,
		[Parameter()]
		[Switch]$Force
	)

	if ($null -eq $Branch) {
		$currentBranch = Invoke-GitCommand branch --show-current
		$Branch = [GitBranch]::FromLocalBranch($currentBranch)
	}

	Invoke-GitCommand fetch (ConvertTo-GitRepoUrl $Branch.Username) $Branch.Branch

	$checkForBranch = Invoke-GitCommand branch --list $Branch.ToLocalBranch()
	if ($null -eq $checkForBranch) {
		New-GitBranch $Branch FETCH_HEAD
	} else {
		Open-GitBranch $Branch
		if ($Force) {
			Invoke-GitCommand reset --hard FETCH_HEAD
		} else {
			Invoke-GitCommand merge --ff-only FETCH_HEAD
		}
	}
}
Set-Alias -Name 'udgb' -Value 'Update-GitBranch'
Export-ModuleMember `
	-Function 'Update-GitBranch' `
	-Alias 'udgb'

<# NEED DOCS #>
function Publish-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[GitBranch]$Branch,
		[Parameter()]
		[Switch]$Force
	)

	if ($null -eq $Branch) {
		$currentBranch = Invoke-GitCommand branch --show-current
		$Branch = [GitBranch]::FromLocalBranch($currentBranch)
	}

	if ($Force) {
		Invoke-GitCommand push --force (ConvertTo-GitRepoUrl $Branch.Username) "$($Branch.Username)/$($Branch.Branch):$($Branch.Branch)"
	} else {
		Invoke-GitCommand push (ConvertTo-GitRepoUrl $Branch.Username) "$($Branch.Username)/$($Branch.Branch):$($Branch.Branch)"
	}
}
Set-Alias -Name 'pbgb' -Value 'Publish-GitBranch'
Export-ModuleMember `
	-Function 'Publish-GitBranch' `
	-Alias 'pbgb'

<# NEED DOCS #>
function Unpublish-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[GitBranch]$Branch
	)

	if ([String]::IsNullOrEmpty($UsernameAndBranch)) {
		$currentBranch = Invoke-GitCommand branch --show-current
		$Branch = [GitBranch]::FromLocalBranch($currentBranch)
	}

	Invoke-GitCommand push -d (ConvertTo-GitRepoUrl $Branch.Username) $Branch.Branch
}
Set-Alias -Name 'ubgb' -Value 'Unpublish-GitBranch'
Export-ModuleMember `
	-Function 'Unpublish-GitBranch' `
	-Alias 'ubgb'
