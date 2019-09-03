### LOCATION STACK

function Add-LocationToStack {
<#
.SYNOPSIS
Adds path to the location stack
.DESCRIPTION
Adds a directory path specified by <-location> parameter to $LocationStack hashtable, with key defined by <-id> parameter.
If path is not specified, current directory path is used.
If path or id is already present in $LocationStack, use <-force> to overwrite
#>

    param (
        [string]$id = $(throw 'Mandatory parameter not provided: <id>.'),
        [string]$location = $PWD.Path,
        [switch]$force
    )

    $ErrorActionPreference = 'Stop'
    $location = (Resolve-Path $location).Path.TrimEnd('\/')

    if (!$Global:LocationStack) {
        $Global:LocationStack = @{ }
    }

    if ($id -match '\W') {
        throw "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_])"
    }

    if ($id -in $Global:LocationStack.Keys) {

        if (!$force) {
            Write-Warning "LocationStack ID '$id' exists with following path: '$($Global:LocationStack.$id)'."
            Write-Warning "Use <-force> to overwrite."
            break
        }
    }

    if ($location -in $Global:LocationStack.Values) {

        $existing_location_id = ($Global:LocationStack.GetEnumerator() | ? { $_.value -eq $location }).key

        if (!$force) {
            Write-Warning "Location '$location' exists with following ID: '$existing_location_id'."
            Write-Warning "Use <-force> to overwrite."
            break              
        }
    }

    if ($existing_location_id) {
        $Global:LocationStack.Remove($existing_location_id)
    }

    $Global:LocationStack.$id = $location
}

function Remove-LocationFromStack {
<#
.SYNOPSIS
Removes path from the location stack
.DESCRIPTION
Removes an entry from $LocationStack hashtable, with key defined by <-id> parameter.
Use <-force> to confirm your intent to delete.
#>

    param (
        [string]$id = $(throw 'Mandatory parameter not provided: <id>.'),
        [switch]$force
    )

    $ErrorActionPreference = 'Stop'

    if (!$Global:LocationStack -or ($Global:LocationStack.Count -eq 0)) {
        Write-Warning "Location Stack is currently empty."
        break
    }

    if ($id -match '\W') {
        throw "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_])"
    }

    if ($id -notin $Global:LocationStack.Keys) {
        Write-Warning "Location ID '$id' not found in the Location Stack."
        break
    }

    if (!$force) {
        Write-Warning "Found '$id' : '$($Global:LocationStack.$id)'."
        Write-Warning "To delete, re-run with <-force>."
        break
    }

    $location = $Global:LocationStack.$id
    $Global:LocationStack.Remove($id)
    Write-Host "Removed '$id' : '$location'"
}

function Show-LocationStack {
<#
.SYNOPSIS
Lists paths in the location stack.
.DESCRIPTION
Returns $LocationStack hashtable.
Use <-ids>(array) and <-locations>(array) to filter returned results (both accept wildcard '*').
#>

    param (
        [string[]]$ids,
        [string[]]$locations
    )

    $ErrorActionPreference = 'Stop'

    if (!$Global:LocationStack -or ($Global:LocationStack.Count -eq 0)) {
        Write-Warning "Location Stack is currently empty."
        break
    }

    $show_hash = @{}

    if ($ids) {

        foreach ($id in $ids) {
            
            if ($id -match '[^a-zA-Z0-9_\*]') {
                Write-Warning "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_] + wildcard '*')"
            }

            $keys = @($Global:LocationStack.Keys.GetEnumerator() | ?{$_ -like $id})
            $keys | %{$show_hash.$_ = $Global:LocationStack.$_}
        }
    }

    if ($locations) {

        $values = @()

        foreach ($location in $locations) {

            $Global:LocationStack.Values.GetEnumerator() |
            ? {$_ -like $location} |
            % {$values += $_}
        }

        $Global:LocationStack.Keys.GetEnumerator() | %{

            if ($Global:LocationStack.$_ -in $values) {
                $show_hash.$_ = $Global:LocationStack.$_
            }
        }
    }

    if (!$id -and !$location) {
        $show_hash = $Global:LocationStack.Clone()
    }
    
    return $show_hash
}

function Switch-Location {
<#
.SYNOPSIS
Changes current directory to the path in the location stack
.DESCRIPTION
If <-id> is specified, uses path with that ID in $LocationStack hashtable.
If <-location> is specified, changes to that location if it can be resolved.
Before changing location, current directory path is recorded in $LocationStack hashtable under 'last' key.
If no parameters specified, changes location to the path defined by 'last' key in $LocationStack hashtable.
#>

    param (
        [string]$id,
        [string]$location
    )

    $ErrorActionPreference = 'Stop'

    if ($id -and $location) {
        throw "Both <-id> and <-location> cannot be used simultaneously."
    }

    if (!$Global:LocationStack) {
        $Global:LocationStack = @{ }
    }

    if ($id) {

        if ($id -match '\W') {
            throw "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_])"
        }

        if ($id -in $Global:LocationStack.Keys) {
            $location = $Global:LocationStack.$id
        }
        else {
            throw "Location ID '$id' not found in the Location Stack."
        }
    }

    if (!$location) {
        $location = $Global:LocationStack.last
    }

    if ($location) {

        $location = (Resolve-Path $location).Path
        $Global:LocationStack.last = $PWD.Path
        cd $location
    }
}

function Open-LocationInExplorer {
<#
.SYNOPSIS
Opens path(s) from the location stack in Windows Explorer.
.DESCRIPTION
Use <-ids>(array) and <-locations>(array) to filter paths to open (both accept wildcard '*').
#>

    param (
        [string[]]$ids,
        [string[]]$locations
    )

    $ErrorActionPreference = 'Stop'

    if (!$Global:LocationStack -or ($Global:LocationStack.Count -eq 0)) {
        Write-Warning "Location Stack is currently empty."
        break
    }

    $locations_to_open = @()

    if ($ids) {

        foreach ($id in $ids) {

            if ($id -match '[^a-zA-Z0-9_\*]') {
                Write-Warning "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_] + wildcard '*')"
            }

            $keys = @($Global:LocationStack.Keys.GetEnumerator() | ?{$_ -like $id})
            $keys | %{$locations_to_open += $Global:LocationStack.$_}                
        }
    }

    if ($locations) {

        foreach ($location in $locations) {

            $Global:LocationStack.Values.GetEnumerator() |
            ? {$_ -like $location} |
            % {$locations_to_open += $_}
        }
    }

    if (!$ids -and !$locations) {
        $Global:LocationStack.Values.GetEnumerator() |
        % {$locations_to_open += $_}
    }

    $opened_locations = @()

    foreach ($path in $locations_to_open) {

        if ($path -notin $opened_locations) {

            explorer "$path"
            $opened_locations += $path
        }
    }
}

function Clear-LocationStack {
<#
.SYNOPSIS
Clears location stack.
.DESCRIPTION
Removes all entries from $LocationStack hashtable except the one with 'last' key.
Use <-force> to delete $LocationStack hashtable completely.
#>

    param (
        [switch]$force
    )

    $ErrorActionPreference = 'Stop'

    if ($force) {
        Get-Variable LocationStack -Scope Global -ErrorAction SilentlyContinue | rm
    }
    else {

        if (!$Global:LocationStack) {
            break
        }

        $keys_to_delete = @()

        foreach ($key in $Global:LocationStack.Keys.GetEnumerator()) {
            
            if ($key -ne 'last') {
                $keys_to_delete += $key
            }
        }

        $keys_to_delete | % {$Global:LocationStack.Remove($_)}
    }
}

function Save-LocationStack {
<#
.SYNOPSIS
Saves location stack to a file.
.DESCRIPTION
If <-name> is not specified, location stack is saved as 'default'.
If location stack with provided name already exists, use <-force> to overwrite.
#>

    param (
        [string]$name,
        [switch]$force
    )

    $ErrorActionPreference = 'Stop'

    if (!$Global:LocationStack -or ($Global:LocationStack.Count -eq 0)) {
        Write-Warning "Location Stack is currently empty."
        break
    }

    $save_directory = Join-Path (Split-Path $PROFILE) 'data'
    mkdir $save_directory -ErrorAction SilentlyContinue | Out-Null
    if (!$name) {$name = 'default'}
    $filepath = Join-Path $save_directory "locstack_$name`.json"

    if (Test-Path $filepath) {
        
        if (!$force) {

            Write-Warning "LocationStack '$name' exists on disk."
            Write-Warning "Use <-force> to overwrite."
            break
        }
    }

    $Global:LocationStack | ConvertTo-Json | Out-File $filepath -Force -ErrorAction Stop
}

function Open-LocationStack {
<#
.SYNOPSIS
Loads location stack from a file.
.DESCRIPTION
If <-name> is not specified, 'default' stack is loaded.
Parameter <-force> is required to avoid accidental replacement of current stack.
#>

    param (
        [string]$name,
        [switch]$force
    )

    $ErrorActionPreference = 'Stop'

    if (!$force) {

        Write-Warning "(!) Re-run with '-Force' parameter to open location stack from file."
        break
    }

    $save_directory = Join-Path (Split-Path $PROFILE) 'data'
    if (!$name) {$name = 'default'}
    $filepath = Join-Path $save_directory "locstack_$name`.json"

    if (!(Test-Path $filepath)) {
        throw "LocationStack '$name' not found on disk. Use Get-LocationStack to list available stacks."
    }

    $load_hash = @{}

    (cat $filepath -ErrorAction Stop | ConvertFrom-Json).psobject.properties |
    %{ $load_hash[$_.Name] = $_.Value }

    $Global:LocationStack = $load_hash.Clone()
    Remove-Variable load_hash -force
}

function Get-LocationStack {
<#
.SYNOPSIS
Lists saved location stacks.
.DESCRIPTION
Use <-name>(array) to filter listed stacks (accepts wildcard '*')
#>

    param (
        [string[]]$names = @('*')
    )

    $save_directory = Join-Path (Split-Path $PROFILE) 'data'
    $stacks_list = @()

    foreach ($name in $names) {

        $filter = "locstack_$name`.json"
        $stacks_on_disk = (ls $save_directory -Filter $filter -ErrorAction SilentlyContinue).BaseName

        $stacks_on_disk | %{

            if ($_ -notin $stacks_list) {
                $stacks_list += $_
            }
        }
    }

    if ($stacks_list) {

        $stacks_list | % {
            
            if ($_) {               
                Write-Host $_.replace('locstack_','')
            }
        }
    }
}

Set-Alias -Name als -Value Add-LocationToStack
Set-Alias -Name rls -Value Remove-LocationFromStack
Set-Alias -Name shls -Value Show-LocationStack
Set-Alias -Name sl -Value Switch-Location
Set-Alias -Name ole -Value Open-LocationInExplorer
Set-Alias -Name clrs -Value Clear-LocationStack
Set-Alias -Name svls -Value Save-LocationStack
Set-Alias -Name ols -Value Open-LocationStack
Set-Alias -Name gls -Value Get-LocationStack

Export-ModuleMember -Function * -Alias *
