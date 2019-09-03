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

    $showHash = @{}

    if ($ids) {

        foreach ($id in $ids) {
            
            if ($id -match '[^a-zA-Z0-9_\*]') {
                Write-Warning "Invalid ID: '$id' (allowed characters: [a-zA-Z0-9_] + wildcard '*')"
            }

            $keys = @($Global:LocationStack.Keys.GetEnumerator() | ?{$_ -like $id})
            $keys | %{$showHash.$_ = $Global:LocationStack.$_}            
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
                $showHash.$_ = $Global:LocationStack.$_
            }
        }
    }

    if (!$id -and !$location) {
        $showHash = $Global:LocationStack.Clone()
    }
    
    return $showHash
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

function Open-LocationInExplorer ($name, $location) {
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

function Clear-LocationStack ([switch]$all) {
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
If location stack with provided name already exists, use <-force> to confirm your intent to overwrite.
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



#(ps) current progress

function Load-Locations ($name, [switch]$force) {

    if ($force) {
        if ($Global:LocationStack) {
            $Global:LocationStack.Clear()
        } else {
            $Global:LocationStack = @{}
        }

        $save_directory = Join-Path (Split-Path $PROFILE) 'data'

        if (!$name) {
            $name = 'locstack.json'
        } else {
            $name = "locstack_$name`.json"
        }

        $filepath = Join-Path $save_directory $name
    
        if (Test-Path $filepath) {
            (cat $filepath -ErrorAction Stop | ConvertFrom-Json).psobject.properties | %{ $Global:LocationStack[$_.Name] = $_.Value }
        } else {
            Write-Host " (!) File not found: '$filepath'"
        }
    } else {
        Write-Host " (!) Re-run with '-Force' parameter to load location stack"
    }
}

function List-SavedLocations {

    $save_directory = Join-Path (Split-Path $PROFILE) 'data'

    $stacks = (ls $save_directory -Filter 'locstack*.json' -ErrorAction SilentlyContinue).BaseName

    if ($stacks) {
        foreach ($stack in $stacks) {
            if ($stack -eq 'locstack') {
                Write-Host 'default'
            } else {
                Write-Host $stack.replace('locstack_','')
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

Set-Alias -Name ll -Value Load-Locations
Set-Alias -Name lsl -Value List-SavedLocations

Export-ModuleMember -Function * -Alias *
