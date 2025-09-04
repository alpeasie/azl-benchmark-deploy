BeforeDiscovery {

    $null = Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId

}

if ($env:clusterDeploymentMode -eq 'full') {
Describe "LocalBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 25 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 25
    }
}
} elseif ($env:clusterDeploymentMode -eq 'validate') {
Describe "LocalBox resource group" {
    BeforeAll {
        $ResourceGroupName = $env:resourceGroup
    }
    It "should have 18 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 18
    }
} else {
Describe "LocalBox resource group" {
    BeforeAll { $ResourceGroupName = $env:resourceGroup }
    It "should have 5 resources or more" {
        (Get-AzResource -ResourceGroupName $ResourceGroupName).count | Should -BeGreaterOrEqual 5
    }
}
}
}
