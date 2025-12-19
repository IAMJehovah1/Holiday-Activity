# Holiday Orb - Safari Extension

A festive Safari Web Extension that decorates your GitHub Activity Overview with holiday cheer! 🎄

## Features

- ❄️ **Animated Snowflakes**: Beautiful falling snowflakes across GitHub pages
- 🎁 **Contribution Graph Effects**: Festive glow effects on your contribution calendar
- 🎅 **Header Decorations**: Holiday emojis to brighten your browsing
- ⚙️ **Customizable Settings**: Toggle effects on/off through the extension popup

## Installation

### For Safari on macOS

1. Open Safari and enable Developer mode:
   - Go to Safari → Preferences → Advanced
   - Check "Show Develop menu in menu bar"

2. Load the extension:
   - Go to Develop → Allow Unsigned Extensions
   - Go to Safari → Preferences → Extensions
   - Click "+" and select the extension folder

### For Distribution (App Store)

This extension can be packaged using Xcode:

1. Open Xcode and create a new Safari Web Extension project
2. Copy the extension files into the project
3. Build and distribute through App Store Connect

## Files Structure

```
Holiday-Activity/
├── manifest.json          # Extension configuration
├── background.js          # Service worker for extension lifecycle
├── content.js            # Main script that decorates GitHub pages
├── styles.css            # CSS for decorations and animations
├── popup/
│   ├── popup.html        # Extension popup interface
│   ├── popup.css         # Popup styling
│   └── popup.js          # Popup functionality
└── icons/
    ├── icon16.png        # 16x16 icon
    ├── icon32.png        # 32x32 icon
    ├── icon48.png        # 48x48 icon
    └── icon128.png       # 128x128 icon
```

## Usage

1. Navigate to any GitHub page
2. Click the Holiday Orb extension icon in Safari's toolbar
3. Toggle the decorations you want to enable/disable
4. Settings are automatically saved and applied

## Development

The extension uses:
- **Manifest V3**: Modern extension API
- **Service Worker**: Background processing
- **Content Scripts**: DOM manipulation for GitHub
- **Chrome Storage API**: Persistent settings

## Credits

Repository was created by [Working Copy](https://workingcopy.app/?ct=holiday) to decorate the GitHub Activity Overview.
