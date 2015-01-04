Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Import-TransliterationSchema
{
	<#
		.SYNOPSIS
			Loads a transliteration schema from a CSV file

		.DESCRIPTION
			The transliteration schema is stored as a CSV file.
			The first line of the file should be "Search, Replace"
			The next lines should contain pairs in the form of:
				<search>, <replace>
			When transliterating a string, every occurrence of
			<search> in it is replaced with <replace>.

		.PARAMETER Path
			Path of the CSV file containing the transliteration rules.
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
		[string]$Path,

		[string]$CsvDelimiter = ",",

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



Function Print-TransliterationSchema
{
	param($Object, $Tabs)

	Begin
	{
		foreach($key in $Object.Keys)
		{
			if(($Object[$key] -is [string]) -or ($Object[$key] -is [char]))
			{
				Write-Output "$Tabs[$key] -> ""$($Object[$key])"""
			}
			else
			{
				Write-Output "$Tabs[$key] ->"
				Print-Schema $Object[$key] "$Tabs`t"
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
			The function transliterates a string basedon a schema.
			The schema must be an object returned by Import-TransliterationSchema

		.PARAMETER String
			The text to be transliterated

		.PARAMETER Schema
			The transliteration schema to use.
			Must be an object returned by a call to Import-TransliterationSchema

		.OUTPUTS
			The transliterated string

		.LINK
			Import-TransliterationSchema

		.NOTES
			Author: Atanas Semerdzhiev

	#>

	[CmdletBinding()]

	Param(
		[Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$True)]
		[AllowEmptyString()]
		[string[]]$String,

		[Parameter(Mandatory=$True, Position=1)]
		$Schema
	)

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

				$currentLevel = $Schema # Start search from the top of the prefix tree

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
			Rename-Transliterate абв.txt (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			Transliterate a specific file

		.EXAMPLE
			Rename-Transliterate абв.txt,абв.doc,абвгд.txt (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			Transliterate several files

		.EXAMPLE
			Rename-Transliterate *.txt (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			This will result in an error - you have to pass specific filenames
			to the script and cannot use wildcards

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			To generate a list of items to transliterate, you can use Get-ChildItem.
			This example transliterate all files and subdirectories in the current directory

		.EXAMPLE
			Get-ChildItem * -Include *.cpp,*.c | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			Transliterate only .cpp and .c files in the current directory

		.EXAMPLE
			Get-ChildItem * -Attribute !Directory | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			Transliterate all files, but do not transliterate directories

		.EXAMPLE
			Get-ChildItem * -Attribute Directory | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv)
			Transliterate only directories

		.EXAMPLE
			Get-ChildItem * -Recurse | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv) -WhatIf
			Transliterate the names of all items in the current directory and
			in its subdirectories.

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv) -WhatIf
			Test what the script will do, if we try to transliterate all the files
			in the current directory, but do not actually perform the actions

		.EXAMPLE
			Get-ChildItem * | Rename-Transliterate (Import-TransliterationSchema Transliterate-Cyr-Lat.csv) -Confirm
			Run in interactive mode - you will have to confirm or reject
			the transliteration for each file/directory

		.LINK
			Import-TransliterationSchema

		.NOTES
			Author: Atanas Semerdzhiev

	#>


	[CmdletBinding(SupportsShouldProcess = $True)]

	Param(
		[Parameter(Mandatory=$True,				   
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True)]
		[Alias('FullName')]
		[string[]]$Path,

		[Parameter(Mandatory=$True)]
		$Schema
	)


	Begin
	{
		# Create an array to store the items that will be transliterated by the script
		# This array supports the functionality of the -WhatIf switch and
		# is only filled and used when this switch is supplied
		[string[]] $transliteratedItems = @()
	}


	Process {

		foreach($p in $Path)
		{
			# See if item exists
			if( -not (Test-Path $Path) )
			{
				Write-Error "Path $Path does not exist."
			}

			
			# Retrieve item information
			$fileInfo = Get-Item $p


			# Transliterate the basename
			Write-Debug $fileInfo.Basename
			$transliteratedBasename = ConvertTo-TransliteratedString -String $fileInfo.Basename -Schema $Schema
		
			
			# Process the item only if transliteration has produced a different basename
			if($transliteratedBasename -ne $fileInfo.BaseName)
			{
				# As the results of the transliteration may conflict with the name of an already existing
				# item in the target container, generate an unique name for the new file
				$unique = Get-UniqueName -Name "$transliteratedBasename$($fileInfo.Extension)" -Destination $fileInfo.PSParentPath -ExcludeNames $transliteratedItems


				# If we are running with the -WhatIf switch, add the new name
				# to the list of transliterated items
				if($WhatIfPreference)
				{
					$transliteratedNames += $unique.Name
				}


				# Now the new name is unique and we can process it
				if($PSCmdlet.ShouldProcess("$($fileInfo.FullName) --> $($unique.Name)", "Transliterate"))
				{
					# The -Confirm switch is necessary, otherwise Rename-Item "inherits" it from our script
					Rename-Item -Path $fileInfo.FullName -NewName $unique.Name -Confirm:$false
				}
			}
			else
			{
				# Transliteration does not change the basename, so there is nothing to do
				Write-Verbose "Skipping $($fileInfo.FullName)"
			}

		} # foreach($p in $Path)

	} # Process
 
 } # Function

 # Export-ModuleMember -Function Rename-Transliterate