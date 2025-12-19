// Popup JavaScript for Holiday Orb Extension

// Safari compatibility: Use browser API if available, otherwise chrome
const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

document.addEventListener('DOMContentLoaded', () => {
  // Load saved settings
  browserAPI.storage.sync.get(['enabled', 'snowflakes', 'ornaments'], (data) => {
    document.getElementById('enabled').checked = data.enabled !== false;
    document.getElementById('snowflakes').checked = data.snowflakes !== false;
    document.getElementById('ornaments').checked = data.ornaments !== false;
  });

  // Save settings on button click
  document.getElementById('save').addEventListener('click', () => {
    const settings = {
      enabled: document.getElementById('enabled').checked,
      snowflakes: document.getElementById('snowflakes').checked,
      ornaments: document.getElementById('ornaments').checked
    };

    browserAPI.storage.sync.set(settings, () => {
      // Show status message
      const status = document.getElementById('status');
      status.textContent = 'Settings saved! Refresh GitHub to see changes.';
      status.classList.add('show');
      
      setTimeout(() => {
        status.classList.remove('show');
      }, 3000);

      // Reload all GitHub tabs to apply new settings
      browserAPI.tabs.query({ url: 'https://github.com/*' }, (tabs) => {
        tabs.forEach((tab) => {
          browserAPI.tabs.reload(tab.id);
        });
      });
    });
  });

  // Auto-save on checkbox change
  ['enabled', 'snowflakes', 'ornaments'].forEach((id) => {
    document.getElementById(id).addEventListener('change', () => {
      document.getElementById('save').click();
    });
  });
});
