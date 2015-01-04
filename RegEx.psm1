Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Move-ItemByRegex {

	<#

	.SYNOPSIS
		Move an item to a directory, based on its name

	.DESCRIPTION
		This command matches the name of an item against a regular expression
		and uses the results of the match to determine directory, to place the item in.

	.PARAMETER Path
		Specifies the path to the items to move.

	.PARAMETER FileRegEx
		Specifies a regular expression, which will be matched against each item in Path.
		Only items that match the regular expression will be moved.

	.PARAMETER MatchAgainst
		Specifies what part of the item's name to match the regular expression against.
		Can be one of the following:
			- "Name" - matches against the name
			- "Basename" - matches against the basename of the file (name without subdirectory and extension)
			- "FullName" - matches against the full path of the item

	.PARAMETER DirectoryTemplate
		Specifies a template, which is used to determine the name of the directory,
		in which the item will be moved. 
		The syntax for the template is the same as the one for .NET's String.Format method.
		You can use {1}, {2}, etc. in the template and they will be replaced with the
		first, second, etc. capture group, which resulted from the regular expression match.		

	.EXAMPLE
		Get-ChildItem * | Rename-Transliterate -Confirm
		Run in interactive mode - you will have to confirm or reject
		the transliteration for each file/directory

	.NOTES
		Author: Atanas Semerdzhiev

	#>

	[CmdletBinding(SupportsShouldProcess = $True)]

	Param(
		[Parameter(Mandatory=$True,
				   Position=0,
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True)]
		[Alias('FullName')]
		[string[]]$Path,

		[string]$FileRegEx = "(.+)",

		[string]$MatchAgainst = "Name",

		[string]$DirectoryTemplate = "{1}"
	)

	Begin
	{
		Write-Verbose "Using regular expression /$FileRegEx/"
		Write-Verbose "Directory template is ""$DirectoryTemplate"""

		# A bag of the paths of the items moved by the command
		# This variable is only used when running with the -WhatIf switch
		# [string[]] $movedItems = @()
	}

	Process
	{
		foreach($p in $Path)
		{
			if ( -not (Test-Path $p) )
			{
				Write-Error "Path ""$p"" does not exist."
				continue
			}

			# Obtain item information
			$fileInfo = Get-Item $p

			# Determine what to match against
			$itemName = ""

			switch ($MatchAgainst)
			{
				"Name"		{ $itemName = $fileInfo.Name }
				"FullName"	{ $itemName = $fileInfo.FullName }
				"Basename"	{ $itemName = $fileInfo.Basename }
				default		{ $itemName = $fileInfo.Name }
			}

			Write-Debug "Matching against $itemName"

			# If the item does not match the regular expression, skip it
		    if( -not ($itemName -match $FileRegEx) )
			{
				Write-Verbose "Skipping $($fileInfo.Name)"
				continue
			}


			# First, generate the new name using the template.
			# The String.Format function requires an array and $matches is a hash table.
			# Thus we need to convert the match results into an array.
			# We create a new array, copy the results into it and finally reverse it, as they
			# are copied in reverse order.
			$buffer = 1..$matches.Count
			$matches.Values.CopyTo($buffer, 0)
			[System.Array]::Reverse($buffer)

			$dirToMoveTo = [System.String]::Format($DirectoryTemplate, $buffer)
		
			# Problems may occur when [ and ] are used in the file name,
			# as they are treated as wildcards by the shell.
			# So, we have to escape all wildcard characters from the newly-generated name
			# This article shows how to solve the problem:
			# http://www.vistax64.com/powershell/13575-square-brackets-file-names-unexpected-results.html
			$dirToMoveTo = [Management.Automation.WildcardPattern]::Escape($dirToMoveTo)


			# The generated container name may be the name of an already-existing non-container (e.g. file)
			if( Test-Path $dirToMoveTo -PathType Leaf)
			{
				Write-Error "Cannot move [$($fileInfo.Name)] to [$dirToMoveTo], because it already exists and is not a container." -RecommendedAction "Review the directory template or the list of input files"
				continue
			}


			# If running with the -WhatIf switch, add the newly-generated name
			# to the list of generated items
			# if($WhatIfPreference)
			# {
			#	$movedItems += $unique.Name
			# }

		
			# Now move the item, if allowed	
			if($PSCmdlet.ShouldProcess("$($fileInfo.FullName) --> $DirToMoveTo\", "Move"))
			{
				if( -not (Test-Path $dirToMoveTo) )
				{
					New-Item $dirToMoveTo -Type Directory | Out-Null
				}

				# Another item with the same name may already exist at the destination.
				# We need to generate an unique name
				# $unique = Get-UniqueName -Name $fileInfo.Name -Destination $DirToMoveTo -ExcludeNames $movedItems
				$unique = Get-UniqueName -Name $fileInfo.Name -Destination $DirToMoveTo

				Move-Item $fileInfo.FullName $unique.FullName
			}

		} # foreach($p in $Path)

	} # Process
} # Function