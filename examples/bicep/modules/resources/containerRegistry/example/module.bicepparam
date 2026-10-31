using 'module.bicep'

// NOTE: The deploying identity needs 'Contributor' on rg-sample-tst.
param naming = {
  environment: 'tst'
  locationShort: 'euwe'
  workload: 'sample'
}

// NOTE: Ranges in CIDR notation, the deploying agent must be inside one of them to push test images.
param ipRules = [
  '<OFFICE_IP_RANGE>'
  '<BUILD_AGENT_IP_RANGE>'
]
