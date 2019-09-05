## LocationStack

  This module is a replacement for PowerShell built-in Push-Location/Pop-Location cmdlets with enhanced functionality:
  - ability to add multiple locations (paths) to the stack ([hashtable]) with custom ID. 
  - ID can be used later to switch dirctly to the target location.
  - ability to quickly switch between last two locations with single command.
  - persistent location table (location record will remain after 'popping' and can be used again).
  - ability to export/import location stack hashtable into/from a file with custom name to maintain multiple stack tables.

### Installation
##### Powershell v.5.0+
1. From PowerShell console run command:<br>
&gt;_ Install-Module -Name LocationStack

##### Powershell v.2.0+
1. Download LocationStack.psm1 file:
https://www.powershellgallery.com/packages/LocationStack/1.0.3/Content/LocationStack.psm1
2. From PowerShell console run command:<br>
&gt;_ Import-Module <download_dir>/LocationStack.psm1

### Notes

  Open-source and free of charge. Feel free to modify.
  I&#39;ve written it for my own use, and it proved very helpful. Hoping that someone else will find it useful.
  Reference to original repo is greatly appreciated.
