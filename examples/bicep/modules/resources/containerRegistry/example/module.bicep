targetScope = 'resourceGroup'

// NOTE:
//   Test deployment of the containerRegistry module, the values come from module.bicepparam.
//
//   az deployment group create -g rg-sample-tst -f example/module.bicep -p example/module.bicepparam --what-if

import { typeNaming } from '../../../utility/lib.bicep'

// ---------------------------------------------------------------------------
// Parameters
@description('(Required) Naming context of the test deployment.')
param naming typeNaming

@description('(Required) IP ranges that may reach the registry.')
param ipRules string[]

// ---------------------------------------------------------------------------
// Deployment
module containerRegistry '../module.bicep' = {
  name: 'test-container-registry'
  params: {
    naming: naming
    sku: 'Premium'
    networking: {
      access: 'Restricted'
      ipRules: ipRules
    }
  }
}
