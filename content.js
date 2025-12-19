// Content script for Holiday Orb Extension
// Injects holiday decorations into GitHub pages

(function() {
  'use strict';

  // Safari compatibility: Use browser API if available, otherwise chrome
  const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

  // Configuration constants
  const SNOWFLAKE_COUNT = 30;
  const CONTRIBUTION_SELECTOR = 'td.ContributionCalendar-day';

  // Create snowflakes animation
  function createSnowflakes() {
    const snowContainer = document.createElement('div');
    snowContainer.id = 'holiday-orb-snow';
    snowContainer.className = 'holiday-orb-snow-container';
    
    // Create snowflakes
    for (let i = 0; i < SNOWFLAKE_COUNT; i++) {
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
    const contributionDays = document.querySelectorAll(CONTRIBUTION_SELECTOR);
    
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
    if (header && !document.querySelector('.holiday-orb-header-decoration')) {
      const decoration = document.createElement('div');
      decoration.className = 'holiday-orb-header-decoration';
      decoration.innerHTML = '🎄 🎅 ⭐ 🎁 ❄️';
      header.appendChild(decoration);
    }
  }

  // Initialize decorations
  function init() {
    browserAPI.runtime.sendMessage({ action: 'getSettings' }, (settings) => {
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
  // Observe only the main content area to reduce overhead
  const observeTarget = document.querySelector('main') || document.body;
  const observer = new MutationObserver((mutations) => {
    // Throttle decoration updates
    let hasContributionChanges = false;
    
    for (const mutation of mutations) {
      if (mutation.type === 'childList') {
        const hasContributions = Array.from(mutation.addedNodes).some(node => 
          node.nodeType === Node.ELEMENT_NODE && 
          (node.matches && node.matches('.js-calendar-graph') || 
           node.querySelector && node.querySelector('.js-calendar-graph'))
        );
        if (hasContributions) {
          hasContributionChanges = true;
          break;
        }
      }
    }
    
    if (hasContributionChanges) {
      decorateContributionGraph();
    }
  });

  observer.observe(observeTarget, {
    childList: true,
    subtree: true
  });
})();
