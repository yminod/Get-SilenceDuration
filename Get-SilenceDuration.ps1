#Requires -Version 7.4

function Format-Hms([double]$Seconds) {
    $span = [timespan]::fromseconds($Seconds)
    return '{0}:{1:00}:{2:00}' -f [math]::Floor($span.TotalHours), $span.Minutes, $span.Seconds
}

function Get-SilenceDuration {
<#
.SYNOPSIS
Detect silence segments in audio files using FFmpeg silencedetect filter.

.DESCRIPTION
This script runs FFmpeg with the silencedetect filter and outputs silence
start time, end time, and duration for each detected silence segment.

Supports both serial and parallel execution. Output includes numeric
seconds for precise processing and human-readable time format for convenience.

.PARAMETER Path
One or more audio file paths. Wildcards are supported.

.PARAMETER ThresholdDbfs
Silence threshold in dBFS. Default is -60.0.

.PARAMETER MinDuration
Minimum silence duration in seconds. Default is 1.0.

.PARAMETER ChannelSeparation
Detect silence independently for each channel.

.PARAMETER Serial
Force serial execution. Default is parallel.

.PARAMETER ThrottleLimit
Maximum number of parallel FFmpeg processes. Default is 5.

.EXAMPLE
Get-SilenceDuration *.wav -Serial

Detect silence in all WAV files in serial mode.

.EXAMPLE
Get-ChildItem *.wav | Get-SilenceDuration | Export-Csv -NoTypeInformation -Encoding utf8BOM -UseQuotes AsNeeded .\silence.csv

Detect silence from pipeline input and export results to (Excel compatible) CSV.

.OUTPUTS
System.Management.Automation.PSCustomObject

Properties:

Name        File name
StartSec    Silence start time in seconds
EndSec      Silence end time in seconds
DurationSec Silence duration in seconds
StartHMS    Human readable start time
EndHMS      Human readable end time

.NOTES
Requires FFmpeg to be installed and available in PATH.

Designed for PowerShell 7.4+.

.LINK
https://ffmpeg.org/ffmpeg-filters.html#silencedetect
#>
    [CmdletBinding()]
    param (
        [Parameter(
             Mandatory,
             ValueFromPipeline,
             ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]$Path,

        [double]$ThresholdDbfs = -60.0,
        [double]$MinDuration = 1.0,
        [switch]$ChannelSeparation,

        [switch]$Serial,
        [int]$ThrottleLimit = 5,

        [int]$InitialFileCount = 128
    )
    begin {
        try { $null = Get-Command ffmpeg -ErrorAction Stop }
        catch { throw "ffmpeg not found in PATH." }

        # Defaults to $null if the variable is missing.
        $avLogForceNoColor = $Env:AV_LOG_FORCE_NOCOLOR

        $files = [Collections.Generic.List[string]]::new($InitialFileCount)
    }
    process {
        foreach ($p in $Path) {
            foreach ($r in Resolve-Path -Path $p -ErrorAction Stop) {
                $files.Add($r.Path)
            }
        }
    }
    end {
        $sbTemplate = @'
$source = $_
$lines = & ffmpeg `
  -hide_banner `
  -nostats `
  -i $source `
  -af ('silencedetect=' `
  + "noise={0}dB:" `
  + "duration={1}:" `
  + "mono=$(if ({2}) {{ 1 }} else {{ 0 }})") `
  -f null - 2>&1

{3}

$beg = $null
$begHms = $null
$end = $null
$endHms = $null
$dur = $null

switch -CaseSensitive -Regex ($lines) {{
    'silence_start: ([.0-9]+)$' {{
        $beg = [math]::Floor([double]$Matches[1] * 100) / 100
        $begHms = Format-Hms $beg

        $end = $null
        $endHms = $null
        $dur = $null
    }}
    'silence_end: ([.0-9]+) \| silence_duration: ([.0-9]+)$' {{
        $end = [math]::Floor([double]$Matches[1] * 100) / 100
        $endHms = Format-Hms $end
        $dur = [math]::Floor([double]$Matches[2] * 100) / 100

        [pscustomobject]@{{
            'Name' = Split-Path -Path $source -Leaf
            'StartSec' = $beg
            'EndSec' = $end
            'StartHMS' = $begHms
            'EndHMS' = $endHms
            'DurationSec' = $dur
        }}

        $beg = $null
        $begHms = $null
        $end = $null
        $endHms = $null
        $dur = $null
    }}
}}
'@

        try {
            # Disable ANSI color codes for clean output.
            $Env:AV_LOG_FORCE_NOCOLOR = 1

            # Apply [Globalization.CultureInfo]::InvariantCulture.
            $thresholdStr = [string]$ThresholdDbfs
            $minDurationStr = [string]$MinDuration

            if ($Serial) {
                $files | ForEach-Object `
                  -Process ([scriptblock]::Create(
                                ($sbTemplate -f
                                 '${thresholdStr}',
                                 '${minDurationStr}',
                                 '$ChannelSeparation',
                                 '')))
            }
            else {
                $formatHmsFunction =  [string]${function:Format-Hms}
                $files | ForEach-Object -ThrottleLimit $ThrottleLimit `
                  -Parallel ([scriptblock]::Create(
                                 ($sbTemplate -f
                                  '${using:thresholdStr}',
                                  '${using:minDurationStr}',
                                  '${using:ChannelSeparation}',
                                  '${function:Format-Hms} = ${using:formatHmsFunction}')))
            }
        }
        finally {
            if ($avLogForceNoColor -eq $null) {
                Remove-Item Env:AV_LOG_FORCE_NOCOLOR -ErrorAction SilentlyContinue
            } else {
                $Env:AV_LOG_FORCE_NOCOLOR = $avLogForceNoColor
            }
        }
    }
}
