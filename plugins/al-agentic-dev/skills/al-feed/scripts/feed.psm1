#Requires -Version 7.2

# Branch-feed engine. Pure render + escape functions are unit-tested directly;
# Add-FeedCard is the stateful append (UTF-8, append-only) + html regeneration.
# The /al-feed skill composes a card and calls feed-append.ps1 -> Add-FeedCard.

# Keep in lockstep with the ValidateSet on Add-FeedCard's -Kind, the matching
# one in feed-append.ps1, and the kind list in SKILL.md — PowerShell's
# ValidateSet needs a literal, so this list can't be single-sourced.
$script:ValidKinds = @('decision', 'verdict', 'surprise', 'landing')

$script:ChevSvg = '<svg class="chev" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>'

# HTML-escape any card-derived text. Order matters: & first, so a literal
# "&lt;" in source becomes "&amp;lt;" not the entity. A trust artifact must
# never let narration (full of &, <, quoted identifiers) break or inject markup.
function ConvertTo-FeedHtmlText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

# Format an ISO ts to a compact, deterministic label. Falls back to the raw
# string when it doesn't parse, so a non-date ts is shown, never swallowed.
function Format-FeedTime {
    param([AllowNull()][string]$Ts)
    if ([string]::IsNullOrWhiteSpace($Ts)) { return '' }
    $dt = [datetime]::MinValue
    $ok = [datetime]::TryParse($Ts, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dt)
    if ($ok) { return $dt.ToString('yyyy-MM-dd HH:mm', [System.Globalization.CultureInfo]::InvariantCulture) }
    return $Ts
}

# Read feed.jsonl into card objects, oldest-first (storage order). Fails LOUD
# on any malformed line: a silently dropped card is worse than a thrown error
# in a feed a developer is trusting to be complete. Missing file -> empty.
function Get-FeedCards {
    param([Parameter(Mandatory)][string]$JsonlPath)
    if (-not (Test-Path -LiteralPath $JsonlPath)) { return @() }
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $lines = [System.IO.File]::ReadAllLines($JsonlPath, $utf8)
    $cards = [System.Collections.Generic.List[object]]::new()
    $n = 0
    foreach ($line in $lines) {
        $n++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "feed.jsonl line ${n} is not valid JSON: $($_.Exception.Message)"
        }
        # Valid JSON that isn't a card object (a bare scalar or array) would
        # otherwise render as a silent blank card — fail loud instead.
        if ($obj -isnot [System.Management.Automation.PSCustomObject]) {
            throw "feed.jsonl line ${n} is not a card object (got '$line')"
        }
        # The punchline is the one mandatory text field (Add-FeedCard enforces it
        # on write); an object line missing it would render a silent blank card.
        if ([string]::IsNullOrWhiteSpace([string]$obj.punchline)) {
            throw "feed.jsonl line ${n} has no punchline (got '$line')"
        }
        $cards.Add($obj)
    }
    , $cards.ToArray()
}

# Render ONE card to its static .entry markup. Every text field is escaped.
function ConvertTo-FeedCardHtml {
    param([Parameter(Mandatory)][object]$Card)

    $skill = ConvertTo-FeedHtmlText ([string]$Card.skill)
    $time = ConvertTo-FeedHtmlText (Format-FeedTime ([string]$Card.ts))
    $punch = ConvertTo-FeedHtmlText ([string]$Card.punchline)
    $kind = [string]$Card.kind
    $kindClass = if ($script:ValidKinds -contains $kind) { $kind } else { '' }

    $layers = @($Card.layers | Where-Object { $null -ne $_ })
    $layerHtml = ''
    $pipHtml = ''
    foreach ($ly in $layers) {
        $label = ConvertTo-FeedHtmlText ([string]$ly.label)
        $body = ConvertTo-FeedHtmlText ([string]$ly.body)
        $layerHtml += '<div class="layer"><div class="layer-inner"><span class="layer-label">' + $label + '</span><p class="layer-body">' + $body + '</p></div></div>'
        $pipHtml += '<span class="pip"></span>'
    }

    $meta = "<div class=`"card-meta`"><span class=`"skill-chip`">$skill</span><span class=`"time`">$time</span></div>"

    if ($layers.Count -eq 0) {
        # punchline-only card: not expandable, no hint, no foot.
        return @"
<article class="entry" data-kind="$kindClass">
  <span class="dot" aria-hidden="true"></span>
  <div class="card">
    <div class="card-head card-head--flat">
      $meta
      <p class="punchline">$punch</p>
    </div>
  </div>
</article>
"@
    }

    @"
<article class="entry" data-kind="$kindClass">
  <span class="dot" aria-hidden="true"></span>
  <div class="card">
    <button type="button" class="card-head" aria-expanded="false">
      $meta
      <p class="punchline">$punch</p>
      <span class="hint">$script:ChevSvg Open</span>
    </button>
    <div class="layers">$layerHtml</div>
    <div class="card-foot" style="display:none">
      <button type="button" class="more-btn"></button>
      <span class="pips">$pipHtml</span>
      <span class="end-marker">&mdash; that's the whole story.</span>
    </div>
  </div>
</article>
"@
}

# Pure projection: cards (oldest-first) -> full html, NEWEST FIRST, by reversing
# storage order. Same input -> byte-identical output (idempotent). No I/O.
function ConvertTo-FeedHtml {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Cards,
        [Parameter(Mandatory)][string]$Template,
        [string]$Branch = '',
        [string]$Title = ''
    )
    $ordered = @($Cards)
    [array]::Reverse($ordered)

    if ($ordered.Count -eq 0) {
        $cardsHtml = '<p class="empty-note">Nothing recorded on this branch yet.</p>'
    } else {
        $cardsHtml = (($ordered | ForEach-Object { ConvertTo-FeedCardHtml $_ }) -join "`n")
    }

    $html = $Template.Replace('<!--FEED_CARDS-->', $cardsHtml)
    $html = $html.Replace('<!--BRANCH-->', (ConvertTo-FeedHtmlText $Branch))
    $html = $html.Replace('<!--TITLE-->', (ConvertTo-FeedHtmlText $Title))
    $html
}

# Stateful append: build the card, append ONE json line (UTF-8, no BOM), then
# regenerate feed.html from the whole jsonl. Append-only — prior lines untouched.
# Single-writer per SpecDir (one agent per branch); no cross-process file lock.
function Add-FeedCard {
    param(
        [Parameter(Mandatory)][string]$SpecDir,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Skill,
        [Parameter(Mandatory)][ValidateSet('decision', 'verdict', 'surprise', 'landing')][string]$Kind,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Punchline,
        [object[]]$Layers = @(),
        [string]$Ts,
        [string]$TemplatePath,
        [string]$Branch = '',
        [string]$Title = ''
    )

    if ([string]::IsNullOrWhiteSpace($Ts)) { $Ts = (Get-Date).ToString('o') }

    $normLayers = @()
    foreach ($ly in $Layers) {
        if ($null -eq $ly) { continue }
        $normLayers += [ordered]@{ label = [string]$ly.label; body = [string]$ly.body }
    }

    $card = [ordered]@{
        skill     = $Skill
        ts        = $Ts
        punchline = $Punchline
        layers    = @($normLayers)
        kind      = $Kind
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)

    # Resolve and read the template BEFORE mutating the durable jsonl: a bad or
    # missing template then throws before anything is persisted, so feed.jsonl
    # and feed.html never disagree on a failed append.
    if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
        $TemplatePath = Join-Path $PSScriptRoot '..' 'references' 'feed.template.html'
    }
    $template = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $TemplatePath), $utf8)

    if (-not (Test-Path -LiteralPath $SpecDir)) {
        New-Item -ItemType Directory -Path $SpecDir -Force | Out-Null
    }
    $jsonlPath = Join-Path $SpecDir 'feed.jsonl'
    # Validate the existing jsonl BEFORE appending: a pre-existing malformed line
    # throws here, before the new card is persisted, so a corrupt prior line can
    # never leave jsonl advanced with feed.html never regenerated.
    $null = Get-FeedCards $jsonlPath
    $line = ($card | ConvertTo-Json -Compress -Depth 8)
    [System.IO.File]::AppendAllText($jsonlPath, $line + "`n", $utf8)

    $cards = Get-FeedCards $jsonlPath
    $html = ConvertTo-FeedHtml -Cards $cards -Template $template -Branch $Branch -Title $Title
    [System.IO.File]::WriteAllText((Join-Path $SpecDir 'feed.html'), $html, $utf8)

    $card
}

Export-ModuleMember -Function ConvertTo-FeedHtmlText, Format-FeedTime, Get-FeedCards, ConvertTo-FeedCardHtml, ConvertTo-FeedHtml, Add-FeedCard
