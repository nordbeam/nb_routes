/**
 * NbRoutes Runtime Library
 *
 * This runtime library is embedded in the generated route helpers to build URLs
 * from route specifications at runtime.
 */

/**
 * Configuration for route generation
 */
class RouteConfig {
  constructor(options = {}) {
    this.defaultUrlOptions = options.defaultUrlOptions || {};
    this.trailingSlash = options.trailingSlash !== undefined ? options.trailingSlash : false;
  }

  configure(options) {
    Object.assign(this, options);
  }
}

/**
 * Main route builder class
 */
class RouteBuilder {
  constructor(config = {}) {
    this.config = new RouteConfig(config);
  }

  /**
   * Creates a route helper function
   *
   * @param {Object} params - Parameter definitions { paramName: { required: true } | { default: value } }
   * @param {Array} spec - Route specification tree
   * @param {boolean} absolute - Whether to generate absolute URLs
   * @returns {Function} Route helper function
   */
  route(params, spec, absolute = false) {
    const self = this;

    const helper = function(...args) {
      return self.buildPath(params, spec, args, absolute);
    };

    // Add introspection methods
    helper.requiredParams = () => {
      return Object.keys(params).filter(key => params[key].required === true);
    };

    helper.toString = () => {
      return self.specToString(spec);
    };

    return helper;
  }

  /**
   * Builds a path from the route specification and arguments
   */
  buildPath(paramDefs, spec, args, absolute) {
    const { params, options } = this.extractArgs(paramDefs, args);

    // Validate required parameters
    this.validateRequiredParams(paramDefs, params);

    // Build the path from spec
    let path = this.evaluateSpec(spec, params, options);

    // Apply trailing slash if configured
    if (this.config.trailingSlash && !path.endsWith('/')) {
      path += '/';
    }

    // Add query string for unused parameters
    const queryString = this.buildQueryString(params, options);
    if (queryString) {
      path += '?' + queryString;
    }

    // Add anchor if provided
    if (options.anchor) {
      path += '#' + encodeURIComponent(options.anchor);
    }

    // Build absolute URL if requested
    if (absolute) {
      path = this.buildAbsoluteUrl(path, options);
    }

    return path;
  }

  /**
   * Extracts parameters and options from function arguments
   */
  extractArgs(paramDefs, args) {
    const params = {};
    const options = {};
    const requiredParams = Object.keys(paramDefs).filter(k => paramDefs[k].required);

    // Handle different argument patterns:
    // 1. route(id, options) - positional params + options object
    // 2. route(options) - options object with params
    // 3. route(id) - positional params only

    if (args.length === 0) {
      // No arguments - use defaults
      Object.keys(paramDefs).forEach(key => {
        if (paramDefs[key].default !== undefined) {
          params[key] = paramDefs[key].default;
        }
      });
    } else if (args.length === 1 && typeof args[0] === 'object' && args[0] !== null) {
      // Single object argument - could be all params or options
      const obj = args[0];

      Object.keys(paramDefs).forEach(key => {
        if (obj[key] !== undefined) {
          params[key] = obj[key];
        } else if (paramDefs[key].default !== undefined) {
          params[key] = paramDefs[key].default;
        }
      });

      // Remaining keys are query params or options
      Object.keys(obj).forEach(key => {
        if (!paramDefs[key] && key !== 'anchor' && key !== 'format' && key !== 'trailing_slash') {
          options[key] = obj[key];
        } else if (key === 'anchor' || key === 'trailing_slash') {
          options[key] = obj[key];
        }
      });
    } else {
      // Positional arguments
      requiredParams.forEach((key, index) => {
        if (index < args.length) {
          params[key] = args[index];
        }
      });

      // Last argument might be options object
      const lastArg = args[args.length - 1];
      if (typeof lastArg === 'object' && lastArg !== null && args.length > requiredParams.length) {
        Object.assign(options, lastArg);

        // Extract any params from options
        Object.keys(paramDefs).forEach(key => {
          if (lastArg[key] !== undefined) {
            params[key] = lastArg[key];
          }
        });
      }

      // Apply defaults
      Object.keys(paramDefs).forEach(key => {
        if (params[key] === undefined && paramDefs[key].default !== undefined) {
          params[key] = paramDefs[key].default;
        }
      });
    }

    return { params, options };
  }

  /**
   * Validates that all required parameters are provided
   */
  validateRequiredParams(paramDefs, params) {
    const missing = Object.keys(paramDefs)
      .filter(key => paramDefs[key].required && params[key] === undefined);

    if (missing.length > 0) {
      throw new Error(`Missing required parameter(s): ${missing.join(', ')}`);
    }
  }

  /**
   * Evaluates a route specification tree to build the path
   */
  evaluateSpec(spec, params, options) {
    const usedParams = new Set();
    const path = this._evaluateNode(spec, params, options, usedParams);

    // Mark used params so they're not added to query string
    usedParams.forEach(key => delete params[key]);

    return path;
  }

  _evaluateNode(node, params, options, usedParams) {
    if (typeof node === 'string') {
      // Literal string
      return node;
    }

    if (Array.isArray(node)) {
      if (node.length === 0) {
        return '';
      }

      const [type, ...rest] = node;

      switch (type) {
        case 'param': {
          const [paramName] = rest;
          usedParams.add(paramName);
          const value = params[paramName];
          if (value === undefined) {
            return '';
          }
          return encodeURIComponent(String(value));
        }

        case 'glob': {
          const [paramName] = rest;
          usedParams.add(paramName);
          const value = params[paramName];
          if (value === undefined) {
            return '';
          }
          // Glob params are not encoded (they can contain /)
          return String(value);
        }

        case 'optional': {
          const [parts] = rest;
          // Optional parts are only included if all their params are present
          const allParamsPresent = this._checkOptionalParams(parts, params);
          if (!allParamsPresent) {
            return '';
          }
          return parts.map(part => this._evaluateNode(part, params, options, usedParams)).join('');
        }

        default:
          // Array of nodes - concatenate
          return node.map(n => this._evaluateNode(n, params, options, usedParams)).join('');
      }
    }

    return '';
  }

  /**
   * Checks if all parameters in an optional segment are present
   */
  _checkOptionalParams(parts, params) {
    for (const part of parts) {
      if (Array.isArray(part) && part[0] === 'param') {
        const paramName = part[1];
        if (params[paramName] === undefined) {
          return false;
        }
      }
    }
    return true;
  }

  /**
   * Builds query string from remaining parameters
   */
  buildQueryString(params, options) {
    const pairs = [];

    Object.keys(params).forEach(key => {
      if (params[key] !== undefined) {
        pairs.push(
          encodeURIComponent(key) + '=' + encodeURIComponent(String(params[key]))
        );
      }
    });

    // Add options that are not special keys
    Object.keys(options).forEach(key => {
      if (key !== 'anchor' && key !== 'trailing_slash' && options[key] !== undefined) {
        pairs.push(
          encodeURIComponent(key) + '=' + encodeURIComponent(String(options[key]))
        );
      }
    });

    return pairs.join('&');
  }

  /**
   * Builds an absolute URL with scheme, host, and port
   */
  buildAbsoluteUrl(path, options) {
    const urlOptions = { ...this.config.defaultUrlOptions, ...options };
    const scheme = urlOptions.scheme || 'http';
    const host = urlOptions.host || 'localhost';
    const port = urlOptions.port;

    let url = `${scheme}://${host}`;

    if (port && !this.isDefaultPort(scheme, port)) {
      url += `:${port}`;
    }

    url += path;

    return url;
  }

  /**
   * Checks if port is the default for the scheme
   */
  isDefaultPort(scheme, port) {
    return (scheme === 'http' && port === 80) || (scheme === 'https' && port === 443);
  }

  /**
   * Converts a route spec to a string representation (for debugging)
   */
  specToString(spec) {
    return this._nodeToString(spec);
  }

  _nodeToString(node) {
    if (typeof node === 'string') {
      return node;
    }

    if (Array.isArray(node)) {
      if (node.length === 0) {
        return '';
      }

      const [type, ...rest] = node;

      switch (type) {
        case 'param':
          return `:${rest[0]}`;
        case 'glob':
          return `*${rest[0]}`;
        case 'optional':
          return `(${rest[0].map(n => this._nodeToString(n)).join('')})`;
        default:
          return node.map(n => this._nodeToString(n)).join('');
      }
    }

    return '';
  }

  /**
   * Configure the route builder
   */
  configure(options) {
    this.config.configure(options);
  }

  /**
   * Get current configuration
   */
  getConfig() {
    return { ...this.config };
  }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { RouteBuilder };
} else if (typeof define === 'function' && define.amd) {
  define([], function() { return { RouteBuilder }; });
} else {
  this.NbRoutes = { RouteBuilder };
}
