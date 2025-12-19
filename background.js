// Background service worker for Holiday Orb Extension
// Handles extension lifecycle and storage

chrome.runtime.onInstalled.addListener(() => {
  console.log('Holiday Orb Extension installed!');
  
  // Set default settings
  chrome.storage.sync.set({
    enabled: true,
    snowflakes: true,
    ornaments: true,
    theme: 'default'
  });
});

// Listen for messages from content scripts
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'getSettings') {
    chrome.storage.sync.get(['enabled', 'snowflakes', 'ornaments', 'theme'], (data) => {
      sendResponse(data);
    });
    return true; // Keep the message channel open for async response
  }
});
