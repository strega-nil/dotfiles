#Requires -Version 7
Set-StrictMode -Version 2

# helper functions
function Invoke-GitCommand {
	$result = git @args
	if (-not $?) {
		throw "git $($args -join ' ') failed with error code: $LASTEXITCODE"
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
class GitBranch {
	[String]$Username
	[String]$BranchName

	[String]ToString() {
		if ([String]::IsNullOrEmpty($this.Username)) {
			return "$($this.BranchName)"
		} else {
			return "$($this.Username):$($this.BranchName)"
		}
	}
	[String]ToLocalBranch() {
		if ([String]::IsNullOrEmpty($this.Username)) {
			return "$($this.BranchName)"
		} else {
			return "dev/$($this.Username)/$($this.BranchName)"
		}
	}
	[bool]HasUsername() {
		return -not [String]::IsNullOrEmpty($this.Username)
	}

	GitBranch([String]$lUsername, [String]$lBranchName) {
		if ($null -ne $lUsername -and $lUsername.Contains(':')) {
			throw [System.ArgumentOutOfRangeException]::new(
				'Username',
				'Username must not contain a colon')
		}
		$this.Username = $lUsername
		$this.BranchName = $lBranchName
	}
	GitBranch([String]$UsernameAndBranch) {
		$lUsername,$lBranchName = $UsernameAndBranch -split ':',2
		if ($null -eq $lBranchName) {
			$lBranchName = $lUsername
			$lUsername = $null
		}

		# why can't I delegate here :(
		$result = [GitBranch]::new($lUsername, $lBranchName)
		$this.Username, $this.BranchName = $result.Username, $result.BranchName
	}
	static [GitBranch]FromLocalBranch([String]$LocalBranch) {
		if ($LocalBranch -match '^dev/([^/]+)/(.+)$') {
			$lUsername = $Matches[1]
			$lBranchName = $Matches[2]
		} else {
			$lUsername = $null
			$lBranchName = $LocalBranch
		}
		return [GitBranch]::new($lUsername, $lBranchName)
	}
}
Register-ArgumentCompleter -ParameterName 'Branch' -ScriptBlock {
	Param(
		[String]$CommandName,
		[String]$ParameterName,
		[String]$WordToComplete,
		[String]$CommandAst,
		[String]$FakeBoundParameters
	)

	$username,$branch = $WordToComplete -split ':',2
	if ($null -eq $branch) {
		git branch '--format=%(refname:short)' | % {
			if ($_.StartsWith("$username")) {
				$username,$branch = $_ -split '/',2
				if ($null -ne $branch) {
					$username
				}
			}
		}
	} else {
		git branch '--format=%(refname:short)' | % {
			if ($_.StartsWith("$username/$branch")) {
				$username,$branch = $_ -split '/',2
				if ($null -ne $branch) {
					"${username}:${branch}"
				}
			}
		}
	}
}

class GitRepo {
	<# https://github.com/microsoft/stl = {
			protocol = https
			service = github
			upstream = microsoft
			repository = stl
		}

		https://dev.azure.com/devdiv/DevDiv/_git/msvc = {
			protocol = https
			service = ado
			upstream = devdiv/DevDiv
			repository = msvc
		}
	#> 
	[String]$Protocol # https, ssh
	[String]$Service # github, ado
	[String]$Upstream
	[String]$Repository

	GitRepo([String]$Url) {
		if ($Url -match '^https://github.com/(?<upstream>[-_.a-zA-Z0-9]+)/(?<repo>[-_.a-zA-Z0-9]+)$') {
			$this.Service = 'github'
			$this.Protocol = 'https'
		} elseif ($Url -match '^git@github.com:(?<upstream>[-_.a-zA-Z0-9]+)/(?<repo>[-_.a-zA-Z0-9]+)$') {
			$this.Service = 'github'
			$this.Protocol = 'ssh'
			# https://devdiv@dev.azure.com/devdiv/DevDiv/_git/AddressSanitizer
		} elseif ($Url -match '^https://(.*@)?dev.azure.com/(?<upstream>[-_./a-zA-Z0-9]+)/_git/(?<repo>[-_.a-zA-Z0-9]+)$') {
			$this.Service = 'ado'
			$this.Protocol = 'https'
			# git@ssh.dev.azure.com:v3/devdiv/DevDiv/AddressSanitizer
		} elseif ($Url -match '^git@ssh.dev.azure.com:v3/(?<upstream>[-_./a-zA-Z0-9]+)/(?<repo>[-_.a-zA-Z0-9]+)$') {
			$this.Service = 'ado'
			$this.Protocol = 'ssh'
		} else {
			throw "Could not parse repository url `"$Url`""
		}
		$this.Upstream = $Matches['upstream']
		$this.Repository = $Matches['repo']

		if ($this.Repository -match '^(.*)\.git$') {
			$this.Repository = $Matches[1] # remove trailing .git
		}
	}

	[String]ProtocolAndService() {
		if ($this.Service -notin 'github','ado') {
			throw "Invalid service '$($this.Service)' - expected github, ado"
		} elseif ($this.Protocol -notin 'https','ssh') {
			throw "Invalid protocol '$($this.Protocol)' - expected https, ssh"
		}
		return "$($this.Service):$($this.Protocol)"
	}

	[String]ToString() {
		$pas = $this.ProtocolAndService()
		if ($pas -eq 'github:https') {
			return "https://github.com/$($this.Upstream)/$($this.Repository)"
		} elseif ($pas -eq 'github:ssh') {
			return "git@github.com:$($this.Upstream)/$($this.Repository)"
		} elseif ($pas -eq 'ado:https') {
			$username, $rest = $this.Upstream -split '/',2
			return "https://$username@dev.azure.com/$($this.Upstream)/_git/$($this.Repository)"
		} elseif ($pas -eq 'ado:ssh') {
			return "git@ssh.dev.azure.com:v3/$($this.Upstream)/$($this.Repository)"
		} else {
			throw "[GitRepo]::ToString() internal error: $pas"
		}
	}

	[String]UrlForBranch([GitBranch]$Branch) {
		$pas = $this.ProtocolAndService()
		if (-not $Branch.HasUsername() -or $this.Service -eq 'ado') {
			return $this.ToString()
		} elseif ($pas -eq 'github:https') {
			return "https://github.com/$($Branch.Username)/$($this.Repository)"
		} elseif ($pas -eq 'github:ssh') {
			return "git@github.com:$($Branch.Username)/$($this.Repository)"
		} else {
			throw "[GitRepo]::UrlForBranch() internal error: $pas"
		}
	}

	[String]BranchNameForBranch([GitBranch]$Branch) {
		if (-not $Branch.HasUsername() -or $this.Service -eq 'github') {
			return $Branch.BranchName
		} elseif ($this.Service -eq 'ado') {
			if ($this.Upstream -match '^microsoft/') {
				return "user/$($Branch.Username)/$($Branch.BranchName)"
			} else {
				return "dev/$($Branch.Username)/$($Branch.BranchName)"
			}
		} else {
			throw "Invalid service '$($this.Service)' - expected github, ado"
		}
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

Register-ArgumentCompleter -CommandName 'New-GitBranch' -ParameterName 'BaseBranch' -ScriptBlock {
	Param(
		[String]$CommandName,
		[String]$ParameterName,
		[String]$WordToComplete,
		[String]$CommandAst,
		[String]$FakeBoundParameters
	)

	git branch '--format=%(refname:short)' | % {
		if ($_.StartsWith($WordToComplete)) {
			$_
		}
	}
}

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

function Get-CurrentGitBranch {
	[CmdletBinding()]
	Param()

	[GitBranch]::FromLocalBranch((Invoke-GitCommand branch --show-current))
}
Set-Alias -Name 'gcgb' -Value 'Get-CurrentGitBranch'
Export-ModuleMember `
	-Function 'Get-CurrentGitBranch' `
	-Alias 'gcgb'

function Get-CurrentGitRepo {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[String]$RemoteName
	)

	if ([String]::IsNullOrEmpty($RemoteName)) {
		[String[]]$remotes = git remote | Where-Object {
			$_ -in 'origin','upstream'
		}
		if ($null -eq $remotes) {
			throw "Unknown default remote name - expected one of origin, upstream"
		}

		$RemoteName = $remotes[0]
	}

	[GitRepo]::new((Invoke-GitCommand remote get-url $RemoteName))
}
Set-Alias -Name 'gcgr' -Value 'Get-CurrentGitRepo'
Export-ModuleMember `
	-Function 'Get-CurrentGitRepo' `
	-Alias 'gcgr'

<# NEED DOCS #>
function Update-GitBranch {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[GitBranch]$Branch,
		[Parameter()]
		[Switch]$OnlyFetch,
		[Parameter()]
		[Switch]$Force
	)

	if ($null -eq $Branch) {
		$Branch = Get-CurrentGitBranch
	}

	$repo = Get-CurrentGitRepo
	Invoke-GitCommand fetch $repo.UrlForBranch($Branch) $repo.BranchNameForBranch($Branch) | Out-Host

	if ($OnlyFetch) {
		return 'FETCH_HEAD'
	}

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
		$Branch = Get-CurrentGitBranch
	}

	$repo = Get-CurrentGitRepo
	if ($Force) {
		Invoke-GitCommand push --force $repo.UrlForBranch($Branch) "$($Branch.ToLocalBranch()):$($repo.BranchNameForBranch($Branch))"
	} else {
		Invoke-GitCommand push $repo.UrlForBranch($Branch) "$($Branch.ToLocalBranch()):$($repo.BranchNameForBranch($Branch))"
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

	if ($null -eq $Branch) {
		$Branch = Get-CurrentGitBranch
	}
	$repo = Get-CurrentGitRepo
	Invoke-GitCommand push -d $repo.UrlForBranch($Branch) $repo.BranchNameForBranch($Branch)
}
Set-Alias -Name 'upgb' -Value 'Unpublish-GitBranch'
Export-ModuleMember `
	-Function 'Unpublish-GitBranch' `
	-Alias 'upgb'
