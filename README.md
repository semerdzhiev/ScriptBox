ScriptBox
=========

A collection of useful PowerShell scripts.


Scripts List
---------
The collection contains the following scripts:

###General Purpose
1. Get-UniqueName

###Transliteration
1. Move-ItemByRegex

###Transliteration
1. Import-TransliterationSchema
2. ConvertTo-TransliteratedString
3. Rename-ItemTransliterate


Installation
---------
You can find detailed information on how to install and manage a PowerShell module in this MSDN article:
http://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx

Probably the easiest way to install the module is to place it in your own user-specific Modules directory. This directory is not created by default, so if it does not exist, you will have to create it yourself. Just go to your Documents folder and create a "WindowsPowerShell" subfolder. Inside WindowsPowerShell create a "Modules" folder. After that you can clone the repository inside Modules folder. You will end up with a structure, that looks like this:

```
$home\Documents\WindowsPowerShell\Modules\ScriptBox
```

Using the Module
---------

In order to use the commands included in the module, you have to import them first. You can do that at any time in yur current PowerShell session, by typing:

```
Import-Module ScriptBox
```

or by using the shorthand:

```
ipmo ScriptBox
```
