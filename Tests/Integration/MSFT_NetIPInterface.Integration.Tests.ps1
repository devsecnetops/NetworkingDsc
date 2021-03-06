$script:DSCModuleName = 'NetworkingDsc'
$script:DSCResourceName = 'MSFT_NetIPInterface'

#region HEADER
# Integration Test Template Version: 1.1.0
[string] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\NetworkingDsc'

if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Configure Loopback Adapter and configure settings with an initial state
. (Join-Path -Path (Split-Path -Parent $Script:MyInvocation.MyCommand.Path) -ChildPath 'IntegrationHelper.ps1')
New-IntegrationLoopbackAdapter -AdapterName 'NetworkingDscLBA'

<#
    The following settings are not supported by the loopback adapter so
    can not be tested using these tests:
    - Advertising
    - AutomaticMetric (can not be disabled after being enabled)
    - NeighborUnreachabilityDetection

    Applying the above configuration settings to the loopback adapter
    results in a "The parameter is incorrect" error message.
#>
$setNetIPInterfaceParameters = @{
    InterfaceAlias              = 'NetworkingDscLBA'
    AddressFamily               = 'IPv4'
    AdvertiseDefaultRoute       = 'Disabled'
    AutomaticMetric             = 'Disabled'
    DirectedMacWolPattern       = 'Disabled'
    EcnMarking                  = 'Disabled'
    ForceArpNdWolPattern        = 'Disabled'
    Forwarding                  = 'Disabled'
    IgnoreDefaultRoutes         = 'Disabled'
    ManagedAddressConfiguration = 'Disabled'
    OtherStatefulConfiguration  = 'Disabled'
    RouterDiscovery             = 'Disabled'
}
Set-NetIPInterface @setNetIPInterfaceParameters

# Using try/finally to always cleanup even if something awful happens.
try
{
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile -Verbose -ErrorAction Stop

    Describe "$($script:DSCResourceName)_Integration" {
        Context 'When all settings are enabled' {
            # This is to pass to the Config
            $script:configData = @{
                AllNodes = @(
                    @{
                        NodeName                        = 'localhost'
                        InterfaceAlias                  = 'NetworkingDscLBA'
                        AddressFamily                   = 'IPv4'
                        AdvertiseDefaultRoute           = 'Enabled'
                        AutomaticMetric                 = 'Enabled'
                        DirectedMacWolPattern           = 'Enabled'
                        EcnMarking                      = 'AppDecide'
                        ForceArpNdWolPattern            = 'Enabled'
                        Forwarding                      = 'Enabled'
                        IgnoreDefaultRoutes             = 'Enabled'
                        ManagedAddressConfiguration     = 'Enabled'
                        NeighborUnreachabilityDetection = 'Enabled'
                        OtherStatefulConfiguration      = 'Enabled'
                        RouterDiscovery                 = 'ControlledByDHCP'
                    }
                )
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    & "$($script:DSCResourceName)_Config_Enabled" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $script:configData

                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ComputerName localhost `
                        -Wait `
                        -Verbose `
                        -Force `
                        -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should have set the resource and all the parameters should match' {
                $current = Get-DscConfiguration | Where-Object -FilterScript {
                    $_.ConfigurationName -eq "$($script:DSCResourceName)_Config_Enabled"
                }
                $current.InterfaceAlias                  | Should -Be $script:configData.AllNodes[0].InterfaceAlias
                $current.AddressFamily                   | Should -Be $script:configData.AllNodes[0].AddressFamily
                $current.AdvertiseDefaultRoute           | Should -Be $script:configData.AllNodes[0].AdvertiseDefaultRoute
                $current.AutomaticMetric                 | Should -Be $script:configData.AllNodes[0].AutomaticMetric
                $current.DirectedMacWolPattern           | Should -Be $script:configData.AllNodes[0].DirectedMacWolPattern
                $current.EcnMarking                      | Should -Be $script:configData.AllNodes[0].EcnMarking
                $current.ForceArpNdWolPattern            | Should -Be $script:configData.AllNodes[0].ForceArpNdWolPattern
                $current.Forwarding                      | Should -Be $script:configData.AllNodes[0].Forwarding
                $current.IgnoreDefaultRoutes             | Should -Be $script:configData.AllNodes[0].IgnoreDefaultRoutes
                $current.ManagedAddressConfiguration     | Should -Be $script:configData.AllNodes[0].ManagedAddressConfiguration
                $current.NeighborUnreachabilityDetection | Should -Be $script:configData.AllNodes[0].NeighborUnreachabilityDetection
                $current.OtherStatefulConfiguration      | Should -Be $script:configData.AllNodes[0].OtherStatefulConfiguration
                $current.RouterDiscovery                 | Should -Be $script:configData.AllNodes[0].RouterDiscovery
            }
        }

        Context 'When all settings are disabled' {
            # This is to pass to the Config
            $script:configData = @{
                AllNodes = @(
                    @{
                        NodeName                    = 'localhost'
                        InterfaceAlias              = 'NetworkingDscLBA'
                        AddressFamily               = 'IPv4'
                        AdvertiseDefaultRoute       = 'Disabled'
                        DirectedMacWolPattern       = 'Disabled'
                        EcnMarking                  = 'Disabled'
                        Forwarding                  = 'Disabled'
                        ForceArpNdWolPattern        = 'Disabled'
                        IgnoreDefaultRoutes         = 'Disabled'
                        ManagedAddressConfiguration = 'Disabled'
                        OtherStatefulConfiguration  = 'Disabled'
                        RouterDiscovery             = 'Disabled'

                    }
                )
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    & "$($script:DSCResourceName)_Config_Disabled" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $script:configData

                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ComputerName localhost `
                        -Wait `
                        -Verbose `
                        -Force `
                        -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should have set the resource and all the parameters should match' {
                $current = Get-DscConfiguration | Where-Object -FilterScript {
                    $_.ConfigurationName -eq "$($script:DSCResourceName)_Config_Disabled"
                }
                $current.InterfaceAlias                  | Should -Be $script:configData.AllNodes[0].InterfaceAlias
                $current.AddressFamily                   | Should -Be $script:configData.AllNodes[0].AddressFamily
                $current.AdvertiseDefaultRoute           | Should -Be $script:configData.AllNodes[0].AdvertiseDefaultRoute
                $current.DirectedMacWolPattern           | Should -Be $script:configData.AllNodes[0].DirectedMacWolPattern
                $current.EcnMarking                      | Should -Be $script:configData.AllNodes[0].EcnMarking
                $current.ForceArpNdWolPattern            | Should -Be $script:configData.AllNodes[0].ForceArpNdWolPattern
                $current.Forwarding                      | Should -Be $script:configData.AllNodes[0].Forwarding
                $current.IgnoreDefaultRoutes             | Should -Be $script:configData.AllNodes[0].IgnoreDefaultRoutes
                $current.ManagedAddressConfiguration     | Should -Be $script:configData.AllNodes[0].ManagedAddressConfiguration
                $current.OtherStatefulConfiguration      | Should -Be $script:configData.AllNodes[0].OtherStatefulConfiguration
                $current.RouterDiscovery                 | Should -Be $script:configData.AllNodes[0].RouterDiscovery
            }
        }
    }
}
finally
{
    # Remove Loopback Adapter
    Remove-IntegrationLoopbackAdapter -AdapterName 'NetworkingDscLBA'

    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
