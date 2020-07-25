# Requires -Module Az.Compute

describe 'resource group' {
    it 'creates the resource group with the expected name' {
        Get-AzResourceGroup -Name dev_playground -ErrorAction Ignore | should -not -BeNullOrEmpty
    }
}

describe 'virtual network' {

    $script:vNet = Get-AzVirtualNetwork -Name dev_playground-vNet -ErrorAction Ignore

    it 'creates the vNet with the expected name' {
        $script:vNet | should -not -BeNullOrEmpty
    }

    it 'creates the vNet with the expected address space' {
        $script:vNet.AddressSpace.AddressPrefixes[0] | should -Be '10.0.0.0/16'
    }
}

describe 'subnet' {

    $script:vNet = Get-AzVirtualNetwork -Name dev_playground-vNet -ErrorAction Ignore
    $script:subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $script:vNet -ErrorAction Ignore

    it 'attaches the subnet to the expected vNet' {
        $script:subnet | should -Not -BeNullOrEmpty
    }

    it 'creates the subnet with the expected address prefix' {
        $script:subnet.AddressPrefix[0] | should -Be '10.0.2.0/24'
    }
}

describe 'public IP' {

    $script:pip = Get-AzPublicIpAddress -ResourceGroupName dev_playground -ErrorAction Ignore

    it 'creates the public IP in the expected resource group' {
        $script:pip | should -Not -BeNullOrEmpty
    }

    it 'create the public IP with the expected allocation method' {
        $script:pip.PublicIpAllocationMethod | should -Be 'Static'
    }
}

describe 'vNic' {

    $script:vNet = Get-AzVirtualNetwork -Name dev_playground-vNet -ErrorAction Ignore
    $script:subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $script:vNet -ErrorAction Ignore

    $script:nsg = Get-AzNetworkSecurityGroup -Name 'env-access' -ResourceGroupName 'dev_playground' -ErrorAction Ignore

    $script:pip = Get-AzPublicIpAddress -ResourceGroupName dev_playground -ErrorAction Ignore

    $script:vNic = Get-AzNetworkInterface -ResourceGroupName 'dev_playground' -Name 'vNic' -ErrorAction Ignore

    it 'creates the vNic in the expected resource group' {
        $script:vNic | should -Not -BeNullOrEmpty
    }

    it 'assigns the vNic to the expected subnet' {
        $script:vNic.IpConfigurations[0].Subnet.Id | should -Be $script:subnet.Id
    }

    it 'create the vNic with the expected address allocation' {
        $script:vNic.IpConfigurations[0].PrivateIpAllocationMethod | should -Be 'Static'
    }

    it 'creates the vNic with the expected IP address' {
        $script:vNic.IpConfigurations[0].PrivateIpAddress | should -Be '10.0.2.5'
    }

    it 'assigns the vNic to the expected public IP' {
        $script:vNic.IpConfigurations[0].PublicIpAddress.Id | should -Be $script:pip.Id
    }

    it 'assigns the vNic to the expected network security group' {
        $script:vNic.NetworkSecurityGroup.Id | should -Be $script:nsg.Id
    }
}

describe 'network security group' {

    $script:nsg = Get-AzNetworkSecurityGroup -Name 'env-access' -ResourceGroupName 'dev_playground' -ErrorAction Ignore
    
    it 'creates a network security group with the expected name' {
        $script:nsg | should -Not -BeNullOrEmpty
    }
}

describe 'vm' {

    $script:vm = Get-AzVM -ResourceGroupName dev_playground -Name 'vm-0' -ErrorAction Ignore

    $script:vNic = Get-AzNetworkInterface -ResourceGroupName 'dev_playground' -Name 'vNic' -ErrorAction Ignore

    it 'creates the VM with the expected name' {
        $script:vm | should -Not -BeNullOrEmpty
    }

    it 'creates the VM in the expected resource group' {
        $script:vm | should -Not -BeNullOrEmpty
    }

    it 'creates the VM with the expected size' {
        $script:vm.HardwareProfile.VmSize | should -Be 'Standard_F2'
    }

    it 'creates the VM with the expected local admin user account' {
        $script:vm.OSProfile.AdminUsername | should -Be 'adminuser'
    }

    it 'assigns the expected vNic to the VM' {
        $script:vm.NetworkProfile.NetworkInterfaces.id | should -Be $script:vNic.Id
    }

    it 'creates an OS disk using the expected caching setting' {
        $script:vm.StorageProfile.OsDisk.Caching | should -Be 'ReadWrite'
    }

    it 'creates an OS disk using the expected storage account type' {
        $script:vm.StorageProfile.OsDisk.manageddisk.StorageAccountType | should -Be 'Standard_LRS'
    }

    it 'creates a VM with the expected OS' {
        $script:vm.StorageProfile.OsDisk.OsType | should -Be 'Windows'
    }
}