# Installation Guide for Holiday Orb Safari Extension

## Quick Start Guide

### Prerequisites
- macOS with Safari 14 or later
- Safari Developer mode enabled

### Step-by-Step Installation

#### 1. Enable Safari Developer Mode

1. Open Safari
2. Go to **Safari** → **Preferences** (or press `⌘,`)
3. Click the **Advanced** tab
4. Check the box: **"Show Develop menu in menu bar"**
5. Close Preferences

#### 2. Allow Unsigned Extensions (for Development)

1. In Safari's menu bar, click **Develop**
2. Select **"Allow Unsigned Extensions"**
   - You'll need to authenticate with your password
   - This needs to be done each time you restart Safari

#### 3. Load the Extension

##### Option A: Load from GitHub (Recommended)

1. Clone or download this repository:
   ```bash
   git clone https://github.com/IAMJehovah1/Holiday-Activity.git
   cd Holiday-Activity
   ```

2. In Safari, go to **Safari** → **Preferences** → **Extensions**

3. Click the **"+"** button at the bottom left

4. Navigate to the `Holiday-Activity` folder and select it

5. Click **"Select Folder"**

6. The extension should now appear in your Extensions list

7. Make sure it's enabled by checking the box next to its name

##### Option B: Use Safari Web Extension Converter

If you want to package it as a proper Safari extension:

1. Install Xcode from the Mac App Store (if not already installed)

2. Open Terminal and run:
   ```bash
   xcrun safari-web-extension-converter /path/to/Holiday-Activity
   ```

3. Follow the prompts to create an Xcode project

4. Open the generated project in Xcode

5. Build and run the project (⌘R)

6. Safari will launch with the extension installed

#### 4. Grant Permissions

1. When you first visit GitHub.com, Safari will ask if you want to allow the extension
2. Click **"Always Allow on github.com"** for the best experience

#### 5. Test the Extension

1. Navigate to https://github.com
2. You should see:
   - ❄️ Snowflakes falling across the page
   - 🎄 Holiday emojis in the header
   - ✨ Glow effects on your contribution graph (if viewing a profile)

3. Click the extension icon in Safari's toolbar to access settings

## Customization

### Using the Extension Popup

1. Click the Holiday Orb icon in Safari's toolbar
2. Toggle features on/off:
   - **Enable Decorations**: Master on/off switch
   - **Snowflakes**: Toggle falling snow animation
   - **Ornaments & Effects**: Toggle contribution graph and header decorations
3. Changes are saved automatically
4. Refresh GitHub pages to see updates

## Troubleshooting

### Extension Not Appearing

- Make sure Developer mode is enabled
- Ensure "Allow Unsigned Extensions" is active
- Try restarting Safari

### Decorations Not Showing

- Check that the extension is enabled in Safari → Preferences → Extensions
- Make sure you've granted permissions for github.com
- Click the extension icon and verify settings are enabled
- Try refreshing the GitHub page

### Performance Issues

- If you experience slowdown, try disabling snowflakes (more CPU intensive)
- The extension only runs on GitHub domains for optimal performance

## Uninstalling

1. Go to Safari → Preferences → Extensions
2. Select "Holiday Orb - GitHub Activity Decorator"
3. Click the **Uninstall** button
4. Confirm the removal

## For Developers

### File Structure
```
Holiday-Activity/
├── manifest.json       # Extension configuration (Manifest V3)
├── background.js       # Service worker for lifecycle events
├── content.js         # Main content script (injected into GitHub)
├── styles.css         # CSS for decorations and animations
├── popup/            # Extension popup UI
│   ├── popup.html
│   ├── popup.css
│   └── popup.js
└── icons/           # Extension icons
    ├── icon16.png
    ├── icon32.png
    ├── icon48.png
    └── icon128.png
```

### Development Tips

- Edit files directly and reload the extension in Safari Preferences
- Use Safari's Web Inspector to debug (Develop → Show Extension Background Pages)
- Check console for error messages
- The extension uses both `browser` and `chrome` APIs for compatibility

### Testing Changes

1. Make changes to extension files
2. In Safari Preferences → Extensions, click the extension
3. Click "Reload" or disable/enable the extension
4. Refresh GitHub pages to see changes

## Support

For issues, questions, or contributions, please visit:
https://github.com/IAMJehovah1/Holiday-Activity

---

**Happy Holidays!** 🎄 Enjoy your festive GitHub experience! ❄️
