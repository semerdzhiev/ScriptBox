Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

<#
	.SYNOPSIS
		Calculates hashes for all files in a directory and saves them to a file

	.DESCRIPTION
		The cmdlet uses Get-FileHash to calculate the hash for a given file.
		
		Each line in the output file will be in the following format:
		<hash> *<path>
		where <hash> is the hash calculated for the file <file>.
		
		The format of the file is that used by the Xsum family of programs in Linux
		(e.g. md5sum, sha512sum, etc.)
		
	.PARAMETER Path
		Directory to scan
		
	.PARAMETER Algorithm
		Algorithm, which will be used to hash the contents of a file.
		Can be one of the valid algoroithms for the Get-FileHash cmdlet.
		
	.PARAMETER OutputFile
		The file, in which to store the hashes.
		If you pass the empty string for this parameter, a default name
		will be used, which is in the form "<path>-<date>-<time>.<algorithm>".
		The new name will be unique and will not conflict with an existing file.
		If necessary, a number, such as (1) will be appended to its basename.
		
	.PARAMETER IfOutputFileExists
		Specifies what to do if OutputFile already exists. Can be one of:
		- Unique - create a new, unique filename and do not modify the existing file;
		- Append - add the information to the end of the existing file;
		- Overwrite - overwrite the existing contents of the file.
		
	.PARAMETER PrependDirectory
		Specifies that the basename of the input directory should be prepended to
		the file paths in the output file. For example, if we scan a directory
		C:\Temp\Test, which contains items A and B, with hashes Ha and Hb,
		with this switch, the output file will look like this:
		Ha *Test\A
		Hb *Test\B
		without the switch, the file will look like this:
		Ha *A
		Hb *B
		This switch has no effect, if the directory you are scanning is a root directory
		on a given volume. For example in the following command, the switch will have
		no effect:
		Export-DirectoryItemHashes D:\ -PrependDirectory
		
	.EXAMPLE
		Export-DirectoryItemHashes "C:\Temp\My Folder"
		
		Assuming that we run the script from C:\Temp, at 12:00 on 2017-12-17,
		the cmdlet will create a file called  "My Folder-2017-12-17-1200.sha512" and
		store the hashes in it. If such a file already exists, a new, unique name will
		be used, like "My Folder-2017-12-17-1200 (1).sha512".
		
	.EXAMPLE
		Export-DirectoryItemHashes "C:\Temp\My Folder" -Algorithm md5 -OutputFile test.md5 -IfOutputFileExists Overwrite
		
		Will calculate MD5 hashes for all files under C:\Temp\My Folder and store
		the results in a file called test.md5. If the file already exists, the
		data will be appended to it.		
		
	.NOTES
		Author: Atanas Semerdzhiev
		URL: http://github.com/semerdzhiev/ScriptBox
#>
Function Export-DirectoryItemHashes
{
	[CmdletBinding()]

	Param(
		[parameter(mandatory=$true,
				   HelpMessage="Enter the path of the directory to scan.")]
        [ValidateNotNullOrEmpty()]
		[string]$Path,
		
		[ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
		[string]$Algorithm = 'SHA512',
		
		[string]$OutputFile = '',
		
		[ValidateSet('Unique', 'Append', 'Overwrite')]
		[string]$IfOutputFileExists = 'Unique',
		
		[switch]$PrependDirectory
	)
	
	Process {
	
		# Get information about the input directory
		$inputDir = Get-Item $Path
		
		# Determine whether the input dir is the root of a volume
		$isRootDir = $inputDir.FullName -Eq $inputDir.BaseName
		
		# If no name is specified for the output file, generate an unique one
		if(-Not $OutputFile)
		{
			$prefix = if($isRootDir) { $inputDir.PSDrive } else { $inputDir.Name }
			$OutputFile = (Get-UniqueName "$prefix-$(Get-Date -Format yyy-MM-dd-hhmm).$($Algorithm.ToLower())").FullName
			$IfOutputFileExists = 'Unique'
		}
	
		# If a name for the output file has been specified, check to see
		# whether it exists and is a folder
		ElseIf( (Test-Path $OutputFile -PathType Container) )
		{
			Throw "$OutputFile already exists and it is a container!"
		}
		
		# If the output file already exists and the user requires is to truncate it,
		# or if we need to create a new, unique file, do so
		ElseIf(-Not ($IfOutputFileExists -Eq 'Append'))
		{
			If($IfOutputFileExists -Eq 'Unique')
			{
				$OutputFile = (Get-UniqueName $OutputFile).FullName
			}
			
			# Creates a new file $OutputFile, or truncates it, if it exists
			New-Item -ItemType File -Path "$OutputFile" -Force | Out-Null
		}




		# Scan the target folder and retrieve its contents
		Write-Progress -Activity "Exporting Hashes" -Status "Scanning folder contents (this may take several minutes)" -PercentComplete -1
		
		$allItems = Get-ChildItem -LiteralPath "$Path" -Recurse -Name -File -Force
		


		
		# Process all items and export the results to the file
		$i = 0
		
		$statusParameters = @{
			'Activity' = 'Exporting Hashes';
			'Status'   = "Processing items ($($allItems.length) found)" 
		}


		# Determine whether to use a prefix when writing paths to the file or not
		# This should be done if the user requires it (-PrependDirectory), but only
		# when the target directory is not the root of a drive.
		$pathPrefix = ''
		
		if($PrependDirectory -And (-Not $isRootDir))
		{
			$pathPrefix = "$((Get-Item $Path).Basename)/"
		}
		
	
		# Process each item and output its hash to the file
		foreach($f in $allItems)
		{
			$i++
			
			Write-Progress @statusParameters -CurrentOperation "$f" -PercentComplete (($i / $allItems.length) * 100)
			
			$hash = Get-FileHash -LiteralPath "$Path\$f" -Algorithm $Algorithm
			
			"$($hash.Hash)`t*$pathPrefix$($f.Replace('\','/'))`n" | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8 -NoNewLine
		}
	}
}

