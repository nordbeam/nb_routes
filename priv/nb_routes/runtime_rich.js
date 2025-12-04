/**
 * Rich Route Runtime
 * Provides runtime helpers for rich route helpers (variant: :rich)
 */

/**
 * Build query string from params object, properly handling arrays
 * @param {Object} params - Query parameters (may include arrays)
 * @returns {string} - Encoded query string
 */
function _buildQueryString(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined) continue;
    if (Array.isArray(value)) {
      // Handle arrays by creating multiple params with the same key
      for (const v of value) {
        if (v !== null && v !== undefined) {
          parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(String(v)));
        }
      }
    } else {
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(String(value)));
    }
  }
  return parts.join('&');
}

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
    const queryString = _buildQueryString(options.query);
    if (queryString) {
      url += (url.includes('?') ? '&' : '?') + queryString;
    }
  } else if (options?.mergeQuery && typeof window !== 'undefined') {
    // Merge with current URL query parameters
    const current = new URLSearchParams(window.location.search);

    for (const [key, value] of Object.entries(options.mergeQuery)) {
      if (value === null || value === undefined) {
        current.delete(key);
      } else if (Array.isArray(value)) {
        // For arrays, delete existing and add all values
        current.delete(key);
        for (const v of value) {
          if (v !== null && v !== undefined) {
            current.append(key, String(v));
          }
        }
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
