// Content script for Holiday Orb Extension
// Injects holiday decorations into GitHub pages

(function() {
  'use strict';

  // Create snowflakes animation
  function createSnowflakes() {
    const snowContainer = document.createElement('div');
    snowContainer.id = 'holiday-orb-snow';
    snowContainer.className = 'holiday-orb-snow-container';
    
    // Create 30 snowflakes
    for (let i = 0; i < 30; i++) {
      const snowflake = document.createElement('div');
      snowflake.className = 'holiday-orb-snowflake';
      snowflake.innerHTML = '❄';
      snowflake.style.left = Math.random() * 100 + '%';
      snowflake.style.animationDelay = Math.random() * 10 + 's';
      snowflake.style.animationDuration = (Math.random() * 3 + 7) + 's';
      snowflake.style.fontSize = (Math.random() * 10 + 10) + 'px';
      snowflake.style.opacity = Math.random() * 0.6 + 0.4;
      snowContainer.appendChild(snowflake);
    }
    
    document.body.appendChild(snowContainer);
  }

  // Add holiday orb decorations to contribution graph
  function decorateContributionGraph() {
    const contributionDays = document.querySelectorAll('td.ContributionCalendar-day');
    
    contributionDays.forEach((day) => {
      const level = day.getAttribute('data-level');
      if (level && parseInt(level) > 0) {
        // Add a subtle glow effect to active contribution days
        day.style.boxShadow = '0 0 3px rgba(255, 215, 0, 0.5)';
      }
    });
  }

  // Add festive header decoration
  function addHeaderDecoration() {
    const header = document.querySelector('header');
    if (header) {
      const decoration = document.createElement('div');
      decoration.className = 'holiday-orb-header-decoration';
      decoration.innerHTML = '🎄 🎅 ⭐ 🎁 ❄️';
      header.appendChild(decoration);
    }
  }

  // Initialize decorations
  function init() {
    chrome.runtime.sendMessage({ action: 'getSettings' }, (settings) => {
      if (settings.enabled) {
        if (settings.snowflakes) {
          createSnowflakes();
        }
        if (settings.ornaments) {
          decorateContributionGraph();
          addHeaderDecoration();
        }
      }
    });
  }

  // Wait for DOM to be fully loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Re-apply decorations when navigating (GitHub is a SPA)
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === 'childList') {
        decorateContributionGraph();
      }
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
