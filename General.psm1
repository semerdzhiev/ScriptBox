Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Get-UniqueName
{
	<#
		.SYNOPSIS
			Generates an unique name for an item, that will be stored in a container

		.DESCRIPTION
			Receives the path of a container (e.g. a file to a directory) and the name of an item.
			If there is already another item with the same name in the container,
			the function attempts to generate a new, unique name for the item that you want to add,
			that will not conflict with any other item in the container.
			It does that like Windows Explorer, by appending (1), (2), etc. to the name.

			The function returns a string - a unique name for the item.

		.PARAMETER Name
			Name of the item

		.PARAMETER Directory
			Path of an existing container

		.PARAMETER ExcludeNames
			An array of names that should not be used

		.OUTPUTS
			For each supplied name, the function produces an object with three properties:
			- Name - the generated unique name
			- Destination - the destination container
			- FullName - the full path of the unique name

		.EXAMPLE
			Get-UniqueName "MyFile.txt" C:\Temp

			If there is no file called "MyFile.txt" in C:\Temp, the function
			will preserve the original name. The result will be:

			Name                     Directory                FullName
			----                     -----------              --------
			MyFile.txt               C:\Temp                  C:\Temp\MyFile.txt

			
		.EXAMPLE
			Get-UniqueName "MyFile.txt" C:\Temp

			Let's assume that C:\Temp already contains files called "MyFile.txt",
			"MyFile (1).txt" and "MyFile (5).txt". The function will return
			the first available name, which is "MyFile (2).txt":

			Name                     Directory                FullName
			----                     -----------              --------
			MyFile (2).txt           C:\Temp                  C:\Temp\MyFile (2).txt


		.EXAMPLE
			Get-UniqueName "MyFile.txt" C:\Temp -ExcludeNames "MyFile (2).txt", "MyFile (3).txt"

			If for some reason you do not want the new file to be called
			"MyFile (2).txt" or "MyFile (3).txt", you can tell the function
			not to use those names. Assuming that C:\Temp already contains files
			named "MyFile.txt" and "MyFile (1).txt", the result of this call will be:

			Name                     Destination              FullName
			----                     -----------              --------
			MyFile (4).txt           C:\Temp                  C:\Temp\MyFile (4).txt


		.NOTES
			Author: Atanas Semerdzhiev
	#>


	[CmdletBinding()]

	Param(
		[Parameter(Mandatory=$True,
				   Position=0,
				   ValueFromPipeline=$True,
				   ValueFromPipelineByPropertyName=$True)]
		[string[]]$Name,

		[Parameter(Position=1,
		           ValueFromPipelineByPropertyName=$True)]
		[string]$Directory = ".\",

		[string[]]$ExcludeNames
	)


	Begin
	{
		# Destination must exist and must be a container
		if( -not (Test-Path $Directory -PathType Container) )
		{
			throw "Path $Directory does not exist or is not a container"
		}
	}


	Process {

		foreach($n in $Name)
		{
			# Get the components of the path
		
			$parent    = [System.IO.Path]::GetDirectoryName($n)
			$basename  = [System.IO.Path]::GetFileNameWithoutExtension($n)
			$extension = [System.IO.Path]::GetExtension($n)


			# Generate a new, unique name in the destination container

			$newName = "$basename$extension"
			$newPath = Join-Path $Directory $newName
			$counter = 1

			while( (Test-Path $newPath) -or ($ExcludeNames -contains $newName) )
			{
				$newName = "$basename ($counter)$extension"
				$newPath = Join-Path $Directory $newName
				$counter++
			}

			# return the result as an object
			$result = New-Object PSObject
			$result | Add-Member -MemberType NoteProperty -Name Name        -Value $newName
			$result | Add-Member -MemberType NoteProperty -Name Destination -Value $Directory
			$result | Add-Member -MemberType NoteProperty -Name FullName    -Value (Join-Path (Get-Item $Directory).FullName $newName)

			$result

		} # foreach($p in $Path)

	} # Process

} # function