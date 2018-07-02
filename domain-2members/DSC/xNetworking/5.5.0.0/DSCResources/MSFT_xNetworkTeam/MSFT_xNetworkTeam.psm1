$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the Networking Common Modules
Import-Module -Name (Join-Path -Path $modulePath `
        -ChildPath (Join-Path -Path 'NetworkingDsc.Common' `
            -ChildPath 'NetworkingDsc.Common.psm1'))

# Import the Networking Resource Helper Module
Import-Module -Name (Join-Path -Path $modulePath `
        -ChildPath (Join-Path -Path 'NetworkingDsc.ResourceHelper' `
            -ChildPath 'NetworkingDsc.ResourceHelper.psm1'))

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xNetworkTeam' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

<#
    .SYNOPSIS
    Returns the current state of a Network Team.

    .PARAMETER Name
    Specifies the name of the network team to create.

    .PARAMETER TeamMembers
    Specifies the network interfaces that should be a part of the network team.
    This is a comma-separated list.
#>
Function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers
    )

    $configuration = @{
        Name        = $Name
        TeamMembers = $TeamMembers
    }

    Write-Verbose -Message ($localizedData.GetTeamInfo -f $Name)
    $networkTeam = Get-NetLBFOTeam -Name $Name -ErrorAction SilentlyContinue

    if ($networkTeam)
    {
        Write-Verbose -Message ($localizedData.FoundTeam -f $Name)
        if ($null -eq (Compare-Object -ReferenceObject $TeamMembers -DifferenceObject $networkTeam.Members))
        {
            Write-Verbose -Message ($localizedData.TeamMembersExist -f $Name)
            $configuration.Add('LoadBalancingAlgorithm', $networkTeam.loadBalancingAlgorithm)
            $configuration.Add('TeamingMode', $networkTeam.teamingMode)
            $configuration.Add('Ensure', 'Present')
        }
    }
    else
    {
        Write-Verbose -Message ($localizedData.TeamNotFound -f $Name)
        $configuration.Add('Ensure', 'Absent')
    }

    return $configuration
}

<#
    .SYNOPSIS
    Adds, updates or removes a Network Team.

    .PARAMETER Name
    Specifies the name of the network team to create.

    .PARAMETER TeamMembers
    Specifies the network interfaces that should be a part of the network team.
    This is a comma-separated list.

    .PARAMETER TeamingMode
    Specifies the teaming mode configuration.

    .PARAMETER LoadBalancingAlgorithm
    Specifies the load balancing algorithm for the network team.

    .PARAMETER Ensure
    Specifies if the network team should be created or deleted.
#>
Function Set-TargetResource
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers,

        [Parameter()]
        [ValidateSet('SwitchIndependent', 'LACP', 'Static')]
        [System.String]
        $TeamingMode = 'SwitchIndependent',

        [Parameter()]
        [ValidateSet('Dynamic', 'HyperVPort', 'IPAddresses', 'MacAddresses', 'TransportPorts')]
        [System.String]
        $LoadBalancingAlgorithm = 'HyperVPort',

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ($localizedData.GetTeamInfo -f $Name)

    $networkTeam = Get-NetLBFOTeam -Name $Name -ErrorAction SilentlyContinue

    if ($Ensure -eq 'Present')
    {
        if ($networkTeam)
        {
            Write-Verbose -Message ($localizedData.FoundTeam -f $Name)

            $setArguments = @{
                Name = $Name
            }

            if ($networkTeam.loadBalancingAlgorithm -ne $LoadBalancingAlgorithm)
            {
                Write-Verbose -Message ($localizedData.LoadBalancingAlgorithmDifferent -f $LoadBalancingAlgorithm)

                $setArguments.Add('LoadBalancingAlgorithm', $LoadBalancingAlgorithm)
                $isNetModifyRequired = $true
            }

            if ($networkTeam.TeamingMode -ne $TeamingMode)
            {
                Write-Verbose -Message ($localizedData.TeamingModeDifferent -f $TeamingMode)

                $setArguments.Add('TeamingMode', $TeamingMode)
                $isNetModifyRequired = $true
            }

            if ($isNetModifyRequired)
            {
                Write-Verbose -Message ($localizedData.ModifyTeam -f $Name)

                Set-NetLbfoTeam @setArguments -ErrorAction Stop -Confirm:$false
            }

            $netTeamMembers = Compare-Object `
                -ReferenceObject $TeamMembers `
                -DifferenceObject $networkTeam.Members

            if ($null -ne $netTeamMembers)
            {
                Write-Verbose -Message ($localizedData.MembersDifferent -f $Name)

                $membersToRemove = ($netTeamMembers | Where-Object -FilterScript {
                        $_.SideIndicator -eq '=>'
                    }).InputObject

                if ($membersToRemove)
                {
                    Write-Verbose -Message ($localizedData.RemovingMembers -f ($membersToRemove -join ','))

                    $null = Remove-NetLbfoTeamMember -Name $membersToRemove `
                        -Team $Name `
                        -ErrorAction Stop `
                        -Confirm:$false
                }

                $membersToAdd = ($netTeamMembers | Where-Object -FilterScript {
                        $_.SideIndicator -eq '<='
                    }).InputObject

                if ($membersToAdd)
                {
                    Write-Verbose -Message ($localizedData.AddingMembers -f ($membersToAdd -join ','))

                    $null = Add-NetLbfoTeamMember -Name $membersToAdd `
                        -Team $Name `
                        -ErrorAction Stop `
                        -Confirm:$false
                }
            }
        }
        else
        {
            Write-Verbose -Message ($localizedData.CreateTeam -f $Name)

            try
            {
                $null = New-NetLbfoTeam `
                    -Name $Name `
                    -TeamMembers $teamMembers `
                    -TeamingMode $TeamingMode `
                    -LoadBalancingAlgorithm $loadBalancingAlgorithm `
                    -ErrorAction Stop `
                    -Confirm:$false

                Write-Verbose -Message $localizedData.CreatedNetTeam
            }

            catch
            {
                New-InvalidOperationException `
                    -Message ($localizedData.failedToCreateTeam -f $_.Exception.Message)
            }
        }
    }
    else
    {
        Write-Verbose -Message ($localizedData.RemoveTeam -f $Name)

        $null = Remove-NetLbfoTeam -Name $name -ErrorAction Stop -Confirm:$false
    }
}

<#
    .SYNOPSIS
    Tests is a specified Network Team is in the correct state.

    .PARAMETER Name
    Specifies the name of the network team to create.

    .PARAMETER TeamMembers
    Specifies the network interfaces that should be a part of the network team.
    This is a comma-separated list.

    .PARAMETER TeamingMode
    Specifies the teaming mode configuration.

    .PARAMETER LoadBalancingAlgorithm
    Specifies the load balancing algorithm for the network team.

    .PARAMETER Ensure
    Specifies if the network team should be created or deleted.
#>
Function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers,

        [Parameter()]
        [ValidateSet('SwitchIndependent', 'LACP', 'Static')]
        [System.String]
        $TeamingMode = 'SwitchIndependent',

        [Parameter()]
        [ValidateSet('Dynamic', 'HyperVPort', 'IPAddresses', 'MacAddresses', 'TransportPorts')]
        [System.String]
        $LoadBalancingAlgorithm = 'HyperVPort',

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ($localizedData.GetTeamInfo -f $Name)

    $networkTeam = Get-NetLbfoTeam -Name $Name -ErrorAction SilentlyContinue

    if ($ensure -eq 'Present')
    {
        if ($networkTeam)
        {
            Write-Verbose -Message ($localizedData.FoundTeam -f $Name)

            if (
                ($networkTeam.LoadBalancingAlgorithm -eq $LoadBalancingAlgorithm) -and
                ($networkTeam.teamingMode -eq $TeamingMode) -and
                ($null -eq (Compare-Object -ReferenceObject $TeamMembers -DifferenceObject $networkTeam.Members))
            )
            {
                Write-Verbose -Message ($localizedData.TeamExistsNoAction -f $Name)

                return $true
            }
            else
            {
                Write-Verbose -Message ($localizedData.TeamExistsWithDifferentConfig -f $Name)

                return $false
            }
        }
        else
        {
            Write-Verbose -Message ($localizedData.TeamDoesNotExistShouldCreate -f $Name)

            return $false
        }
    }
    else
    {
        if ($networkTeam)
        {
            Write-Verbose -Message ($localizedData.TeamExistsShouldRemove -f $Name)

            return $false
        }
        else
        {
            Write-Verbose -Message ($localizedData.TeamDoesNotExistNoAction -f $Name)

            return $true
        }
    }
}
