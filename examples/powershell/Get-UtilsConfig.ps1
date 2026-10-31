# NOTE:
#   Part of the Utils module, dot-sourced by Utils.psm1.
#
#   Get-UtilsConfig
#   Get-UtilsConfig -ConfigPath ./utils.config.json -Verbose

function Get-UtilsConfig {

    <#
    .SYNOPSIS
        Reads the Utils config file and fills in the defaults.

    .DESCRIPTION
        Returns the config from the given JSON file. A missing file is not an error,
        the defaults apply then. Keys missing in the file fall back to their default too.

    .EXAMPLE
        Read the config from the default location:

        PS> Get-UtilsConfig

    .EXAMPLE
        Read a specific config file and log every decision:

        PS> Get-UtilsConfig -ConfigPath ./utils.config.json -Verbose
    #>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        <#
        [Optional]
        The path to the config file. Default is '.utils/utils.config.json' in the home folder.
        #>
        [Parameter(
            Mandatory = $false
        )]
        [System.String]
        $ConfigPath = (Join-Path -Path $HOME -ChildPath '.utils/utils.config.json')
    )

    # ---------------------------------------------------------------------------
    # Defaults

    $DefaultConfig = [PSCustomObject]@{
        Region   = 'westeurope'
        Interval = 120
    }

    # ---------------------------------------------------------------------------
    # Read config

    try {
        $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        # Handled: a missing config simply means the defaults apply.
        Write-Verbose "[Get-UtilsConfig] Config '$ConfigPath' not found -> using defaults."
        return $DefaultConfig
    }
    # Everything else (e.g. invalid JSON) bubbles up unchanged.

    # ---------------------------------------------------------------------------
    # Merge defaults

    # Every key missing in the file falls back to its default.
    foreach ($property in $DefaultConfig.PSObject.Properties) {
        if ($null -NE $Config.($property.Name)) {
            continue
        }

        Write-Verbose "[Get-UtilsConfig] '$($property.Name)' missing in '$ConfigPath' -> using default '$($property.Value)'."
        $Config | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
    }

    return $Config
}
