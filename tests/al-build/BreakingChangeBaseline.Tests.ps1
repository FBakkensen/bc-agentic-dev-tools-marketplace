#Requires -Version 7.2

BeforeAll {
    $base = Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts'
    Import-Module (Resolve-Path (Join-Path $base 'common.psm1')) -Force -DisableNameChecking
    Import-Module (Resolve-Path (Join-Path $base 'build-operations.psm1')) -Force -DisableNameChecking
}

Describe 'Get-BaselineVersion' {
    Context 'Filename token (BcContainerHelper <publisher>_<name>_<version>.app)' {
        It 'reads a 4-part version from the trailing token' {
            Get-BaselineVersion -AppFileName '9altitudes_NALICF Copy Document_1.2.3.0.app' -ReleaseTag 'v9.9.9.9' |
                Should -Be '1.2.3.0'
        }

        It 'accepts the name with or without the .app extension' {
            Get-BaselineVersion -AppFileName 'Pub_App_2.0.0.0' | Should -Be '2.0.0.0'
        }

        It 'accepts a 2-part version' {
            Get-BaselineVersion -AppFileName 'Pub_App_1.2.app' | Should -Be '1.2'
        }

        It 'tolerates underscores in the publisher/name (version is the last token)' {
            Get-BaselineVersion -AppFileName 'My_Pub_My_App_3.4.5.6.app' | Should -Be '3.4.5.6'
        }
    }

    Context 'Release-tag fallback' {
        It 'falls back to the tag when the filename has no version token' {
            Get-BaselineVersion -AppFileName 'no-version-here.app' -ReleaseTag '5.6.7.0' | Should -Be '5.6.7.0'
        }

        It 'strips a leading v from the tag' {
            Get-BaselineVersion -AppFileName 'no-version-here.app' -ReleaseTag 'v5.6.7.0' | Should -Be '5.6.7.0'
        }

        It 'prefers the filename token over the tag' {
            Get-BaselineVersion -AppFileName 'Pub_App_1.0.0.0.app' -ReleaseTag '9.9.9.9' | Should -Be '1.0.0.0'
        }
    }

    Context 'No valid version' {
        It 'returns $null when neither filename nor tag yields a version' {
            Get-BaselineVersion -AppFileName 'garbage.app' -ReleaseTag 'release-candidate' | Should -BeNullOrEmpty
        }

        It 'returns $null when the tag is non-numeric and no token exists' {
            Get-BaselineVersion -AppFileName 'app.app' | Should -BeNullOrEmpty
        }
    }
}

Describe 'Set-AppSourceCopBaseline' {
    BeforeEach {
        $script:asc = '{ "mandatoryAffixes": ["NALICF"], "supportedCountries": ["dk"] }' | ConvertFrom-Json
    }

    It 'adds version and baselinePackageCachePath' {
        $r = Set-AppSourceCopBaseline -Object $script:asc -Version '1.2.3.0' -CachePath '../.output/baseline-cache'
        $r.version | Should -Be '1.2.3.0'
        $r.baselinePackageCachePath | Should -Be '../.output/baseline-cache'
    }

    It 'preserves existing keys and single-element arrays across a JSON round-trip' {
        Set-AppSourceCopBaseline -Object $script:asc -Version '1.0.0.0' -CachePath 'x' | Out-Null
        $roundTripped = $script:asc | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $roundTripped.mandatoryAffixes | Should -Be @('NALICF')
        $roundTripped.mandatoryAffixes.Count | Should -Be 1
        $roundTripped.supportedCountries | Should -Be @('dk')
    }

    It 'updates in place without duplicating on re-run (idempotent)' {
        Set-AppSourceCopBaseline -Object $script:asc -Version '1.0.0.0' -CachePath 'x' | Out-Null
        Set-AppSourceCopBaseline -Object $script:asc -Version '2.0.0.0' -CachePath 'y' | Out-Null
        @($script:asc.PSObject.Properties | Where-Object { $_.Name -eq 'version' }).Count | Should -Be 1
        $script:asc.version | Should -Be '2.0.0.0'
        $script:asc.baselinePackageCachePath | Should -Be 'y'
    }
}

Describe 'Clear-AppSourceCopBaseline' {
    It 'removes version so detection is off, leaving other keys intact' {
        $asc = '{ "mandatoryAffixes": ["NALICF"], "version": "1.0.0.0", "baselinePackageCachePath": "x" }' | ConvertFrom-Json
        Clear-AppSourceCopBaseline -Object $asc | Out-Null
        $asc.PSObject.Properties['version'] | Should -BeNullOrEmpty
        $asc.mandatoryAffixes | Should -Be @('NALICF')
        $asc.baselinePackageCachePath | Should -Be 'x'
    }

    It 'is a no-op when version is already absent' {
        $asc = '{ "mandatoryAffixes": ["NALICF"] }' | ConvertFrom-Json
        { Clear-AppSourceCopBaseline -Object $asc } | Should -Not -Throw
        $asc.PSObject.Properties['version'] | Should -BeNullOrEmpty
    }
}

Describe 'Get-AlValidationVerdict' {
    It 'passes on an empty result' {
        $r = Get-AlValidationVerdict -ValidationResult @()
        $r.Verdict | Should -Be 'Passed'
        $r.Findings | Should -BeNullOrEmpty
        $r.EnvironmentErrors | Should -BeNullOrEmpty
    }

    It 'passes when nothing was returned at all' {
        $r = Get-AlValidationVerdict
        $r.Verdict | Should -Be 'Passed'
    }

    It 'classifies environment-only errors as EnvironmentError, not a breaking change' {
        $lines = @(
            'Unexpected error while validating app. Error is: hcs::CreateComputeSystem bcserver: The request is not supported.'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'EnvironmentError'
        $r.EnvironmentErrors.Count | Should -Be 1
        $r.Findings | Should -BeNullOrEmpty
    }

    It 'classifies AppSourceCop findings as BreakingChange' {
        $lines = @(
            '2 errors found in MyApp.app on https://bcartifacts.azureedge.net/sandbox/24.0/dk:'
            'error AS0023: Procedure ''PostSalesOrder'' has been removed.'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'BreakingChange'
        $r.Findings.Count | Should -Be 2
    }

    It 'lets a finding outrank an environment error in a mixed result' {
        $lines = @(
            'error AS0023: Procedure ''PostSalesOrder'' has been removed.'
            'Unexpected error while validating app. Error is: docker pull timed out'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'BreakingChange'
        $r.Findings.Count | Should -Be 1
        $r.EnvironmentErrors.Count | Should -Be 1
    }

    It 'ignores blank separator lines (Run-AlCops appends them between blocks)' {
        $r = Get-AlValidationVerdict -ValidationResult @('', '   ', '')
        $r.Verdict | Should -Be 'Passed'
    }
}

Describe 'validate-breaking-changes.ps1 Run-AlValidation contract' {
    It 'passes skipVerification (local and AL-Go CI builds are unsigned; without it every run classifies NotSigned as a finding)' {
        $scriptPath = Join-Path $base 'validate-breaking-changes.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $pair = $ast.FindAll({ param($node)
                $node -is [System.Management.Automation.Language.HashtableAst]
            }, $true) |
            ForEach-Object { $_.KeyValuePairs } |
            Where-Object { $_.Item1.Extent.Text -eq 'skipVerification' }
        $pair | Should -Not -BeNullOrEmpty
        $pair.Item2.Extent.Text | Should -Be '$true'
    }
}
