# Illuminator

A feature-rich Garmin watchface inspired by classic digital watches, built with Connect IQ for Garmin devices.

## Features

### Display Elements

- **World Map** - Real-time world map with day/night overlay based on the current sun position (sunrise/sunset edge plus a civil-twilight band)
- **Analogue Clock** - Analogue clock with hour and minute hands, optionally in a second time zone
- **Digital Time** - Large digital time display (HH:MM, seconds optional)
- **Date Display** - Day of week and date in compact format (e.g., "MON 05-02")
- **Goal Meters** - Visual progress bars for steps and floors climbed goals
- **Move Bar** - Inactivity indicator showing movement status
- **Always-On Mode** - Dimmed time, date, analogue hands and day-side map, shifted every minute for burn-in protection (≈8 % of pixels lit, Garmin's limit is 10 %)

### Configurable Data Fields

The watchface supports up to **6 customizable data fields** across three zones:

| Zone            | Max Fields |
|-----------------|------------|
| Middle (center) | 3          |
| Under time      | 2          |
| Bottom          | 1          |

#### Available Data Fields

| Field               | Description                          | Notes                                         |
|---------------------|--------------------------------------|-----------------------------------------------|
| Heart Rate          | Current heart rate in BPM            | From wrist sensor, updated every second       |
| Battery             | Battery percentage with icon         | Visual battery indicator included             |
| Battery (No Icon)   | Battery percentage only              | Plain text display (bottom field)             |
| Notifications       | Count of unread notifications        | From connected phone                          |
| Calories            | Total calories burned today          | Based on activity tracking                    |
| Distance            | Distance traveled today              | In user's preferred units                     |
| Alarms              | Number of active alarms              | Device alarms only                            |
| Altitude            | Current elevation                    | Metres or feet, following the watch setting   |
| Weather Temperature | Current weather temperature          | From Garmin weather service                   |
| Pressure            | Barometric pressure                  | Latest barometer sample, hPa                  |
| Humidity            | Current humidity percentage          | From Garmin weather service                   |
| Sunrise             | Next sunrise time                    | Computed on the watch from the last location  |
| Sunset              | Next sunset time                     | Computed on the watch from the last location  |

Sunrise/sunset shows `24h` during polar day and `0h` during polar night. The location comes from Garmin weather (follows the phone), the last GPS activity, or the last stored value, checked about once an hour.

## Compatibility

All supported devices are round AMOLED watches with Connect IQ 5.x:

| Resolution | Devices |
|------------|---------|
| 454x454 | Venu 3, Venu 4 45mm, epix Pro (Gen 2) 51mm, fēnix 8 47/51mm, fēnix 8 Pro, Forerunner 965 / 970 / 570 47mm, Approach S70 47mm, D2 Mach 2, Descent Mk3i 51mm |
| 416x416 | Venu 2 / 2 Plus, epix (Gen 2), epix Pro (Gen 2) 47mm, fēnix 8 43mm, fēnix E, Forerunner 265, Instinct 3 AMOLED 50mm, D2 Air X10, D2 Mach 1 |
| 390x390 | Venu 3S, Venu 4 41mm, vívoactive 5 / 6, Forerunner 165 / 165 Music / 570 42mm, epix Pro (Gen 2) 42mm, MARQ (Gen 2) / MARQ Aviator (Gen 2), Instinct 3 AMOLED 45mm, Approach S70 42mm, Descent Mk3 43mm, Descent G2 |

Resources are picked automatically by folder name (`resources-round-WxH`). The 390x390 set is generated from the 416x416 set with `tools/scale_resources.py`.

## Requirements

- Connect IQ API level 4.0.0 or higher on the device (all supported devices run 5.x)
- Connect IQ SDK 8.x for building
- Garmin Connect Mobile app for settings

## Permissions

The watchface requires the following permissions:
- **SensorHistory** - Barometric pressure (heart rate comes from activity info and needs no permission)
- **Positioning** - Last known location for sunrise/sunset
- **Notifications** - Notification count

## Installation

### From Connect IQ Store
[Illuminator](https://apps.garmin.com/apps/6bb094b0-7984-487a-a3c4-1e582c6a4ba4)

### Manual Installation (Development)

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
2. Clone this repository
3. Open in VS Code with Monkey C extension
4. Build and deploy to your device or simulator

```bash
# Build the project
monkeyc -d venu2 -f monkey.jungle -o bin/Casio.prg -y developer_key.der
```

## Configuration

Access watchface settings through:
1. Garmin Connect Mobile app
2. Navigate to your device → Appearance → Watch Faces
3. Select Illuminator and tap Settings

Changes are applied immediately, without restarting the watch face.

### Settings Options

- **Analogue Clock Timezone** - Local time, UTC, or a fixed UTC offset for the analogue clock (no DST)
- **Show Seconds** - Show or hide the seconds next to the digital time (never shown in always-on mode)
- **Number of Data Fields** - Configure how many fields to show in each zone
- **Data Field 1-6** - Select what data to display in each field position

## Project Structure

```
illuminator/
├── source/
│   ├── IlluminatorApp.mc           # Application entry, settings changes
│   ├── IlluminatorView.mc          # Watch face view, always-on mode, debug diagnostics
│   ├── AodFace.mc                  # Always-on time and date
│   ├── WorldMap.mc                 # World map with day/night overlay (bitmap cached)
│   ├── Analogue.mc                 # Analogue clock (tile-font dial and hands)
│   ├── TimeField.mc                # Digital time display
│   ├── DateField.mc                # Date display
│   ├── DataFields.mc               # Configurable data fields, sunrise/sunset
│   ├── GoalMeter.mc                # Steps/floors progress bars
│   ├── MoveBar.mc                  # Inactivity indicator
│   ├── Res.mc                      # Shared fonts, loaded once
│   ├── Cache.mc                    # Per-minute device settings and activity data
│   └── Loc.mc                      # Last known location
├── resources/                      # Common: drawables, settings, strings
├── resources-round-454x454/        # 454x454 fonts, tile art and layouts
├── resources-round-416x416/        # 416x416 fonts, tile art and layouts
├── resources-round-390x390/        # 390x390 (generated from 416x416)
├── tools/scale_resources.py        # Regenerates a scaled resource folder
├── docs/                           # Analysis and task list
├── manifest.xml                    # App manifest
└── monkey.jungle                   # Build configuration
```

## Development

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
- [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
- Python 3 with Pillow (only for `tools/scale_resources.py`)

### Building

1. Open the project in VS Code
2. Press `Ctrl+Shift+P` → "Monkey C: Build Current Project"
3. Select target device

### Debugging

Use the Connect IQ Simulator:
1. Press `F5` or use "Monkey C: Run" command
2. Select simulator device

Debug builds log memory and battery once an hour (`System.println`); on a sideloaded watch this goes to `GARMIN\APPS\LOGS\<PRG NAME>.TXT` if that file exists. Release builds don't contain this code.

### Regenerating the 390x390 resources

After changing the 416x416 art or layout:

```bash
python tools/scale_resources.py resources-round-416x416 resources-round-390x390 390
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Inspired by classic Casio digital watch designs
- Built with Garmin Connect IQ SDK
