/**
 * Rich Route Runtime
 * Provides runtime helpers for rich route helpers (variant: :rich)
 */

/**
 * Build URL from pattern and parameters
 * @param {string} pattern - Route pattern with :param placeholders
 * @param {Object} params - Parameter values
 * @param {Object} options - Options for query params, anchor, etc
 * @returns {string} - Built URL
 */
function _buildUrl(pattern, params, options) {
  let url = pattern;

  // Replace path parameters
  for (const [key, value] of Object.entries(params || {})) {
    url = url.replace(`:${key}`, String(value));
  }

  // Handle query parameters
  if (options?.query) {
    const queryString = new URLSearchParams(options.query).toString();
    if (queryString) {
      url += (url.includes('?') ? '&' : '?') + queryString;
    }
  } else if (options?.mergeQuery && typeof window !== 'undefined') {
    // Merge with current URL query parameters
    const current = new URLSearchParams(window.location.search);

    for (const [key, value] of Object.entries(options.mergeQuery)) {
      if (value === null || value === undefined) {
        current.delete(key);
      } else {
        current.set(key, String(value));
      }
    }

    const queryString = current.toString();
    if (queryString) {
      url += (url.includes('?') ? '&' : '?') + queryString;
    }
  }

  // Handle anchor/hash
  if (options?.anchor) {
    url += '#' + options.anchor;
  }

  return url;
}
