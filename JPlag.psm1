Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Function Convert-CppProjectsForJPlag {

	<#

	.SYNOPSIS
        Prepares one or more student submitted C++ projects to be analyzed with JPlag

    .DESCRIPTION
        This Cmdlet makes it easier to process student submissions with JPlag.
     
        It performs the following steps:

        1. Fixes the names of the submitted files:
        They are downloaded from Moodle in the following format:
            "FirstName FamilyName_911457_assignsubmission_file_SubmissionName"
        The fixed version is:
            FirstName FamilyName\SubmissionName
        After that, the names are transliterated, using the provided schema.
        This is because JPlag sometimes has problems with files that contain
        non-latin symbols.

        2. Extracts all archives and then removes the archive files

        3. Cleanup temporary IDE files and folders, such as
            Debug, Release, ipch, etc. in Visual Studio.
            Also, clear directories such as __MACOSX.

        4 Convert the encoding of all source files to UTF-8 without BOM

        The extraction of archives is performed using 7-zip.
        Thus, it must be installed, in order for the Cmdlet to be able to do that.
        
        The Cmdlet is developed to support C++ projects developed
        in Visual Studio or Code Blocks.
        
        Although it may be suitable for other scenarios too,
        it is recommended to check the source code to see if it can be used
        in your specific case.

	.PARAMETER ExtractTo
        Specifies what to do with archive files. Can be one of the following:
        
            None - Does not extract archives
            SameFolder - Extracts archives directly into their containing folder
            Subfolder - Extract each archive in its own subfolder

        The subfolder for each archive (if that option is chosen) is the same
        as its basename. E.g. Archive.zip will be extracted to Archive/

	.PARAMETER TransliterationSchema
        Transliteration schema which will be used to fix the names of files.
        Must be a valid schema for ConvertTo-TransliteratedString

	.NOTES
		Author: Atanas Semerdzhiev

	#>

    param(
        [ValidateSet('None', 'SameFolder', 'Subfolder')]
        [string]$ExtractTo = "Subfolder",

        [ValidateNotNullOrEmpty()]
		[String]$TransliterationSchema = "Cyr-Lat.csv"
    )

    Process
    {
        #
        # Step 1: Move each submission to its own subfolder and transliterate its name
        #         If it contains cyrillic letters
        #
        Write-Progress -Activity "Step 1: Fixing Names" -Status "Moving items to subfolders..." -PercentComplete -1
                
        # Remove the moodle ID and the "assignsubmission" text from the names of folders
        # Folder names look like this: "FirstName FamilyName_911457_assignsubmission_file_"
        Move-ItemRegex * -ItemNameRegEx "^(.+)_\d{6,7}_assign" -newn "{1}"

        Write-Progress -Activity "Step 1: Fixing Names" -Status "Transliterating names..." -PercentComplete -1

        # Transliterate folder names
        Rename-Transliterate * -SchemaPath "$TransliterationSchema"



        #
        # Step 2: Extract all archive files using 7-zip
        #
        if($ExtractTo -ne 'None')
        {
            # Extract all archives and delete files
            $archives = Get-ChildItem *.zip,*.rar,*.7z,*.gz,*.tgz -File -Recurse

            if($archives)
            {

                # No progress indicator is printed here.
                # The reason is that 7-zip does not have a silent mode,
                # which outputs only the prompts.
    
                foreach($a in $archives)
                {
  
                    # Determine the output folder
                    $outputFolder = $a.DirectoryName
                    
                    if($ExtractTo -eq 'Subfolder')
                    {
                        # Trim the basename, because it may end with a space character,
                        # e.g. a file can have the following name: "test  .zip"
                        $trimmedBasename = $a.BaseName.Trim()
    
                        $outputFolder = $outputFolder + "\$trimmedBasename"
                    }
                    
                    # extract the files using 7-zip
                    & "C:\Program Files\7-Zip\7z.exe" x -bb0 -o"$outputFolder" "$($a.FullName)"
                    
                    # remove the archive
                    Remove-Item "$($a.FullName)"
                }
            }
        }



        #
        # Step 3: Cleanup temporary IDE files and folders
        #
        Write-Progress -Activity "Step 3: Cleaning temporary IDE items" -Status "Cleaning folders..." -PercentComplete -1
        
        # Delete temporary IDE folders
        Get-ChildItem . -Include Debug,Release,ipch,.vs,__MACOSX,bin,obj -Directory -Recurse -Force | Remove-Item -Recurse -Force

        Write-Progress -Activity "Step 3: Cleaning temporary IDE items" -Status "Cleaning files..." -PercentComplete -1

        # Delete temporary IDE files
        Get-ChildItem . -Include *.sln,*.sdf,*.suo,*.db -File -Recurse -Force | Remove-Item -Force



        #
        # Step 4: Convert the encoding of all source files to UTF-8 without BOM
        #
        
        $sourceFiles = Get-ChildItem -Include *.cpp,*.c,*.cc,*.h,*.hpp -File -Recurse

        $statusParameters = @{
            'Activity' = "Step 4: Convert file encodings to UTF-8 without BOM";
            'Status'   = "Processing $($sourceFiles.length) source files(s)..." 
        }
        
        $i = 0                

        foreach($f in $sourceFiles)
        {
            ++$i

            Write-Progress @statusParameters -CurrentOperation "$f" -PercentComplete (($i / $sourceFiles.length) * 100)            
            
            $content = Get-Content $f
    
            if($content)
            {
                #
                # The script is not using Out-File here (as shown below),
                # because it writes UTF-8 files with BOM, which breaks JPlag:
                #
                # Out-File $f -Encoding UTF8 -InputObject $content
                #
                # For more information see the following discussion
                # on stackoverflow:
                # https://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom#comment9867553_5596984
                #
                [System.IO.File]::WriteAllLines($f.FullName, $content)
            }
        }

    } # Process
} # Function