# nb_routes Architecture - Rich Route Helpers

## Overview

This document describes the architecture for enhanced route helpers inspired by Laravel Wayfinder, adapted for the Phoenix/Elixir ecosystem.

## Design Goals

1. **Rich return types**: Routes return `{ url, method }` objects instead of just strings
2. **Method variants**: Support `.get()`, `.post()`, `.url()` etc.
3. **Query parameters**: Support `query` and `mergeQuery` options
4. **Form helpers**: Generate form attributes for HTML forms (via nb_inertia)
5. **Type safety**: Full TypeScript support for all variants
6. **Backward compatibility**: Simple mode returns just URLs (current behavior)

## Configuration

```elixir
# config/dev.exs
config :nb_routes,
  output_file: "assets/js/routes.ts",
  module_type: :esm,
  variant: :rich,          # :simple (default) or :rich
  with_methods: true,      # Generate method variants (rich mode only)
  with_forms: false        # Generate form helpers (requires nb_inertia)
```

## Generated Code Structure

### Simple Mode (Backward Compatible)

```typescript
// Current behavior - just returns URL string
export const user_path = (id: number | string, options?: RouteOptions): string => {
  // ...
};
```

### Rich Mode

```typescript
// Returns { url, method } by default
export const user_path = Object.assign(
  (id: number | string, options?: RouteOptions): RouteResult => ({
    url: _buildUrl("/users/:id", { id }, options),
    method: "get"
  }),
  {
    // Method variants
    get: (id: number | string, options?: RouteOptions): RouteResult => ({
      url: _buildUrl("/users/:id", { id }, options),
      method: "get"
    }),
    head: (id: number | string, options?: RouteOptions): RouteResult => ({
      url: _buildUrl("/users/:id", { id }, options),
      method: "head"
    }),

    // URL only (for simple use cases)
    url: (id: number | string, options?: RouteOptions): string =>
      _buildUrl("/users/:id", { id }, options),
  }
);
```

### Rich Mode with Forms (nb_inertia integration)

```typescript
export const update_user_path = Object.assign(
  // ... basic route helper ...
  {
    // ... method variants ...

    // Form helpers (added by nb_inertia)
    form: Object.assign(
      (id: number | string, options?: RouteOptions): FormAttributes => ({
        action: _buildFormAction("/users/:id", { id }, "patch", options),
        method: "post"
      }),
      {
        patch: (id: number | string, options?: RouteOptions): FormAttributes => ({
          action: _buildFormAction("/users/:id", { id }, "patch", options),
          method: "post"
        }),
        put: (id: number | string, options?: RouteOptions): FormAttributes => ({
          action: _buildFormAction("/users/:id", { id }, "put", options),
          method: "post"
        }),
        delete: (id: number | string, options?: RouteOptions): FormAttributes => ({
          action: _buildFormAction("/users/:id", { id }, "delete", options),
          method: "post"
        }),
      }
    )
  }
);
```

## Runtime Helpers

### _buildUrl (nb_routes)

```typescript
function _buildUrl(
  pattern: string,
  params: Record<string, any>,
  options?: RouteOptions
): string {
  let url = pattern;

  // Replace path parameters
  for (const [key, value] of Object.entries(params)) {
    url = url.replace(`:${key}`, String(value));
  }

  // Handle query parameters
  if (options?.query) {
    const queryString = new URLSearchParams(options.query).toString();
    if (queryString) url += "?" + queryString;
  } else if (options?.mergeQuery && typeof window !== 'undefined') {
    const current = new URLSearchParams(window.location.search);
    for (const [key, value] of Object.entries(options.mergeQuery)) {
      if (value === null || value === undefined) {
        current.delete(key);
      } else {
        current.set(key, String(value));
      }
    }
    const queryString = current.toString();
    if (queryString) url += "?" + queryString;
  }

  // Handle anchor
  if (options?.anchor) {
    url += "#" + options.anchor;
  }

  return url;
}
```

### _buildFormAction (nb_inertia)

```typescript
function _buildFormAction(
  pattern: string,
  params: Record<string, any>,
  method: string,
  options?: RouteOptions
): string {
  let url = _buildUrl(pattern, params, options);

  // Add _method parameter for method spoofing
  if (!["get", "post"].includes(method.toLowerCase())) {
    const separator = url.includes("?") ? "&" : "?";
    url += `${separator}_method=${method.toUpperCase()}`;
  }

  return url;
}
```

## Type Definitions (nb_ts)

```typescript
// Core types
export interface RouteResult {
  url: string;
  method: 'get' | 'post' | 'patch' | 'put' | 'delete' | 'head' | 'options';
}

export interface RouteOptions {
  query?: Record<string, string | number | boolean>;
  mergeQuery?: Record<string, string | number | boolean | null | undefined>;
  anchor?: string;
}

export interface FormAttributes {
  action: string;
  method: 'get' | 'post';
}

// Route helper interfaces
export interface RouteHelper<TParams extends any[]> {
  (...params: [...TParams, options?: RouteOptions]): RouteResult;
  get(...params: [...TParams, options?: RouteOptions]): RouteResult;
  head(...params: [...TParams, options?: RouteOptions]): RouteResult;
  url(...params: [...TParams, options?: RouteOptions]): string;
}

export interface RouteHelperWithForm<TParams extends any[]> extends RouteHelper<TParams> {
  form: {
    (...params: [...TParams, options?: RouteOptions]): FormAttributes;
    patch(...params: [...TParams, options?: RouteOptions]): FormAttributes;
    put(...params: [...TParams, options?: RouteOptions]): FormAttributes;
    delete(...params: [...TParams, options?: RouteOptions]): FormAttributes;
  };
}
```

## Package Responsibilities

### nb_routes
- **Core route generation**
- Rich return types and method variants
- Query parameter API (`query`, `mergeQuery`)
- Generate `_buildUrl` helper
- Simple/rich mode configuration

### nb_inertia
- **Form helper integration**
- Detect nb_routes rich mode
- Extend route helpers with `.form` variants
- Generate `_buildFormAction` helper
- Method spoofing for non-GET/POST

### nb_vite
- **Auto-regeneration**
- Vite plugin for file watching
- Watch `router.ex` and controllers
- Trigger `mix nb_routes.gen` on changes
- HMR for route module updates

### nb_ts
- **Type generation**
- Generate `RouteResult`, `RouteOptions`, `FormAttributes` types
- Generate `RouteHelper` and `RouteHelperWithForm` interfaces
- Type-safe parameters based on route definition
- IntelliSense support for all variants

## Usage Examples

### Basic Usage (Rich Mode)

```typescript
import { user_path, update_user_path } from '@/routes';

// Default: returns { url, method }
user_path(1);
// { url: "/users/1", method: "get" }

// Specific method variant
user_path.head(1);
// { url: "/users/1", method: "head" }

// Just the URL
user_path.url(1);
// "/users/1"
```

### Query Parameters

```typescript
// Add query parameters
user_path(1, { query: { page: 2, filter: 'active' } });
// { url: "/users/1?page=2&filter=active", method: "get" }

// Merge with current URL params
user_path(1, { mergeQuery: { page: 2, sort: null } });
// { url: "/users/1?page=2&...", method: "get" }
// (preserves other params, removes sort)
```

### With Inertia

```typescript
import { router, useForm } from '@inertiajs/react';
import { user_path, update_user_path } from '@/routes';

// Navigate
router.visit(user_path(1));
// Inertia extracts { url, method } automatically

// Forms
const form = useForm({ name: 'John' });
form.submit(update_user_path(1));
// POST /users/1?_method=PATCH
```

### Standard HTML Forms

```tsx
import { update_user_path, delete_user_path } from '@/routes';

// Update form
<form {...update_user_path.form(1)}>
  {/* <form action="/users/1?_method=PATCH" method="post"> */}
  <input name="name" />
  <button>Update</button>
</form>

// Delete with specific method
<form {...delete_user_path.form.delete(1)}>
  {/* <form action="/users/1?_method=DELETE" method="post"> */}
  <button>Delete</button>
</form>
```

## Migration Path

### Phase 1: nb_routes Rich Mode
- Add configuration option
- Generate rich helpers
- Update code generator
- Add tests
- **Backward compatible** - simple mode is default

### Phase 2: nb_inertia Form Helpers
- Detect nb_routes rich mode
- Extend helpers with `.form` variants
- Add method spoofing
- Add tests

### Phase 3: nb_vite Auto-regeneration
- Create Vite plugin
- File watching
- HMR integration
- Optional feature

### Phase 4: nb_ts Type Updates
- Generate new type definitions
- Update route helper types
- Full IntelliSense support

## Backward Compatibility

- **Simple mode remains default**: Existing apps work without changes
- **Opt-in to rich mode**: Set `variant: :rich` in config
- **Progressive enhancement**: Add form helpers only when nb_inertia is installed
- **No breaking changes**: All new features are additive

## Performance Considerations

- **Tree shaking**: Method variants use Object.assign, tree-shakeable
- **Bundle size**: ~2KB additional for runtime helpers (rich mode)
- **Runtime overhead**: Minimal - just object creation
- **Build time**: Negligible increase in generation time

## Testing Strategy

1. **Unit tests**: Each helper function tested independently
2. **Integration tests**: Verify packages work together
3. **Type tests**: Ensure TypeScript types are correct
4. **E2E tests**: Test in real Phoenix app (vouchwall)

## Open Questions

1. Should we support flexible parameter shapes like Wayfinder?
   - `update(1, 2)` vs `update({ post: 1, author: 2 })`
   - **Decision**: Not initially - Phoenix uses positional params

2. Should we generate from controllers or just routes?
   - **Decision**: Routes only - they're the source of truth in Phoenix

3. Should form helpers include CSRF tokens?
   - **Decision**: No - handled by Phoenix form helpers or Inertia

4. Should we support absolute URLs (_url variants)?
   - **Decision**: Yes, via configuration option (future)
