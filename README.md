# Illuminator

A feature-rich Garmin watchface inspired by classic digital watches, built with Connect IQ for Garmin devices.

## Features

### Display Elements

- **World Map** - Real-time world map with day/night overlay based on current sun position
- **Analogue Clock** - Stylish analogue clock display with hour and minute hands
- **Digital Time** - Large digital time display (HH:MM:SS format)
- **Date Display** - Day of week and date in compact format (e.g., "MON 05-02")
- **Goal Meters** - Visual progress bars for steps and floors climbed goals
- **Move Bar** - Inactivity indicator showing movement status

### Configurable Data Fields

The watchface supports up to **6 customizable data fields** across three zones:

| Zone            | Max Fields |
|-----------------|------------|
| Middle (center) | 3          |
| Under time      | 2          |
| Bottom          | 1          |

#### Available Data Fields

| Field               | Description                          | Notes                             |
|---------------------|--------------------------------------|-----------------------------------|
| Heart Rate          | Current heart rate in BPM            | From wrist sensor                 |
| Battery             | Battery percentage with icon         | Visual battery indicator included |
| Battery (No Icon)   | Battery percentage only              | Plain text display                |
| Notifications       | Count of unread notifications        | From connected phone              |
| Calories            | Total calories burned today          | Based on activity tracking        |
| Distance            | Distance traveled today              | In user's preferred units         |
| Alarms              | Number of active alarms              | Device alarms only                |
| Altitude            | Current elevation                    | From barometric sensor            |
| Temperature         | Device temperature                   | Measured at wrist location        |
| Weather Temperature | Current weather temperature          | From Garmin weather service       |
| Pressure            | Barometric pressure                  | Atmospheric pressure reading      |
| Humidity            | Current humidity percentage          | From garmin weather  service      |
| Sunrise             | Today's sunrise time                 | Calculated from last GPS position |
| Sunset              | Today's sunset time                  | Calculated from last GPS position |

## Compatibility
- Round display 454x454 pixels
- Round display 416x416 pixels

## Requirements

- Connect IQ SDK 1.2.0 or higher
- Garmin Connect Mobile app for settings

## Permissions

The watchface requires the following permissions:
- **Sensor** - Heart rate and other sensor data
- **SensorHistory** - Historical sensor readings
- **Positioning** - Location for sunrise/sunset calculations
- **UserProfile** - User activity goals
- **Notifications** - Notification count access
- **Background** - Background processing support

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
monkeyc -d venu2 -f monkey.jungle -o bin/Illuminator.prg -y developer_key.der
```

## Configuration

Access watchface settings through:
1. Garmin Connect Mobile app
2. Navigate to your device → Appearance → Watch Faces
3. Select Illuminator and tap Settings

### Settings Options

- **Number of Data Fields** - Configure how many fields to show in each zone
- **Data Field 1-6** - Select what data to display in each field position

## Project Structure

```
illuminator/
├── source/
│   ├── IlluminatorApp.mc           # Main application entry
│   ├── IlluminatorView.mc          # Watch face view
│   ├── IlluminatorBackground.mc    # Background drawable
│   ├── Analogue.mc                 # Analogue clock component
│   ├── TimeField.mc                # Digital time display
│   ├── DateField.mc                # Date display
│   ├── WorldMap.mc                 # World map with day/night
│   ├── DataFields.mc               # Configurable data fields
│   ├── GoalMeter.mc                # Steps/floors progress bars
│   └── MoveBar.mc                  # Inactivity indicator
├── resources/
│   ├── drawables/                  # Icons and graphics
│   ├── layouts/                    # UI layouts
│   ├── settings/                   # App settings definition
│   └── strings/                    # Localized strings
├── resources-round-416x416/        # Device-specific resources
│   └── fonts/                      # Custom fonts and assets
├── manifest.xml                    # App manifest
└── monkey.jungle                   # Build configuration
```

## Development

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
- [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)

### Building

1. Open the project in VS Code
2. Press `Ctrl+Shift+P` → "Monkey C: Build Current Project"
3. Select target device

### Debugging

Use the Connect IQ Simulator:
1. Press `F5` or use "Monkey C: Run" command
2. Select simulator device

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Inspired by classic Casio digital watch designs
- Built with Garmin Connect IQ SDK


