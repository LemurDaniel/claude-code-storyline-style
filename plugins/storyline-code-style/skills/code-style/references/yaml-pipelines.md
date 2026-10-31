# Code Style: YAML Pipelines (GitHub Actions / Azure DevOps)

## General
- 2 spaces. One thin entry point per pipeline calls shared `tmpl.*` templates. The logic lives only in the templates.
- A header block before `jobs:` or `stages:` lists the auth setup, required secrets and required variables with their meaning:
  ```yaml
  # ---------------------------------------------------------------------------
  # Azure Authentication via Workload Identity Federation (OIDC)
  #   No client secrets or certificates needed.
  #
  #   Required GitHub Secrets:
  #     AZURE_CLIENT_ID   Client ID of the App Registration or Managed Identity
  #     AZURE_TENANT_ID   Azure AD Tenant ID
  # ---------------------------------------------------------------------------
  ```
- **Dangerous steps only behind an explicit switch:** First WhatIf or plan, then approval, then deploy. `apply` or deploy never runs without a preview first.
- **Allowed values sit at the parameter**, either as `values`/`options` or as a comment next to it:
  ```yaml
  - name: scope
    type: string
    # subscription | resourceGroup
  ```
- **Parameters with several input forms** get one example per form above them:
  ```yaml
  # Name or Id of the registries
  # Single mode
  #  - registries: acr-sample-dev-001
  # Multi mode
  #  - registries: |
  #     acr-sample-dev-001
  #     acr-sample-dev-002
  - name: registries
    type: string
    default: ''
  ```
- **Temporary changes are symmetric:** What one step opens beforehand (IP rule, context, firewall), a later step closes again, with `always()` so it also happens on failure.
  ```yaml
  steps:
    - template: ./tmpl.bicepRegistry.ipRules.yaml
      parameters:
        condition: and(ne('${{ parameters.registries }}', ''), succeeded())
        restrictionMode: AllowAccess
        ...

    - task: AzurePowerShell@5
      displayName: Deploy Bicep
      ...

    # Runs even when the deployment failed (the template wraps the condition with always()).
    - template: ./tmpl.bicepRegistry.ipRules.yaml
      parameters:
        condition: ne('${{ parameters.registries }}', '')
        restrictionMode: RemoveAccess
        ...
  ```
- **Document known bugs with a link** and leave the affected part commented out instead of deleting it:
  ```yaml
  # There is a bug in the ManualValidation task
  # https://github.com/microsoft/azure-pipelines-tasks/issues/21179
  # - name: approvers
  #   type: string
  #   default: ""
  ```
- **Inline scripts in `pwsh`** and following the PowerShell style. That means splatting, `-NOT`/`-EQ`, no backtick line breaks and validation with a clear message. Once an inline script grows beyond about 30 lines, it moves to `.scripts/*.ps1`.
  ```yaml
  - task: AzurePowerShell@5
    displayName: Deploy Bicep
    env:
      DEPLOYMENT_NAME: ${{ parameters.deploymentName }}
      TEMPLATE_FILE: ${{ parameters.templateFile }}
      PARAMETERS_FILE: ${{ parameters.parametersFile }}
      RESOURCE_GROUP: ${{ parameters.resourceGroup }}
      IS_WHAT_IF_ONLY: ${{ parameters.whatIfOnly }}
    inputs:
      ...
      inline: |
        $Deployment = @{
            Name                  = $env:DEPLOYMENT_NAME
            TemplateFile          = $env:TEMPLATE_FILE
            TemplateParameterFile = $env:PARAMETERS_FILE
        }

        if ([System.String]::IsNullOrEmpty($env:RESOURCE_GROUP)) {
            throw [System.ArgumentException]::new("Scope 'resourceGroup' requires the parameter 'resourceGroup'.")
        }

        if ([System.Boolean]::Parse($env:IS_WHAT_IF_ONLY)) {
            $Deployment.Add('WhatIf', $true)
        }

        New-AzResourceGroupDeployment @Deployment -ResourceGroupName $env:RESOURCE_GROUP -Verbose
  ```
- **Never template expressions directly in scripts:** neither `${{ }}` in `run:` (GitHub Actions) nor in `inline:`/`script:` (Azure DevOps). Values reach the script via `env:` and are read as `$env:NAME`, otherwise script injection is possible (see above and the `config` job under GitHub Actions).
- The results of WhatIf or plan are published as an artifact so the approver can read them.
- Placeholders instead of real names in templates (`<PROJECT>/<REPO_NAME>`, `rg-sample-dev`).
- **Verify** per `SKILL.md` → "Errors, logging, tests": `actionlint` for GitHub Actions where installed, inline scripts with the checks of their language. Azure DevOps has no local validator, a run with only the preview stage is the check.
  ```
  actionlint .github/workflows/deploy.infra.dev.yaml
  ```

## GitHub Actions
- One file per environment (`deploy.infra.<env>.yaml`) that calls a shared reusable workflow `tmpl.*`.
  ```yaml
  # deploy.infra.dev.yaml
  name: Deploy Infrastructure (dev)

  on:
    workflow_dispatch:

  jobs:
    deploy:
      uses: ./.github/workflows/tmpl.terraform.infra.deploy.yaml
      with:
        environment: dev
      secrets: inherit
  ```
- Jobs separated by `# ----` banners, a large pipeline groups them into chapters (e.g. build, deploy). A central `config` job computes shared values.
  ```yaml
  jobs:

    # ---------------------------------------------------------------------------
    # Config
    #   Computes shared values once for all following jobs.
    # ---------------------------------------------------------------------------
    config:
      runs-on: ubuntu-latest
      outputs:
        state_key: ${{ steps.config.outputs.state_key }}
      steps:
        - id: config
          shell: pwsh
          env:
            ENVIRONMENT: ${{ inputs.environment }}
          run: |
            "state_key=infra-$($env:ENVIRONMENT).tfstate" >> $env:GITHUB_OUTPUT

    # ---------------------------------------------------------------------------
    # Plan
    #   Publishes the plan as an artifact, so the approver can read it.
    # ---------------------------------------------------------------------------
    plan:
      needs: config
      ...
  ```
- `workflow_dispatch` inputs with `description`, `type` and `default`. `apply` sits behind an explicit boolean input.
  ```yaml
  on:
    workflow_dispatch:
      inputs:
        environment:
          description: Target environment
          type: choice
          options: [dev, tst, prd]
          default: dev
        apply:
          description: Run 'terraform apply' after the plan
          type: boolean
          default: false

  # ...
      - name: Terraform Apply
        if: ${{ inputs.apply == true }}
        run: terraform apply tfplan   # a saved plan applies without prompt
  ```
- OIDC instead of secrets, minimal `permissions`, quote strings like `"true"`.
  ```yaml
  permissions:
    id-token: write   # OIDC token for azure/login
    contents: read

  env:
    ARM_USE_OIDC: "true"

  steps:
    - uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
  ```
- Pin third-party actions to the commit SHA, with the version as a comment next to it. Actions from GitHub (`actions/*`) and Microsoft (`azure/*`) may use the major tag.
  ```yaml
  - uses: actions/checkout@v4
  - uses: hashicorp/setup-terraform@<COMMIT_SHA>   # v3.1.2
  ```

## Azure DevOps
- **Template hierarchy under `.devops/`:** The entry point calls stage templates, which in turn call step templates. Every level has its own folder.
  ```
  .devops/
    deploy.bicep.infra.yaml              # entry point: parameters + one stage per environment
    stage/tmpl.bicep.infra.deploy.yaml   # WhatIf -> Approve -> Deploy jobs
    steps/tmpl.bicep.infra.deploy.yaml   # the actual deployment task
    steps/tmpl.bicepRegistry.ipRules.yaml
  ```
- **One entry point with an `environment` parameter**, one stage call per environment with a `condition`. The service connection is fixed in the call, because it must be known at compile time.
  ```yaml
  trigger: none

  parameters:
    - name: environment
      type: string
      default: dev
      values: [dev, tst, prd]
    - name: whatIfOnly
      type: boolean
      default: false

  # NOTE:
  # ServiceConnection must be known at pipeline compile time.
  stages:
    - template: stage/tmpl.bicep.infra.deploy.yaml
      parameters:
        stage: dev
        condition: eq('${{ parameters.environment }}', 'dev')
        serviceConnection: project-connection-dev
        whatIfOnly: ${{ parameters.whatIfOnly }}

        templateFile: ./main.bicep
        parametersFile: ./params/main.dev.bicepparam

        scope: resourceGroup # subscription | resourceGroup
        resourceGroup: rg-sample-dev

        # --- (Optional) Sets temporary IP rules on the ACR
        # Use this when the ACR network is restricted
        # setTemporaryIpRules: |
        #   acrsampledev
  ```
- **Optional parameters in the call commented out with `# --- (Optional)`** and one sentence on when you need them (see above). Mutually exclusive variants stand as their own groups:
  ```yaml
  # --- on subscription scope
  # location: westeurope

  # --- on resource group scope
  resourceGroup: rg-sample-dev
  ```
- **Template parameters grouped with a comment** (general, scope, scope-specific, others). Each has a `type`, optional ones have a `default`.
  ```yaml
  parameters:
    - name: serviceConnection
      type: string

    # General deployment parameter
    - name: deploymentName
      type: string
    - name: templateFile
      type: string

    # deployment scope
    - name: scope
      type: string
      # subscription | resourceGroup

    # others
    - name: azurePowerShellVersion
      type: string
      default: LatestVersion
  ```
- **Jobs and step groups separated by `# ----` banners** (as in GitHub Actions), job names with a stage suffix so they are unique per stage:
  ```yaml
  jobs:
    # ---------------------------------------------------------------------------
    # WhatIf
    #   Previews the changes of the stage.
    # ---------------------------------------------------------------------------
    - job: what_if_${{ parameters.stage }}
      displayName: WhatIf Bicep
      ...

    # ---------------------------------------------------------------------------
    # Validation
    #   Waits up to three days for the manual approval.
    # ---------------------------------------------------------------------------
    - job: validate_${{ parameters.stage }}
      displayName: Approve Bicep
      pool: server
      timeoutInMinutes: 4320   # 3 days
      dependsOn: what_if_${{ parameters.stage }}
      condition: and(succeeded(), eq('${{ parameters.skipApprove }}', 'false'))
      steps:
        - task: ManualValidation@1
          inputs:
            instructions: Approve Bicep Deployment
            onTimeout: reject

    # ---------------------------------------------------------------------------
    # Deploy
    #   Deploys once the preview passed and the approval was given.
    # ---------------------------------------------------------------------------
    - job: deploy_${{ parameters.stage }}
      dependsOn:
        - what_if_${{ parameters.stage }}
        - validate_${{ parameters.stage }}
      # A skipped approval does not count as succeeded(), so the results are checked explicitly.
      condition: |
        and(
          eq(dependencies.what_if_${{ parameters.stage }}.result, 'Succeeded'),
          in(dependencies.validate_${{ parameters.stage }}.result, 'Succeeded', 'Skipped')
        )
  ```
- **Compile-time expressions for variants** (`${{ if }}`/`${{ else }}`, `${{ each }}`) instead of duplicating steps:
  ```yaml
  ${{ if eq(parameters.displayName, '') }}:
    displayName: ${{ parameters.stage }} | Bicep Deployment
  ${{ else }}:
    displayName: ${{ parameters.displayName }}

  variables:
    - ${{ if ne(parameters.variableGroup, '') }}:
        - group: ${{ parameters.variableGroup }}

  steps:
    - checkout: self
    - ${{ each subModule in parameters.checkoutSubModules }}:
        - checkout: ${{ subModule.alias }}
          path: s/$(Build.Repository.Name)/${{ subModule.path }}
  ```
- Write the WhatIf output via `Start-Transcript` into `$(Build.ArtifactStagingDirectory)` and publish it with the stage name:
  ```yaml
  - task: PublishPipelineArtifact@1
    displayName: Bicep WhatIf Artifact
    inputs:
      targetPath: $(Build.ArtifactStagingDirectory)/bicep_whatif.txt
      artifact: bicep_whatif_${{ parameters.stage }}
  ```
