#!/usr/bin/env pwsh

[CmdletBinding()]
param ([switch]$GMOnly, [switch]$XGOnly)

if ($XGOnly -and $GMOnly) {
    Write-Error "フラグ -XGOnly と -GMOnly は同時に指定できません" -Category InvalidArgument
    exit 1
}

# 本サイトは消えているためアーカイブサイト
$RengokuDomain = "http://web.archive.org" 
$RengokuRoot = "/web/20190113060708/http://www.rengoku-teien.com"
$MIDIRoot = "$RengokuRoot/midi/"
# HACK: https://web.archive.org/web/(日付)if_/http:// とすると直接ダウンロード可能
$MIDIDLRoot = $MIDIRoot -replace "/(https?://)", 'if_/$1'

$RulePage = Invoke-WebRequest "$RengokuDomain$RengokuRoot/rule/index.html"
$GenrePages = $RulePage.Links.Href | Where-Object { $_ -like "*/midi/*.html" }
$MIDIPages = @{ }
$GenrePages | ForEach-Object {
    $PageName = $_ -replace "^.+/", ""
    $Genre = $PageName -replace "\.[^.]+", ""
    $SubPages = (Invoke-WebRequest "$RengokuDomain$_").Links.Href | Where-Object { $_ -match "[0-9]+\.html$" }
    if ($MIDIPages.ContainsKey($Genre)) {
        $MIDIPages[$Genre] = ($MIDIPages[$Genre] + $SubPages) | Sort-Object -Unique
    }
    else {
        $MIDIPages.Add($Genre , @($PageName) + $SubPages)
    }
}
$XGMIDIs = @{ }
$GMMIDIs = @{ }
$MIDIPages.Keys | ForEach-Object {
    $Genre = $_
    $MIDIPages[$_] | ForEach-Object {
        $MIDIs = (Invoke-WebRequest "$RengokuDomain$MIDIRoot$_").Links.Href | Where-Object {
            $_ -like "*.mid"
        }
        $GM = $MIDIs | Where-Object { $_ -like "*_gm.mid" }
        $XG = $MIDIs | Where-Object { -not ($_ -like "*_gm.mid") }
        if ($XGMIDIs.ContainsKey($Genre)) {
            $XGMIDIs[$Genre] = ($XGMIDIs[$Genre] + $XG) | Sort-Object -Unique
            $GMMIDIs[$Genre] = ($GMMIDIs[$Genre] + $GM) | Sort-Object -Unique
        }
        else {
            $XGMIDIs.Add($Genre, $XG)
            $GMMIDIs.Add($Genre, $GM)
        }
    }
}
$Matrix = @()
if (-not $GMOnly) {
    # HACK: 「,」がないと配列の配列にならない
    $Matrix += , ("xg", $XGMIDIs)
}
if (-not $XGOnly) {
    $Matrix += , ("gm", $GMMIDIs)
}
$Matrix | ForEach-Object {
    $Type = $_[0]
    $MIDIs = $_[1]
    New-Item -ItemType Directory -Force -Name $Type > $null
    $_[1].Keys | ForEach-Object {
        $DestGenre = "$Type\$_"
        New-Item -ItemType Directory -Force $DestGenre > $null
        $MIDIs[$_] | ForEach-Object {
            $DestMIDI = "$DestGenre\$($_ -replace '.+/','')"
            if (-not (Test-Path $DestMIDI)) {
                Invoke-WebRequest "$RengokuDomain$MIDIDLRoot$_" -OutFile $DestMIDI
                Write-Debug "Downloaded: $DestMIDI"
            }
            else {
                Write-Debug "Skipped: $DestMIDI"
            }
        }
    }
}
