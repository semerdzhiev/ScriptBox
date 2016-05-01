Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Import-TransliterationSchema
{
	<#
		.SYNOPSIS
			Loads a transliteration schema from a CSV file

		.DESCRIPTION
			Transliteration schemas are stored on the hard drive as CSV files.
			The first line of the file should be "Search, Replace"
			The next lines should contain pairs in the form of:
				<search>, <replace>
			When transliterating a string, every occurrence of
			<search> in it is replaced with <replace>.

		.PARAMETER Path
			Path to a CSV file, which contains a transliteration schema.
			If the path is relative, the function first tries to resolve
			it against the current working directory and if that fails -
			against the directory, where the script file is located.

		.PARAMETER CsvDelimiter
			A string which contains the delimiter character used in the
			CSV file. The default value is ",".

		.PARAMETER CsvEncoding
			The encoding of the CSV files. Should be one of the encodings
			recognized by Import-Csv. Default is UTF8

		.OUTPUTS
			An object, which contains the transliteration schema rules.
			This object can be passed to ConvertTo-TransliteratedString

		.LINK
			ConvertTo-TransliteratedString

		.NOTES
			Author: Atanas Semerdzhiev

	#>

	[CmdletBinding()]

	Param(
		[Parameter(Mandatory=$True, Position=0)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,

		[ValidateNotNullOrEmpty()]
		[string]$CsvDelimiter = ",",

		[ValidateNotNullOrEmpty()]
		[string]$CsvEncoding = "UTF8"
	)

	Process
	{
		# Check if the user has supplied a valid transliteration rules CSV file
		$csvPath = $Path
		
		if( -not (Test-Path $csvPath -PathType Leaf) )
		{
			# If the path cannot be resolved against the current working directory,
			# try to resolve it against the directory where the script is located
			$csvPath = Join-Path $PSScriptRoot $Path

			if( -not (Test-Path $csvPath -PathType Leaf) )
			{
				throw "Path ""$Path"" does not exist."
			}
		}


		# Load the contents of the CSV file
		$csvContents = Import-Csv $csvPath -Encoding $CsvEncoding -Delimiter $CsvDelimiter

		Write-Verbose "Transliteration rules loaded from ""$csvPath"""


		# Create a hash for the top level of the schema
		$transliterationSchema = @{"Character"="Top"}


		# Buld the tree that will be used for transliteration
		foreach($rule in $csvContents)
		{
			# Split the search to an array of chars
			$searchChars = $rule.Search.toCharArray()

			Write-Verbose "Rule ($($rule.Search) --> $($rule.Replace)), split: $($searchChars -join ', ')"


			# Add the search to the prefix tree
			$currentLevel = $transliterationSchema

			foreach($c in $searchChars)
			{
				# In order to make things easier, we handle letter case during the transliteration
				# for the user. Thus we only store the rules in a single case
				$ci = [Char]::ToLower($c)

				if( -not $currentLevel.ContainsKey($ci) )
				{
					$currentLevel.Add($ci, @{'Character' = $ci}) | Out-Null
				}

				$currentLevel = $currentLevel[$ci]
			}



			# Check to see if another rule for the same prefix has already been added
			if( $currentLevel.ContainsKey('Replace') )
			{
				$s1 = $currentLevel['Search']
				$r1 = $currentLevel['Replace']

				$s2 = $rule.Search
				$r2 = $rule.Replace

				Write-Warning "Conflicting rules found: 1.($s1 --> $r1) and 2.($s2 --> $r2). Second rule skipped."
			}
			else
			{
				# We are storing both the replacement string and the search string
				# in the tree, as the search string is sometimes needed too
				# (for example it is used to print the error message above)
				$currentLevel.Add('Search', $rule.Search.ToLower())
				$currentLevel.Add('Replace', $rule.Replace.ToLower())
			}
		}

		# Print-Schema -Object $transliterationSchema -Tabs ""
		

		# Return the schema as a result
		$transliterationSchema

	} # Process

} # Function



Function Write-TransliterationSchema
{
	<#
		.SYNOPSIS
			Loads and displays the contents of a transliteration schema.
	#>
	
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$True, Position=0)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,

		[string]$Tabs = ""
	)

	Process
	{
		$s = Import-TransliterationSchema "$Schema"
		
		foreach($key in $s.Keys)
		{
			if(($s[$key] -is [string]) -or ($s[$key] -is [char]))
			{
				Write-Output "$Tabs[$key] -> ""$($s[$key])"""
			}
			else
			{
				Write-Output "$Tabs[$key] ->"
				Write-TransliterationSchema $s[$key] "$Tabs`t"
			}
		}
	}
}


Function ConvertTo-TransliteratedString
{
<#
		.SYNOPSIS
			Transliterates a string, based on a schema

		.DESCRIPTION
			The function transliterates a string based on a schema.

		.PARAMETER String
			The text to be transliterated

		.PARAMETER SchemaPath
			The transliteration schema to use.
			Must be the path of a valid CSV file that can be opened by Import-TransliterationSchema

		.PARAMETER SchemaObject
			The transliteration schema to use.
			Must be an object returned by Import-TransliterationSchema
			
		.OUTPUTS
			The transliterated string

		.LINK
			Import-TransliterationSchema

		.NOTES
			Author: Atanas Semerdzhiev

	#>

	[CmdletBinding(DefaultParameterSetName=’SchemaFromFile’)]

	Param(
		[Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$True, ParameterSetName="SchemaFromFile")]
		[Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$True, ParameterSetName="SchemaFromObject")]
		[AllowEmptyString()]
		[string[]]$String,

		[Parameter(Mandatory=$True, Position=1, ParameterSetName="SchemaFromFile")]
		[ValidateNotNullOrEmpty()]
		[String]$SchemaPath,

		[Parameter(Mandatory=$True, Position=1, ParameterSetName="SchemaFromObject")]
		[ValidateNotNullOrEmpty()]
		[Object]$SchemaObject
	)

	Begin
	{
		if($PSCmdlet.ParameterSetName -eq "SchemaFromFile")
		{
			$schemaTrie = Import-TransliterationSchema "$SchemaPath"
		}
		else
		{
			$schemaTrie = $SchemaObject
		}
	}
	
	Process
	{
		foreach($s in $String)
		{
			# Split the string into array of chars
			$chars = $s.toCharArray()

			# Now transliterate the string
			$result = ""
			$i = 0

			while($i -lt $chars.length)
			{
				# In order to determine the case, we have to determine:
				# 1. The case of the first character in the current prefix (can be done now)
				# 2. Whether all characters in the prefix are uppercase (done on every step in the loop)
				$isFirstLetterUppercase = [Char]::IsUpper($chars[$i])
				$areAllLettersUppercase = $isFirstLetterUppercase
				$matchedLength = 0

				# The values below are chosen, so that even if we don't match anything,
				# we will add the current character from $chars to the result

				$lastReplace = "$($chars[$i])" # this must be a string, not a char!
				                               # otherwise the call to Substring below will fail
				$lastPos = $i

				$currentLevel = $schemaTrie # Start search from the top of the trie

				while( ($i -lt $chars.length) -and ($currentLevel.ContainsKey([Char]::ToLower($chars[$i]))) )
				{
					$areAllLettersUppercase = $areAllLettersUppercase -and [Char]::IsUpper($chars[$i])

					$currentLevel = $currentLevel[[Char]::ToLower($chars[$i])]

					if( $currentLevel.ContainsKey('Replace') )
					{
						$lastReplace = $currentLevel['Replace']
						$lastPos = $i
					}

					$matchedLength++
					$i++
				}

				# Now append the new prefix with the appropriate case
				if($areAllLettersUppercase -and ($matchedLength -gt 1) )
				{
					# We use all-uppercase when (1) the matched prefix is more than
					# one character long and (2) all characters in it are uppercase
					$result += $lastReplace.ToUpper()
				}
				elseif($isFirstLetterUppercase)
				{
					$result += $lastReplace.Substring(0,1).ToUpper() + $lastReplace.Substring(1)
				}
				else
				{
					$result += $lastReplace
				}

				$i = $lastPos + 1
			}

			# Return the result
			$result
		}
	}
}


Function Rename-Transliterate {

	<#
		.SYNOPSIS
			Transliterates the names of one or more files and/or directories

		.DESCRIPTION
			The script receives the paths of one or more files and/or directories
			and transliterates their names based on a user-defined set of rules.

			The transliteration rules should be stored in a CSV file.
			The first line of the file should be "Search, Replace". The other lines should be
			in the form (<search>, <replacement>), where <search> is text that should be transliterated
			as <replacement> by the script.

			The script reads the contents of the CSV file and then applies each rule to the
			basename of each supplied item (file or directory). The item's extension and the parent directory
			are not transliterated by the script.

		.PARAMETER Path
			Path of the file or directory, whose name will be transliterated.
			Can be either relative or absolute.
			You can pipe the results of Get-ChildItem to this parameter.

		.PARAMETER Schema
			The transliteration schema to use.
			Must be an object returned by a call to Import-TransliterationSchema

		.EXAMPLE
			Rename-Transliterate абв.txt Cyr-Lat.csv
			Transliterate a specific file

		.EXAMPLE
			Rename-Transliterate абв.txt,абв.doc,абвгд.txt Cyr-Lat.csv
			Transliterate several files

		.EXAMPLE
			Rename-Transliterate *.txt Cyr-Lat.csv
			Transliterate all .txt files

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate Cyr-Lat.csv
			To generate a list of items to transliterate, you can use Get-ChildItem.
			This example transliterate all files and subdirectories of the current directory

		.EXAMPLE
			Get-ChildItem * -Include *.cpp,*.c | Rename-Transliterate Cyr-Lat.csv
			Transliterate only .cpp and .c files in the current directory

		.EXAMPLE
			Get-ChildItem * -Attribute !Directory | Rename-Transliterate Cyr-Lat.csv
			Transliterate all files, but do not transliterate directories

		.EXAMPLE
			Get-ChildItem * -Attribute Directory | Rename-Transliterate Cyr-Lat.csv
			Transliterate only the names of directories

		.EXAMPLE
			Get-ChildItem * -Recurse | Rename-Transliterate Cyr-Lat.csv
			Transliterate the names of all items in the current directory and
			in its subdirectories.

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate Cyr-Lat.csv -WhatIf
			Test what the script will do, if we try to transliterate all the files
			in the current directory, but do not actually perform the actions

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate Cyr-Lat.csv -Confirm
			Run in interactive mode - you will have to confirm or reject
			the transliteration for each file/directory

		.LINK
			Import-TransliterationSchema

		.NOTES
			Author: Atanas Semerdzhiev

	#>

	[CmdletBinding(	SupportsShouldProcess = $True,
					DefaultParameterSetName=’SchemaFromFile’)]

	Param(
		[Parameter(Position=0,
		           Mandatory=$True,
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True,
				   ParameterSetName="SchemaFromFile")]
		[Parameter(Position=0, 
		           Mandatory=$True,
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True,
				   ParameterSetName="SchemaFromObject")]
		[ValidateNotNullOrEmpty()]
		[SupportsWildcards()]
		[Alias("FullName")]
		[string[]]$Path,

		[Parameter(Position=1,
				   Mandatory=$True,
				   ParameterSetName="SchemaFromFile")]
		[ValidateNotNullOrEmpty()]
		[String]$SchemaPath,

		[Parameter(Position=1,
				   Mandatory=$True,
				   ParameterSetName="SchemaFromObject")]
		[ValidateNotNullOrEmpty()]
		[Object]$SchemaObject
	)


	Begin
	{
		# Create an array to store the items that will be transliterated by the script
		# This array supports the functionality of the -WhatIf switch and
		# is only filled and used when this switch is supplied
		[string[]] $transliteratedItems = @()
		
		if($PSCmdlet.ParameterSetName -eq "SchemaFromFile")
		{
			$schemaTrie = Import-TransliterationSchema "$SchemaPath"
		}
		else
		{
			$schemaTrie = $SchemaObject
		}
	}


	Process {

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
				$itemInfo = Get-Item -LiteralPath "$ap"

				# Transliterate the basename
				$transliteratedBasename = ConvertTo-TransliteratedString -String "$($itemInfo.BaseName)" -SchemaObject $schemaTrie
		
				# Process the item only if transliteration has produced a different basename
				if($transliteratedBasename -ne "$($itemInfo.BaseName)")
				{
					$dir = ""
				
					if($itemInfo.PsIsContainer)
					{
						$dir = $locationToMoveTo = (Split-Path $itemInfo.FullName -Parent)
					}
					else
					{
						$dir = $itemInfo.Directory
					}
					
					# As the results of the transliteration may conflict with the name of an already existing
					# item in the target container, generate an unique name for the new file
					$unique = Get-UniqueName -Name "$transliteratedBasename$($itemInfo.Extension)" -Directory "$dir" -ExcludeNames $transliteratedItems

					# If we are running with the -WhatIf switch, add the new name
					# to the list of transliterated items
					if($WhatIfPreference)
					{
						$transliteratedNames += $unique.Name
					}

					# Now the new name is unique and we can process it
					if($PSCmdlet.ShouldProcess("$($itemInfo.FullName)", "Rename to $($unique.Name)"))
					{
						# The -Confirm switch is necessary, otherwise Rename-Item "inherits" it from our script
						Rename-Item -Path $itemInfo.FullName -NewName $unique.Name -Confirm:$false
					}
				}
				else
				{
					# Transliteration does not change the basename, so there is nothing to do
					Write-Verbose "Skipping $($itemInfo.Fullname) - nothing to do"
				}
			
			} # foreach($ap in $actualPaths)

		} # foreach($p in $Path)

	} # Process
 
 } # Function

 # Export-ModuleMember -Function Rename-Transliterate