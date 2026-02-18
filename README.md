# Get-SilenceDuration

Detect silence segments in audio files using FFmpeg's `silencedetect` filter.

Get-SilenceDuration is a PowerShell script that analyzes audio files and outputs the start time, end time, and duration of each detected silence segment.

---

## Requirements

* PowerShell 7.4 or later
* FFmpeg installed and available in PATH

You can verify FFmpeg installation:

```powershell
ffmpeg -version
```

---

## Usage

### Basic

Detect silence in all WAV files:

```powershell
Get-SilenceDuration *.wav
```

### Serial execution

```powershell
Get-SilenceDuration *.wav -Serial
```

### Pipeline input

```powershell
Get-ChildItem *.wav | Get-SilenceDuration
```

### Export to CSV (Excel-compatible UTF-8 with BOM)

```powershell
Get-SilenceDuration *.wav |
Export-Csv silence.csv -NoTypeInformation -Encoding utf8BOM
```

---

## Output

Each detected silence segment produces an object with the following properties:

| Property    | Description                   |
| ----------- | ----------------------------- |
| Name        | File name                     |
| StartSec    | Silence start time (seconds)  |
| EndSec      | Silence end time (seconds)    |
| DurationSec | Silence duration (seconds)    |
| StartHMS    | Silence start time (H:MM:SS)  |
| EndHMS      | Silence end time (H:MM:SS)    |

Numeric values are suitable for precise processing, while HMS values are convenient for human inspection.

---

## Features

* Fast parallel processing using multiple FFmpeg workers
* Supports wildcard and pipeline input
* Outputs timestamps in an Excel-friendly numeric format

---

## License

Apache License 2.0

See LICENSE file for details.
