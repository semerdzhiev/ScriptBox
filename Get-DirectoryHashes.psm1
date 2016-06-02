Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Function Get-DirectoryHashes
{
	[CmdletBinding()]

	Param(
		[parameter(mandatory=$true,
                   HelpMessage="Enter the path of the directory to scan.")]
        [ValidateNotNullOrEmpty()]
		[String]
		$Path
	)
	
	Process {
	
		$currentLocation = Get-Location

		Set-Location $Path

		Get-ChildItem * -Recurse |
			Get-FileHash |
			Select Algorithm,
				   Hash,
				   @{Name='Path';Expression={Resolve-Path -Relative -LiteralPath $_.Path}} |
			Export-Csv "$currentLocation\hashes-$(Get-Date -Format yyy-MM-dd-hhmmss).csv" -Encoding UTF8 -NoTypeInformation -Delimiter ';'
			
		Set-Location $currentLocation
	
	}
}

