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
            Write-Warning "Location ID '$id' exists with following path: '$($Global:LocationStack.$id)'."
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

function Show-Locations ($name, $location) { # this has iisue when run with no added locations
    if (!$Global:LocationStack) {
        $Global:LocationStack = @{}
        $Global:LocationStack.last = $PWD.Path
    }

    $showHash = @{}

    if (!$name -and !$location) {
        $showHash = $Global:LocationStack.Clone()
    }

    if ($name) {
        if ($name -match '\W') {
            throw "Invalid ID name: '$name'."
        } else {
            $keys = @()
            if ($name -is [array]) {
                $name | %{
                    if ($_ -in $Global:LocationStack.Keys) {
                        $keys += $name
                    }
                }
            } else {
                if ($name -in $Global:LocationStack.Keys) {
                    $keys += $name
                }
            }
        }

        $keys | %{$showHash.$_ = $Global:LocationStack.$_}
    }
    
    if ($location) {
        if ($location -in $Global:LocationStack.Values) {
            $name = $Global:LocationStack.GetEnumerator().name | ?{$Global:LocationStack.$_ -eq $location}
            $showHash.$name = $location
        }
    }

    return $showHash
}

function Switch-Location ($name, $location) {
    if (!$Global:LocationStack) {
        $Global:LocationStack = @{}
        $Global:LocationStack.last = $PWD.Path
    }

    if ($name) {
        if (!$location) {
            if ($name -in $Global:LocationStack.Keys) {
                $location = $Global:LocationStack.$name
            } else {
                throw "Location ID '$name' not found."
            }
        }
    } else {
        if (!$location) {
            $location = $Global:LocationStack.last
        }
    }

    $Global:LocationStack.last = $PWD.Path
    cd $location
}

function Open-Location ($name, $location) {
    if (!$Global:LocationStack) {
        $Global:LocationStack = @{}
        $Global:LocationStack.last = $PWD.Path
    }

    $openHash = @{}

    if (!$name -and !$location) {
        $openHash = $Global:LocationStack.Clone()
    }

    if ($name) {
        if ($name -match '\W') {
            throw "Invalid ID name: '$name'."
        } else {
            $keys = @()
            if ($name -is [array]) {
                $name | %{
                    if ($_ -in $Global:LocationStack.Keys) {
                        $keys += $name
                    }
                }
            } else {
                if ($name -in $Global:LocationStack.Keys) {
                    $keys += $name
                }
            }
        }

        $keys | %{$openHash.$_ = $Global:LocationStack.$_}
    }

    if ($location) {
        if ($location -in $Global:LocationStack.Values) {
            $name = $Global:LocationStack.GetEnumerator().name | ?{$Global:LocationStack.$_ -eq $location}
            $openHash.$name = $location
        }
    }

    $openedLocations = @()
    $openHash.Keys | %{
        if ($openHash.$_ -notin $openedLocations) {
            explorer $openHash.$_
            $openedLocations += $openHash.$_
        }
    }
    Remove-Variable openedLocations
}

function Remove-Location ($name, $location) {
    
    if ($Global:LocationStack) {
        
        $showHash = @{}

        if (!$name -and !$location) {
            $showHash = $Global:LocationStack.Clone()
        }

        if ($name) {
            if ($name -match '\W') {
                throw "Invalid ID name: '$name'."
            } else {
                $keys = @()
                if ($name -is [array]) {
                    $name | %{
                        if ($_ -in $Global:LocationStack.Keys) {
                            $keys += $name
                        }
                    }
                } else {
                    if ($name -in $Global:LocationStack.Keys) {
                        $keys += $name
                    }
                }
                
                if (!$keys -and !$location) {
                    throw ("Location ID '" + ($name -join(',')) + "' not found.")
                }
            }

            $keys | %{$showHash.$_ = $Global:LocationStack.$_}
        }
    
        if ($location) {
            if ($location -in $Global:LocationStack.Values) {
                $name = $Global:LocationStack.GetEnumerator().name | ?{$Global:LocationStack.$_ -eq $location}
                $showHash.$name = $location
            } else {
                if (!$name) {
                    throw ("Path '$location' not found.")
                }
            }
        }

        if ($showHash.count -gt 0) {
            $showHash.GetEnumerator().name | %{$Global:LocationStack.Remove($_)}
        }
    }
}

function Clear-Locations ([switch]$all) {
    Remove-Variable Locations -Scope Global -ErrorAction SilentlyContinue
}

function Save-Locations ($name, [switch]$force) {

    if ($Global:LocationStack) {
        $dataDir = Join-Path (Split-Path $PROFILE) 'data'
        mkdir $dataDir -ErrorAction SilentlyContinue | Out-Null

        if (!$name) {
            $name = 'locstack.json'
        } elseif ($name -ne 'default') {
            $name = "locstack_$name`.json"
        } else {
            Write-Host " (!) Name can not be 'default'"
        }

        $filepath = Join-Path $dataDir $name

        try {
            if ($force) {
                $Global:LocationStack | ConvertTo-Json | Out-File $filepath -Force -ErrorAction Stop
            } else {
                $Global:LocationStack | ConvertTo-Json | Out-File $filepath -NoClobber -ErrorAction Stop
            }
            Write-Host "Saved at: '$filepath'"
        } catch {
            throw $_
        }
    } else {
        Write-Host ' (!) Nothing to save'
    }
}

function Load-Locations ($name, [switch]$force) {

    if ($force) {
        if ($Global:LocationStack) {
            $Global:LocationStack.Clear()
        } else {
            $Global:LocationStack = @{}
        }

        $dataDir = Join-Path (Split-Path $PROFILE) 'data'

        if (!$name) {
            $name = 'locstack.json'
        } else {
            $name = "locstack_$name`.json"
        }

        $filepath = Join-Path $dataDir $name
    
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

    $dataDir = Join-Path (Split-Path $PROFILE) 'data'

    $stacks = (ls $dataDir -Filter 'locstack*.json' -ErrorAction SilentlyContinue).BaseName

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

Set-Alias -Name al -Value Add-Location
Set-Alias -Name sw -Value Switch-Location
Set-Alias -Name shl -Value Show-Location
Set-Alias -Name ol -Value Open-Location
Set-Alias -Name rl -Value Remove-Location
Set-Alias -Name cl -Value Clear-Locations
Set-Alias -Name svl -Value Save-Locations
Set-Alias -Name ll -Value Load-Locations
Set-Alias -Name lsl -Value List-SavedLocations

Export-ModuleMember -Function * -Alias *
