ScriptBox
=========

Scripts List
---------
The collection contains the following scripts:

### General purpose
1. Get-UniqueName - Gets an unique name for a file inside a folder. If a file with that name already exists in the folder, the scripts generates a new, unique name by appending (1), (2), etc. to the file name, similar to what Windows Explorer does.

### File/Folder Management
1. Move-ItemRegex - Moves and/or renames an item by using a regular expression, which is matched against its name or path.

### Transliteration
1. Import-TransliterationSchema
2. ConvertTo-TransliteratedString - Transliterates a string, according a user-specified list of rules.
3. Rename-ItemTransliterate - Transliterates the name of a file, according to a user-specified list of rules.


Installation
---------
You can find detailed information on how to install and manage a PowerShell module in this MSDN article:
http://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx

Probably the easiest way to install the module is to place it in your own user-specific Modules directory. This directory is not created by default, so if it does not exist, you have to create it yourself:

1. Go to your Documents folder and create a `WindowsPowerShell` subfolder.
2. Inside `WindowsPowerShell` create a `Modules` folder.
3. Clone the repository inside the `Modules` folder.

You will end up with a structure, that looks like this:

```
$home\Documents\WindowsPowerShell\Modules\ScriptBox
```

Using the Module
---------

In order to use the commands included in the module, you have to import them into your PowerShell session:

```
Import-Module ScriptBox
```

You can also use the shorthand:
```
ipmo ScriptBox
```
