#!/usr/bin/env pwsh

[CmdletBinding()]
param ()

# 本サイトは消えているためアーカイブサイト
$RengokuDomain = "http://web.archive.org" 
$RengokuRoot = "/web/20190113060708/http://www.rengoku-teien.com"
$MIDIRoot = "$RengokuRoot/midi/"
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
        Write-Debug ($XG | ConvertTo-Json)
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
("xg", $XGMIDIs), ("gm", $GMMIDIs) | ForEach-Object {
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

# $MIDIs = $GenrePages | ForEach-Object {
#     (Invoke-WebRequest "$RengokuDomain$_").Links.Href | Where-Object {
#         ($_ -like "*.mid") # -and -not ( $_ -like "*_gm.mid")
#     }
# }

# HACK: https://web.archive.org/web/(日付)if_/http:// とすると直接ダウンロード可能
# $MIDIs -replace "/http","if_/http" | ForEach-Object { (Invoke-WebRequest "$RengokuDomain$MIDIRoot$_") }