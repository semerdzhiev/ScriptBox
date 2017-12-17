Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Export-DirectoryItemHashes
{
	[CmdletBinding()]

	Param(
		[parameter(mandatory=$true,
				   HelpMessage="Enter the path of the directory to scan.")]
        [ValidateNotNullOrEmpty()]
		[String]
		$Path,
		
		[ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
		[string]$Algorithm = 'SHA512',
		
		[string]$OutputFile = '',
		
		[switch]$Append
	)
	
	Process {
	
		# If no name is specified for the output file, generate an unique one
		if(-Not $OutputFile)
		{
			$OutputFile = (Get-UniqueName "$((Get-Item $Path).Name)-$(Get-Date -Format yyy-MM-dd-hhmm).$($Algorithm.ToLower())").FullName
		}
	
		# If a name for the output file has been specified, check to see
		# whether it exists and is a folder
		ElseIf( (Test-Path $OutputFile -PathType Container) )
		{
			Throw "$OutputFile already exists and it is a container!"
		}
		
		# Check if the output file already exists and the user requires is to truncate it
		ElseIf( (Test-Path $OutputFile -PathType Leaf) -And (-Not $Append) )
		{
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
	
		#TODO Replace the Out-File cmdlet with calls to System.IO.StreamWriter.WriteLine and see if it is faster
		# $stream = New-Object -TypeName "System.IO.StreamWriter" -ArgumentList "$OutputFile",[System.Text.Encoding]::UTF8
		
		# Process each item
		foreach($f in $allItems)
		{
			$i++
			Write-Progress @statusParameters -CurrentOperation "$f" -PercentComplete (($i / $allItems.length) * 100)
			
			$hash = Get-FileHash -LiteralPath "$Path\$f" -Algorithm $Algorithm
			
			"$($hash.Hash)`t*$f" | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8
			
			# $stream.WriteLine("$($hash.Hash)`t*$f")
		}
		
		#$stream.Close()
		#$stream.Dispose()
	
		#$currentLocation = Get-Location

		#Set-Location $Path

		#Get-ChildItem * -Recurse |
		#	Get-FileHash |
		#	Select Algorithm,
		#		   Hash,
		#		   @{Name='Path';Expression={Resolve-Path -Relative -LiteralPath $_.Path}} |
		#	Export-Csv "$currentLocation\hashes-$(Get-Date -Format yyy-MM-dd-hhmmss).csv" -Encoding UTF8 -NoTypeInformation -Delimiter ';'
			
		#Set-Location $currentLocation
	}
}

