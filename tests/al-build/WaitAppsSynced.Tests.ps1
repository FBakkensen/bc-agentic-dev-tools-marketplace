#Requires -Version 7.2

# Unit tests for Wait-BCAppsSynced — the sync-completion barrier that closes the
# dev-endpoint publish/test race ("Sorry, we just updated this page") without a
# service-tier restart. Get-BcContainerAppInfo is stubbed so these run with no
# BC container and no BcContainerHelper installed.

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force
    # Inject a stub for the external BcContainerHelper dependency into the module
    # scope so Mock can target it; the real command is unavailable off a BC host.
    InModuleScope common {
        if (-not (Get-Command Get-BcContainerAppInfo -ErrorAction SilentlyContinue)) {
            function Get-BcContainerAppInfo {
                param([string]$containerName, [string]$tenant, [switch]$tenantSpecificProperties)
            }
        }
    }
}

Describe 'Wait-BCAppsSynced' {

    It 'no-ops without querying the container when AppNames is empty' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Get-BcContainerAppInfo {}
            Mock Start-Sleep {}
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @()
            Should -Invoke Get-BcContainerAppInfo -Times 0 -Exactly
        }
    }

    It 'returns after a single poll when every target app is already Synced' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            Mock Get-BcContainerAppInfo {
                @(
                    [pscustomobject]@{ Name = 'Main';  SyncState = 'Synced'; NeedsUpgrade = $false }
                    [pscustomobject]@{ Name = 'Tests'; SyncState = 'Synced'; NeedsUpgrade = $false }
                )
            }
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main', 'Tests')
            Should -Invoke Get-BcContainerAppInfo -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }

    It 'polls until a settling app reaches Synced' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            $script:wcalls = 0
            Mock Get-BcContainerAppInfo {
                $script:wcalls++
                $state = if ($script:wcalls -ge 3) { 'Synced' } else { 'NotSynced' }
                @([pscustomobject]@{ Name = 'Main'; SyncState = $state; NeedsUpgrade = $false })
            }
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main')
            $script:wcalls | Should -Be 3
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }
    }

    It 'keeps waiting while NeedsUpgrade is set even though SyncState is Synced' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            $script:wcalls = 0
            Mock Get-BcContainerAppInfo {
                $script:wcalls++
                $needs = ($script:wcalls -lt 2)
                @([pscustomobject]@{ Name = 'Main'; SyncState = 'Synced'; NeedsUpgrade = $needs })
            }
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main')
            $script:wcalls | Should -Be 2
        }
    }

    It 'ignores apps that are not in the target set' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            Mock Get-BcContainerAppInfo {
                @(
                    [pscustomobject]@{ Name = 'Main';      SyncState = 'Synced';    NeedsUpgrade = $false }
                    [pscustomobject]@{ Name = 'Unrelated'; SyncState = 'NotSynced'; NeedsUpgrade = $true  }
                )
            }
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main')
            Should -Invoke Get-BcContainerAppInfo -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }

    It 'warns and returns (never throws) when the timeout elapses before sync' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            Mock Write-BuildMessage {}
            Mock Get-BcContainerAppInfo {
                @([pscustomobject]@{ Name = 'Main'; SyncState = 'NotSynced'; NeedsUpgrade = $true })
            }
            { Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main') -TimeoutSeconds 0 } | Should -Not -Throw
            Should -Invoke Write-BuildMessage -ParameterFilter { $Type -eq 'Warning' } -Times 1
        }
    }

    It 'treats a deserialized-enum SyncState (Int32 whose ToString is Synced) as synced' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            Mock Write-BuildMessage {}
            # Reproduce BcContainerHelper's real shape: SyncState is an Int32 (4)
            # whose .ToString() is 'Synced' but which is NOT -eq the string
            # 'Synced'. The old `-ne 'Synced'` predicate marked every app pending
            # and timed the barrier out on every gate; this locks in the fix.
            Mock Get-BcContainerAppInfo {
                $synced = 4 | Add-Member -MemberType ScriptMethod -Name ToString -Value { 'Synced' } -PassThru -Force
                @([pscustomobject]@{ Name = 'Main'; SyncState = $synced; NeedsUpgrade = $false })
            }
            Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main') -TimeoutSeconds 2
            Should -Invoke Get-BcContainerAppInfo -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }

    It 'survives a transient Get-BcContainerAppInfo failure and keeps polling' {
        InModuleScope common {
            Mock Import-BCContainerHelper {}
            Mock Start-Sleep {}
            Mock Write-BuildMessage {}
            $script:wcalls = 0
            Mock Get-BcContainerAppInfo {
                $script:wcalls++
                if ($script:wcalls -eq 1) { throw 'transient docker hiccup' }
                @([pscustomobject]@{ Name = 'Main'; SyncState = 'Synced'; NeedsUpgrade = $false })
            }
            { Wait-BCAppsSynced -ContainerName 'c' -AppNames @('Main') } | Should -Not -Throw
            $script:wcalls | Should -Be 2
        }
    }
}
