# NOTE:
#   Requires: PowerShell 7.3+, Az.Accounts, Az.KeyVault and a logged in context (Connect-AzAccount).
#   The identity needs 'Key Vault Secrets Officer' on both Key Vaults.
#
#   ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -WhatIf
#   ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -ExcludePatterns 'tmp-*', 'test-*'
#   ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -SubscriptionId '<SUBSCRIPTION_ID>' -IsForced

<#
.SYNOPSIS
    Moves all enabled secrets from one Key Vault to another.

.DESCRIPTION
    Copies every enabled secret of the source Key Vault into the target Key Vault
    and disables it in the source afterwards. Secrets matching an exclude pattern
    are skipped. Secrets that already exist in the target are only overwritten with -IsForced.

    The Azure context is switched to the given subscription and restored at the end,
    also when the script fails or gets cancelled.

.EXAMPLE
    Preview which secrets would move:

    PS> ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -WhatIf

.EXAMPLE
    Move everything except temporary secrets and overwrite existing ones:

    PS> ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -ExcludePatterns 'tmp-*' -IsForced
#>

[CmdletBinding(SupportsShouldProcess = $true)]
[OutputType([System.Management.Automation.PSCustomObject])]
param (
    <#
    [Required]
    The name of the Key Vault to move the secrets from.
    #>
    [Parameter(
        Mandatory = $true
    )]
    [System.String]
    $Source,

    <#
    [Required]
    The name of the Key Vault to move the secrets to. It must exist already.
    #>
    [Parameter(
        Mandatory = $true
    )]
    [System.String]
    $Target,

    <#
    [Optional]
    The subscription of both Key Vaults. Default is the subscription of the current context.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.String]
    $SubscriptionId,

    <#
    [Optional]
    Wildcard patterns of secret names to skip (e.g. 'tmp-*'). Default is none.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.String[]]
    $ExcludePatterns = @(),

    <#
    [Optional]
    Overwrites secrets that already exist in the target. Default is to skip them.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.Management.Automation.SwitchParameter]
    $IsForced
)

BEGIN {

    # ===========================================================================
    # ======================   LOAD AND VALIDATE SECRETS   ======================
    # ===========================================================================
    #
    #   1. Context       Switches to the given subscription, keeps the previous one.
    #   2. Validations   Fails early on equal or missing Key Vaults.
    #   3. Secrets       Loads all enabled secrets of the source.
    #

    # ---------------------------------------------------------------------------
    # Context

    $PreviousContext = Get-AzContext

    if (-NOT [System.String]::IsNullOrEmpty($SubscriptionId)) {
        Write-Verbose "[Move-KeyVaultSecret] Switching context to subscription '$SubscriptionId'."
        $null = Set-AzContext -Subscription $SubscriptionId
    }

    # ---------------------------------------------------------------------------
    # Validations

    if ($Source -EQ $Target) {
        throw [System.ArgumentException]::new('Source and Target must be different Key Vaults.')
    }
    if ($null -EQ (Get-AzKeyVault -VaultName $Source)) {
        throw [System.ArgumentException]::new("Source Key Vault '$Source' must exist in the current subscription.")
    }
    if ($null -EQ (Get-AzKeyVault -VaultName $Target)) {
        throw [System.ArgumentException]::new("Target Key Vault '$Target' must exist before moving secrets.")
    }

    # ---------------------------------------------------------------------------
    # Secrets

    $Secrets = Get-AzKeyVaultSecret -VaultName $Source
    | Where-Object -Property Enabled -EQ -Value $true

    $MovedCount   = 0
    $SkippedCount = 0

    Write-Verbose "[Move-KeyVaultSecret] Found $($Secrets.Count) enabled secrets in '$Source'."
}

PROCESS {

    # ===========================================================================
    # ============================   MOVE SECRETS   =============================
    # ===========================================================================
    #
    #   For every secret of the source:
    #   > When it matches an exclude pattern    -> skip it.
    #   > When it already exists in the target  -> skip it, unless -IsForced.
    #   > When -WhatIf is set                   -> only report it.
    #   > Otherwise                             -> copy it and disable it in the source.
    #

    :MOVE_SECRETS foreach ($secret in $Secrets) {

        # When it matches an exclude pattern -> skip it.
        foreach ($pattern in $ExcludePatterns) {
            if ($secret.Name -LIKE $pattern) {
                Write-Verbose "[Move-KeyVaultSecret] '$($secret.Name)' matches '$pattern' -> skipping."
                $SkippedCount++
                continue MOVE_SECRETS
            }
        }

        # When it already exists in the target -> skip it, unless -IsForced.
        $hasTargetSecret = $null -NE (Get-AzKeyVaultSecret -VaultName $Target -Name $secret.Name)
        if ($hasTargetSecret -AND -NOT $IsForced) {
            Write-Verbose "[Move-KeyVaultSecret] '$($secret.Name)' exists in '$Target' -> skipping, use -IsForced to overwrite."
            $SkippedCount++
            continue
        }

        # When -WhatIf is set -> only report it.
        if (-NOT $PSCmdlet.ShouldProcess($secret.Name, "Move from '$Source' to '$Target'")) {
            continue
        }

        # Otherwise -> copy it and disable it in the source.
        $sourceSecret = Get-AzKeyVaultSecret -VaultName $Source -Name $secret.Name

        $TargetSecret = @{
            VaultName   = $Target
            Name        = $secret.Name
            SecretValue = $sourceSecret.SecretValue
            ContentType = $sourceSecret.ContentType
            Tag         = $sourceSecret.Tags
        }
        $null = Set-AzKeyVaultSecret @TargetSecret
        $null = Update-AzKeyVaultSecret -VaultName $Source -Name $secret.Name -Enable $false

        Write-Verbose "[Move-KeyVaultSecret] Moved '$($secret.Name)' and disabled it in '$Source'."
        $MovedCount++
    }

    return [PSCustomObject]@{
        Moved   = $MovedCount
        Skipped = $SkippedCount
    }
}

CLEAN {

    # ---------------------------------------------------------------------------
    # Restore context

    # CLEAN also runs on errors and Ctrl+C, so the caller never stays in the wrong subscription.
    if ($null -NE $PreviousContext) {
        Write-Verbose "[Move-KeyVaultSecret] Restoring context '$($PreviousContext.Name)'."
        $null = Set-AzContext -Context $PreviousContext
    }
}
