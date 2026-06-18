#Requires -Version 7.2

BeforeAll {
    $script:Module = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-feed' 'scripts' 'feed.psm1')
    Import-Module $script:Module -Force
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-feed' 'references' 'feed.template.html')
    $script:Template = [System.IO.File]::ReadAllText($script:TemplatePath, [System.Text.UTF8Encoding]::new($false))
    $script:AppendScript = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-feed' 'scripts' 'feed-append.ps1')).Path

    function New-Card {
        param([string]$Skill = '/al-implement', [string]$Punch = 'p', [object[]]$Layers = @(), [string]$Kind = 'verdict', [string]$Ts = '2026-06-17T14:58:00')
        [pscustomobject]@{ skill = $Skill; ts = $Ts; punchline = $Punch; layers = $Layers; kind = $Kind }
    }
}

Describe 'ConvertTo-FeedHtmlText' {
    It 'escapes angle brackets' {
        ConvertTo-FeedHtmlText '<script>' | Should -Be '&lt;script&gt;'
    }
    It 'escapes ampersand first so entities are not double-decoded' {
        ConvertTo-FeedHtmlText '&lt;' | Should -Be '&amp;lt;'
    }
    It 'escapes double quotes' {
        ConvertTo-FeedHtmlText 'say "hi"' | Should -Be 'say &quot;hi&quot;'
    }
    It 'returns empty string for null' {
        ConvertTo-FeedHtmlText $null | Should -Be ''
    }
    It 'leaves plain BC text untouched' {
        ConvertTo-FeedHtmlText 'Sales Header posting' | Should -Be 'Sales Header posting'
    }
}

Describe 'Get-FeedCards' {
    It 'returns empty for a missing file' {
        (Get-FeedCards (Join-Path $TestDrive 'nope.jsonl')).Count | Should -Be 0
    }
    It 'parses valid lines and skips blanks' {
        $p = Join-Path $TestDrive 'ok.jsonl'
        [System.IO.File]::WriteAllText($p, "{`"skill`":`"a`",`"punchline`":`"one`"}`n`n{`"skill`":`"b`",`"punchline`":`"two`"}`n", [System.Text.UTF8Encoding]::new($false))
        $cards = Get-FeedCards $p
        $cards.Count | Should -Be 2
        $cards[0].punchline | Should -Be 'one'
        $cards[1].skill | Should -Be 'b'
    }
    It 'fails loud on a malformed line, naming the line number' {
        $p = Join-Path $TestDrive 'bad.jsonl'
        [System.IO.File]::WriteAllText($p, "{`"skill`":`"a`",`"punchline`":`"ok`"}`n{this is not json`n", [System.Text.UTF8Encoding]::new($false))
        { Get-FeedCards $p } | Should -Throw -ExpectedMessage '*line 2*'
    }
    It 'fails loud on a valid-JSON line that is not a card object' {
        $p = Join-Path $TestDrive 'scalar.jsonl'
        [System.IO.File]::WriteAllText($p, "{`"punchline`":`"ok`"}`n42`n", [System.Text.UTF8Encoding]::new($false))
        { Get-FeedCards $p } | Should -Throw -ExpectedMessage '*line 2*'
    }
    It 'fails loud on an object line with no punchline' {
        $p = Join-Path $TestDrive 'nopunch.jsonl'
        [System.IO.File]::WriteAllText($p, "{`"skill`":`"/a`",`"kind`":`"verdict`"}`n", [System.Text.UTF8Encoding]::new($false))
        { Get-FeedCards $p } | Should -Throw -ExpectedMessage '*no punchline*'
    }
}

Describe 'ConvertTo-FeedCardHtml' {
    It 'escapes punchline, label, and body' {
        $html = ConvertTo-FeedCardHtml (New-Card -Punch '<b>&' -Layers @(@{ label = '<L>'; body = '<x>&"' }))
        $html | Should -Match '&lt;b&gt;&amp;'
        $html | Should -Match '&lt;L&gt;'
        $html | Should -Match '&lt;x&gt;&amp;&quot;'
        $html | Should -Not -Match '<b>&'
    }
    It 'renders a punchline-only card flat, with no foot or hint' {
        $html = ConvertTo-FeedCardHtml (New-Card -Layers @() -Kind 'landing')
        $html | Should -Match 'card-head--flat'
        $html | Should -Not -Match 'card-foot'
        $html | Should -Not -Match 'hint'
    }
    It 'renders one .layer and one .pip per layer' {
        $html = ConvertTo-FeedCardHtml (New-Card -Layers @(@{ label = 'a'; body = 'b' }, @{ label = 'c'; body = 'd' }, @{ label = 'e'; body = 'f' }))
        ([regex]::Matches($html, 'class="layer"')).Count | Should -Be 3
        ([regex]::Matches($html, 'class="pip"')).Count | Should -Be 3
        $html | Should -Match 'card-foot'
    }
    It 'formats an ISO ts to a compact label' {
        $html = ConvertTo-FeedCardHtml (New-Card -Ts '2026-06-17T14:58:00' -Layers @(@{ label = 'a'; body = 'b' }))
        $html | Should -Match '2026-06-17 14:58'
    }
}

Describe 'ConvertTo-FeedHtml' {
    It 'renders newest-first by reversing storage order' {
        $cards = @(New-Card -Punch 'OLDEST'), (New-Card -Punch 'MIDDLE'), (New-Card -Punch 'NEWEST')
        $html = ConvertTo-FeedHtml -Cards $cards -Template $script:Template
        $html.IndexOf('NEWEST') | Should -BeLessThan $html.IndexOf('OLDEST')
    }
    It 'is idempotent — same input, identical output' {
        $cards = @(New-Card -Punch 'one'), (New-Card -Punch 'two')
        $a = ConvertTo-FeedHtml -Cards $cards -Template $script:Template -Branch 'b' -Title 't'
        $b = ConvertTo-FeedHtml -Cards $cards -Template $script:Template -Branch 'b' -Title 't'
        $a | Should -Be $b
    }
    It 'renders an empty feed without error' {
        $html = ConvertTo-FeedHtml -Cards @() -Template $script:Template
        $html | Should -Match 'empty-note'
        $html | Should -Not -Match '<!--FEED_CARDS-->'
    }
    It 'fills and escapes the branch and title placeholders' {
        $html = ConvertTo-FeedHtml -Cards @() -Template $script:Template -Branch 'br<x>&y' -Title 'Hold <it> & pay'
        $html | Should -Match 'br&lt;x&gt;&amp;y'
        $html | Should -Not -Match 'br<x>'
        $html | Should -Match 'Hold &lt;it&gt; &amp; pay'
        $html | Should -Not -Match '<!--BRANCH-->'
        $html | Should -Not -Match '<!--TITLE-->'
    }
}

Describe 'Add-FeedCard (end to end)' {
    It 'appends one json line per call and writes feed.html' {
        $dir = Join-Path $TestDrive 'specA'
        Add-FeedCard -SpecDir $dir -Skill '/al-implement' -Kind 'verdict' -Punchline 'first' -TemplatePath $script:TemplatePath | Out-Null
        $jsonl = Join-Path $dir 'feed.jsonl'
        (Get-FeedCards $jsonl).Count | Should -Be 1
        Test-Path (Join-Path $dir 'feed.html') | Should -BeTrue
    }
    It 'is append-only — earlier lines stay byte-identical' {
        $dir = Join-Path $TestDrive 'specB'
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'landing' -Punchline 'one' -TemplatePath $script:TemplatePath | Out-Null
        $jsonl = Join-Path $dir 'feed.jsonl'
        $firstAfter1 = ([System.IO.File]::ReadAllText($jsonl) -split "`n")[0]
        Add-FeedCard -SpecDir $dir -Skill '/b' -Kind 'decision' -Punchline 'two' -TemplatePath $script:TemplatePath | Out-Null
        Add-FeedCard -SpecDir $dir -Skill '/c' -Kind 'surprise' -Punchline 'three' -TemplatePath $script:TemplatePath | Out-Null
        $linesAfter3 = [System.IO.File]::ReadAllText($jsonl) -split "`n" | Where-Object { $_ }
        $linesAfter3.Count | Should -Be 3
        $linesAfter3[0] | Should -Be $firstAfter1
    }
    It 'round-trips UTF-8 punchlines (em-dash, accents, quotes)' {
        $dir = Join-Path $TestDrive 'specC'
        $text = 'Held — 33.33 EUR, naive "x"'
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'verdict' -Punchline $text -TemplatePath $script:TemplatePath | Out-Null
        $cards = Get-FeedCards (Join-Path $dir 'feed.jsonl')
        $cards[-1].punchline | Should -Be $text
    }
    It 'accepts 0, 1, and many layers' {
        $dir = Join-Path $TestDrive 'specD'
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'landing' -Punchline 'zero' -Layers @() -TemplatePath $script:TemplatePath | Out-Null
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'verdict' -Punchline 'one' -Layers @(@{ label = 'L'; body = 'B' }) -TemplatePath $script:TemplatePath | Out-Null
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'decision' -Punchline 'many' -Layers @(@{ label = 'a'; body = 'b' }, @{ label = 'c'; body = 'd' }, @{ label = 'e'; body = 'f' }) -TemplatePath $script:TemplatePath | Out-Null
        $cards = Get-FeedCards (Join-Path $dir 'feed.jsonl')
        $cards.Count | Should -Be 3
        $cards[1].layers[0].label | Should -Be 'L'
        $cards[1].layers[0].body | Should -Be 'B'
        $cards[2].layers.Count | Should -Be 3
        $cards[2].layers[2].body | Should -Be 'f'
        # the zero-layer card renders flat all the way to feed.html — match the
        # two-class attribute, not the CSS selectors which also name the class
        $html = [System.IO.File]::ReadAllText((Join-Path $dir 'feed.html'))
        ([regex]::Matches($html, 'card-head card-head--flat')).Count | Should -Be 1
    }
    It 'escapes markup end to end into feed.html (punchline and layers)' {
        $dir = Join-Path $TestDrive 'specE'
        Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'surprise' -Punchline '<script>alert(1)</script> & <b>' -Layers @(@{ label = '<L>'; body = '<x>&"' }) -TemplatePath $script:TemplatePath | Out-Null
        $html = [System.IO.File]::ReadAllText((Join-Path $dir 'feed.html'))
        $html | Should -Match '&lt;script&gt;'
        $html | Should -Match '&lt;L&gt;'
        $html | Should -Match '&lt;x&gt;&amp;&quot;'
        $html | Should -Not -Match '<script>alert'
        $html | Should -Not -Match '<x>&'
    }
    It 'rejects an invalid kind' {
        $dir = Join-Path $TestDrive 'specF'
        { Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'bogus' -Punchline 'x' -TemplatePath $script:TemplatePath } | Should -Throw
    }
    It 'fails loud before appending when a prior jsonl line is corrupt' {
        $dir = Join-Path $TestDrive 'specG'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $jsonl = Join-Path $dir 'feed.jsonl'
        [System.IO.File]::WriteAllText($jsonl, "{not json`n", [System.Text.UTF8Encoding]::new($false))
        { Add-FeedCard -SpecDir $dir -Skill '/a' -Kind 'verdict' -Punchline 'new' -TemplatePath $script:TemplatePath } | Should -Throw
        (Get-Content $jsonl).Count | Should -Be 1   # the new card must not have been appended
    }
}

Describe 'feed-append.ps1 (CLI wrapper)' {
    It 'parses -LayersJson and flows layer text through with escaping' {
        $dir = Join-Path $TestDrive 'wrapA'
        & $script:AppendScript -SpecDir $dir -Skill '/al-implement' -Kind 'verdict' -Punchline 'p' -LayersJson '[{"label":"L1","body":"B1 <x> & y"}]' -TemplatePath $script:TemplatePath *> $null
        $cards = Get-FeedCards (Join-Path $dir 'feed.jsonl')
        $cards[-1].layers[0].label | Should -Be 'L1'
        $cards[-1].layers[0].body | Should -Be 'B1 <x> & y'
        $html = [System.IO.File]::ReadAllText((Join-Path $dir 'feed.html'))
        $html | Should -Match 'B1 &lt;x&gt; &amp; y'
    }
    It 'throws on malformed -LayersJson' {
        $dir = Join-Path $TestDrive 'wrapB'
        { & $script:AppendScript -SpecDir $dir -Skill '/a' -Kind 'verdict' -Punchline 'p' -LayersJson '{not json' -TemplatePath $script:TemplatePath } | Should -Throw -ExpectedMessage '*LayersJson is not valid JSON*'
    }
    It 'defaults to a zero-layer card when -LayersJson is omitted' {
        $dir = Join-Path $TestDrive 'wrapC'
        & $script:AppendScript -SpecDir $dir -Skill '/a' -Kind 'landing' -Punchline 'just a punchline' -TemplatePath $script:TemplatePath *> $null
        $cards = Get-FeedCards (Join-Path $dir 'feed.jsonl')
        @($cards[-1].layers).Count | Should -Be 0
    }
}
