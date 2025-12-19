// Background service worker for Holiday Orb Extension
// Handles extension lifecycle and storage

// Safari compatibility: Use browser API if available, otherwise chrome
const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

browserAPI.runtime.onInstalled.addListener(() => {
  console.log('Holiday Orb Extension installed!');
  
  // Set default settings
  browserAPI.storage.sync.set({
    enabled: true,
    snowflakes: true,
    ornaments: true,
    theme: 'default'
  });
});

// Listen for messages from content scripts
browserAPI.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'getSettings') {
    browserAPI.storage.sync.get(['enabled', 'snowflakes', 'ornaments', 'theme'], (data) => {
      sendResponse(data);
    });
    return true; // Keep the message channel open for async response
  }
});
