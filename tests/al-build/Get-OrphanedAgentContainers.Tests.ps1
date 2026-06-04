#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force

    function script:Initialize-TestClone {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Branch
        )
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        git -C $Path init -q
        git -C $Path config user.email 'test@example.invalid'
        git -C $Path config user.name  'test'
        git -C $Path config commit.gpgsign false
        git -C $Path remote add origin 'https://example.com/foo.git'
        git -C $Path checkout -q -b $Branch
        git -C $Path commit -q --allow-empty -m 'init'
    }
}

Describe 'Get-OrphanedAgentContainers — cross-clone isolation' {
    BeforeAll {
        $script:OriginalHome = $env:HOME
        $script:OriginalUserProfile = $env:USERPROFILE

        $script:FakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome

        $script:CloneA = Join-Path $TestDrive 'cloneA'
        $script:CloneB = Join-Path $TestDrive 'cloneB'
        Initialize-TestClone -Path $script:CloneA -Branch 'feat-x'
        Initialize-TestClone -Path $script:CloneB -Branch 'feat-y'

        Push-Location $script:CloneA
        try {
            Register-AgentContainer -ContainerName 'feat-x' -Branch 'feat-x'
            Register-AgentContainer -ContainerName 'ghost'  -Branch 'never-created'
        } finally {
            Pop-Location
        }

        Push-Location $script:CloneB
        try {
            Register-AgentContainer -ContainerName 'feat-y' -Branch 'feat-y'
        } finally {
            Pop-Location
        }
    }

    AfterAll {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    It 'does not flag a peer clone container as orphaned' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $orphaned.ContainerName | Should -Not -Contain 'feat-y'
        } finally {
            Pop-Location
        }
    }

    It 'flags the current clone container whose branch does not exist' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $ghost = $orphaned | Where-Object { $_.ContainerName -eq 'ghost' }
            $ghost          | Should -Not -BeNullOrEmpty
            $ghost.Reason   | Should -Be 'orphaned'
        } finally {
            Pop-Location
        }
    }

    It 'does not flag the current clone container whose branch exists' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $orphaned.ContainerName | Should -Not -Contain 'feat-x'
        } finally {
            Pop-Location
        }
    }
}

Describe 'Get-GitRepoIdentifier — worktree consistency' {
    BeforeAll {
        $script:OriginalHome = $env:HOME
        $script:OriginalUserProfile = $env:USERPROFILE

        $script:FakeHome = Join-Path $TestDrive 'home-worktree'
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome

        $script:Primary = Join-Path $TestDrive 'primary'
        Initialize-TestClone -Path $script:Primary -Branch 'main-line'

        $script:Linked = Join-Path $TestDrive 'linked'
        git -C $script:Primary worktree add -q -b 'wt-branch' $script:Linked
    }

    AfterAll {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    It 'returns the same identifier from a linked worktree as from the primary working tree' {
        $primaryPath = $script:Primary
        $linkedPath  = $script:Linked

        $primaryId = InModuleScope common -Parameters @{ Path = $primaryPath } {
            param($Path)
            Push-Location $Path
            try { Get-GitRepoIdentifier } finally { Pop-Location }
        }

        $linkedId = InModuleScope common -Parameters @{ Path = $linkedPath } {
            param($Path)
            Push-Location $Path
            try { Get-GitRepoIdentifier } finally { Pop-Location }
        }

        $primaryId | Should -Not -BeNullOrEmpty
        $linkedId  | Should -Be $primaryId
    }
}
