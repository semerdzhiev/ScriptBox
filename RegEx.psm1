Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Move-ItemRegex {

	<#

	.SYNOPSIS
		Move an item to a new location, base on its name

	.DESCRIPTION
		This command matches the name of an item against a regular expression.
		The results of the match are used to determine the new location,
		where the item will be moved in.

	.PARAMETER Path
		Paths of the items to move. You can use full or relative paths and wildcards.

	.PARAMETER ItemNameRegEx
		A regular expression, which will be matched against each item in Path.
		Only items that match the regular expression will be moved.

	.PARAMETER NewLocationTemplate
		A template, used to determine the new location where the item will be moved.
		You can use this parameter if you want to move the item to another location.
		If you set this parameter to "" or NULL, the item will be kept in the same location
		and it will just be renamed, according to the value of NewNameTemplate.
		The syntax for the template is the same as the one for .NET's String.Format method.
		The placeholders {1}, {2}, etc. in the template will be replaced with the
		first, second, etc. capture group from the regular expression match.

	.PARAMETER NewNameTemplate
		A template used to generate a new name for the item.
		You can use this parameter if you want to change the name of the item you are moving.
		If you set this parameter to "" or NULL, the name of the item will not be changed
		and it will just be moved to the location specified by NewLocationTemplate.

	.PARAMETER MatchAgainst
		Specifies what part of the item's name to match the regular expression against.
		Can be one of the following:
			- "Name" - matches against the name (default)
			- "Basename" - matches against the basename of the file (name without subdirectory and extension)
			- "FullName" - matches against the full path of the item

	.EXAMPLE
		Move-ItemRegex 01-info.txt '(\d+)' '{1}'

		Will move the file "01-info.txt" to "01\01-info.txt"
		If the directory "01\" does not exist, it will be created.

	.EXAMPLE
		Move-ItemRegex 01-info.txt '(\d+)-(.+)' '{1}' '{2}'

		Will move the file "01-info.txt" to "01\info.txt"

	.EXAMPLE
		Move-ItemRegex *.txt '(\d+)' '{1}'

		Will move each text file, whose name starts with a number to a subdirectory
		named after that number. For example a file called "01-info.txt" will go to a
		subdirectory "01\", "00000abc.txt" will go to "00000\" and a file called
		"abc.txt" will not be processed, as it does not match the regular expression.

	.EXAMPLE
		Move-ItemRegex 01-info.txt '(\d+)-(.+)\.txt' '{1}\{2}' '{2}.txt'
		
		In this example 01-info.txt has to be moved to a subdirectory of a subdirectory - "01\info\".
		They both will be created if they don't exist. The fil will be renamed to info.txt.

	.EXAMPLE
		Move-ItemRegex a-1.txt "(.)-(\d)" '`[{1}{1}`]\`[{2}{2}`]' '`[{1}`]'

		Since the square brackets have special meaning to the shell, if you want the
		newly generated names to contain them, you will have to escape them.
		This example moves the file a-1.txt to a subfolder in a subfolder,
		called "[aa]\[11]" and renames the file to "[a].txt"

	.NOTES
		Author: Atanas Semerdzhiev

	#>

	[CmdletBinding(SupportsShouldProcess = $True)]

	Param(
		[Parameter(Position=0,
		           Mandatory=$True,
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[SupportsWildcards()] 
		[string[]]$Path,

		[Parameter(Position=1,
		           Mandatory=$True)]
		[ValidateNotNullOrEmpty()]
		[string]$ItemNameRegEx,

		[Parameter(Position=2)]
		[PSDefaultValue(Help='"" (Does not move the item to another location)')]
		[string]$NewLocationTemplate = "",

		[Parameter(Position=3)]
		[PSDefaultValue(Help='"" (Does not change the name of the item)')]
		[string]$NewNameTemplate = "",

		[ValidateSet('Name', 'Basename', 'FullName')]  
		[string]$MatchAgainst = "Name"
	)

	Begin
	{
		Write-Verbose "Using regular expression /$ItemNameRegEx/"
		Write-Verbose "New location template is ""$NewLocationTemplate"""
		Write-Verbose "New name template is ""$NewNameTemplate"""
		Write-Verbose "regular expression is matched agains ""$MatchAgainst"""

		if( (-not $NewNameTemplate) -and (-not $NewLocationTemplate) )
		{
			Write-Error "-NewNameTemplate and -NewLocationTemplate cannot both be NULL or empty!"
			return
		}
	}

	Process
	{
		foreach($p in $Path)
		{
			# The path may contain wildcards, so we need to resolve it first.
			$actualPaths = Resolve-Path $p

			# If no Resolve-Path returned an empty array, then $p does not
			# contain a valid path.
			if ( -not $actualPaths )
			{
				Write-Error "Path ""$p"" cannot be resolved!"
				continue
			}

			foreach($ap in $actualPaths)
			{
				# Obtain item information
				$itemInfo = Get-Item $ap

				# Determine what to match against
				$itemName = ""

				switch ($MatchAgainst)
				{
					"Name"		{ $itemName = $itemInfo.Name }
					"FullName"	{ $itemName = $itemInfo.FullName }
					"Basename"	{ $itemName = $itemInfo.Basename }
					default		{ $itemName = $itemInfo.Name }
				}

				Write-Debug "Matching against $itemName"

				# If the item does not match the regular expression, skip it
				if( -not ($itemName -match $ItemNameRegEx) )
				{
					Write-Verbose "Skipping $($itemInfo.Name)"
					continue
				}

				# We have a match, so we will have to process the item.
				# First, we use the templates to generate the new location and name for the item
				# The String.Format function requires an array and $matches is a hash table.
				# Thus we need to convert the match results into an array.
				# We create a new array, copy the results into it and finally reverse it, as they
				# are copied in reverse order.
				$buffer = 1..$matches.Count
				$matches.Values.CopyTo($buffer, 0)
				[System.Array]::Reverse($buffer)

				$locationToMoveTo = $itemInfo.Directory
				if($NewLocationTemplate)
				{
					$locationToMoveTo = [System.String]::Format($NewLocationTemplate, $buffer)
				}

				$newName = $itemInfo.Name
				if($NewNameTemplate)
				{
					$newName = [System.String]::Format($NewNameTemplate, $buffer)
				}

				# Previously, the function auto-escaped special characters used in the templates.
				# This is now left to the user.
				#
				# Problems may occur when [ and ] are used in the template of the new location,
				# as they are treated as wildcards by the shell.
				# Thus, we have to escape all wildcard characters from the newly-generated name
				# This article shows how to solve the problem:
				# http://www.vistax64.com/powershell/13575-square-brackets-file-names-unexpected-results.html
				# $locationToMoveTo = [Management.Automation.WildcardPattern]::Escape($locationToMoveTo)


				# If the user wants to move to a new location:
				# The name of the location to move to must either be new (non-existant) or if
				# it already exists, it must be a container (e.g. a directory).
				# If it is the name of a leaf (e.g. a file), then this is an error 
				if( $NewLocationTemplate -and (Test-Path "$locationToMoveTo" -PathType Leaf) )
				{
					Write-Error "Cannot move ""$($itemInfo.Name)"" to ""$locationToMoveTo"", because it already exists and is not a container." -RecommendedAction "Review the directory template or the list of input files"
					continue
				}


				# If running with the -WhatIf switch, add the newly-generated name
				# to the list of generated items
				# if($WhatIfPreference)
				# {
				#	$movedItems += $unique.Name
				# }


				# Now move the item, if allowed	
				if($PSCmdlet.ShouldProcess("$($itemInfo.FullName) --> $locationToMoveTo\$newName", "Move"))
				{
					# If the user wants to move and the destination does not exist, create it
					if( $NewLocationTemplate -and (-not (Test-Path $locationToMoveTo)) )
					{
						New-Item "$locationToMoveTo" -Type Directory -Confirm:$false | Out-Null
					}

					# Another item with the same name may already exist at the destination.
					# We need to generate an unique name
					# $unique = Get-UniqueName -Name $itemInfo.Name -Destination $locationToMoveTo -ExcludeNames $movedItems
					$unique = Get-UniqueName -Name "$newName" -Directory "$locationToMoveTo"

					Move-Item -LiteralPath "$($itemInfo.FullName)" -Destination "$($unique.FullName)" -Confirm:$false
				}
			
			} # foreach($ap in $actualPaths)

		} # foreach($p in $Path)

	} # Process
} # Function