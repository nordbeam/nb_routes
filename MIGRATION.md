# Migration Guide

This guide helps you migrate to nb_routes rich mode and adopt new features like method variants, form helpers, and auto-regeneration.

## Table of Contents

- [Overview](#overview)
- [Migration Paths](#migration-paths)
- [Step 1: Upgrade to Rich Mode](#step-1-upgrade-to-rich-mode)
- [Step 2: Enable Method Variants](#step-2-enable-method-variants)
- [Step 3: Enable Form Helpers](#step-3-enable-form-helpers)
- [Step 4: Setup Auto-Regeneration](#step-4-setup-auto-regeneration)
- [Breaking Changes](#breaking-changes)
- [Rollback Plan](#rollback-plan)
- [FAQ](#faq)

## Overview

nb_routes now supports two modes:

- **Simple Mode** (v0.1.0+): Returns URL strings `"/users/1"` (backward compatible)
- **Rich Mode** (v0.2.0+): Returns objects `{ url: "/users/1", method: "get" }` (new)

Rich mode unlocks:
- **Method variants**: `.get()`, `.post()`, `.url()` for flexibility
- **Form helpers**: `.form`, `.form.patch()` for HTML forms with method spoofing
- **Enhanced TypeScript**: `RouteResult`, `FormAttributes` types

## Migration Paths

### Path 1: Stay on Simple Mode (No Changes Required)

If you only need URL strings, stay on simple mode. No migration needed.

**What you keep:**
```typescript
import { user_path } from './routes';

user_path(1);  // => "/users/1" (string)
```

**Configuration:**
```elixir
# config/config.exs (or leave unset - simple is default)
config :nb_routes,
  variant: :simple
```

### Path 2: Gradual Migration to Rich Mode

Recommended for existing applications. Migrate incrementally with backward compatibility.

**Timeline:** 1-2 weeks depending on codebase size

### Path 3: Full Rich Mode (New Projects)

Use rich mode from the start for new projects.

## Step 1: Upgrade to Rich Mode

### 1.1 Update Configuration

```elixir
# config/config.exs
config :nb_routes,
  variant: :rich,
  with_methods: true,    # Enable method variants
  with_forms: false      # Enable later
```

### 1.2 Regenerate Routes

```bash
mix nb_routes.gen
```

### 1.3 Update TypeScript Imports

Rich mode adds new types:

```typescript
// Before (simple mode)
import { user_path } from './routes';

// After (rich mode) - add types
import { user_path } from './routes';
import type { RouteResult, RouteOptions } from './routes';
```

### 1.4 Update Route Usage

Rich mode returns objects instead of strings. Here's how to migrate:

#### Option A: Use `.url` for Backward Compatibility (Recommended)

Minimal code changes - append `.url` to get the URL string:

```typescript
// Before (simple mode)
const url = user_path(1);  // => "/users/1"

// After (rich mode) - add .url
const url = user_path.url(1);  // => "/users/1" (string)
```

**Migration strategy:**
1. Find and replace: `user_path(` → `user_path.url(`
2. Repeat for all route helpers
3. Test thoroughly

#### Option B: Use Full Rich Mode Objects

Leverage the new object API:

```typescript
// Before (simple mode)
const url = user_path(1);
router.visit(url, { method: 'get' });

// After (rich mode) - use object destructuring
const { url, method } = user_path(1);
router.visit(url, { method });

// Or use route object directly
const route = user_path(1);
router.visit(route.url, { method: route.method });
```

### 1.5 Update Inertia.js Code

If using Inertia.js, update your navigation code:

```typescript
import { router } from '@inertiajs/react';
import { user_path, users_path } from './routes';

// Before (simple mode)
<Link href={users_path()}>Users</Link>

// After (rich mode) - Option 1: .url variant
<Link href={users_path.url()}>Users</Link>

// After (rich mode) - Option 2: Use object
const usersRoute = users_path();
<Link href={usersRoute.url}>Users</Link>

// For visits with methods
// Before
router.visit(edit_user_path(user.id), { method: 'get' });

// After - method is now automatic!
const route = edit_user_path(user.id);
router.visit(route.url, { method: route.method });
```

### 1.6 Testing

Create a test suite to verify migration:

```typescript
// tests/routes.test.ts
import { user_path, update_user_path } from './routes';

describe('Route Helpers - Rich Mode', () => {
  test('returns route object with url and method', () => {
    const route = user_path(123);

    expect(route).toHaveProperty('url');
    expect(route).toHaveProperty('method');
    expect(route.url).toBe('/users/123');
    expect(route.method).toBe('get');
  });

  test('.url variant returns string', () => {
    const url = user_path.url(123);

    expect(typeof url).toBe('string');
    expect(url).toBe('/users/123');
  });

  test('method variants work correctly', () => {
    const getRoute = user_path.get(123);
    const headRoute = user_path.head(123);

    expect(getRoute.method).toBe('get');
    expect(headRoute.method).toBe('head');
  });
});
```

## Step 2: Enable Method Variants

Method variants are enabled by default when using rich mode.

### Available Variants

Every route gets these variants:

```typescript
// Main function - uses route's HTTP method
user_path(1);           // => { url: "/users/1", method: "get" }

// Method variants
user_path.get(1);       // => { url: "/users/1", method: "get" }
user_path.head(1);      // => { url: "/users/1", method: "head" }
user_path.url(1);       // => "/users/1" (string only)

// Mutation routes get their method variant
update_user_path(1);           // => { url: "/users/1", method: "patch" }
update_user_path.patch(1);     // => { url: "/users/1", method: "patch" }
update_user_path.put(1);       // => { url: "/users/1", method: "put" }

delete_user_path(1);           // => { url: "/users/1", method: "delete" }
delete_user_path.delete(1);    // => { url: "/users/1", method: "delete" }
```

### Use Cases

**HEAD requests for checking existence:**
```typescript
// Check if resource exists without downloading
const exists = await fetch(user_path.head(userId))
  .then(res => res.ok);
```

**Method override for forms:**
```typescript
// Use PUT instead of PATCH
const route = update_user_path.put(user.id);
router.visit(route.url, { method: route.method });
```

## Step 3: Enable Form Helpers

Form helpers simplify HTML form integration with automatic method spoofing.

### 3.1 Enable in Configuration

```elixir
# config/config.exs
config :nb_routes,
  variant: :rich,
  with_methods: true,
  with_forms: true  # NEW: Enable form helpers
```

### 3.2 Regenerate Routes

```bash
mix nb_routes.gen
```

### 3.3 Update TypeScript Imports

```typescript
import { update_user_path, delete_user_path } from './routes';
import type { FormAttributes } from './routes';  // NEW
```

### 3.4 Use Form Helpers in React/Inertia

**Before (manual method spoofing):**
```typescript
function EditUserForm({ user }) {
  const handleSubmit = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);

    // Manual method handling
    router.visit(`/users/${user.id}`, {
      method: 'patch',
      data: Object.fromEntries(formData)
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <input type="text" name="name" defaultValue={user.name} />
      <button type="submit">Update</button>
    </form>
  );
}
```

**After (with form helpers):**
```typescript
function EditUserForm({ user }) {
  const handleSubmit = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const route = update_user_path.patch(user.id);  // Form-aware route

    router.visit(route.url, {
      method: route.method,  // Automatically correct
      data: Object.fromEntries(formData)
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <input type="text" name="name" defaultValue={user.name} />
      <button type="submit">Update</button>
    </form>
  );
}
```

**HTML Forms (server-submitted):**
```typescript
function EditUserForm({ user }) {
  const formAttrs = update_user_path.form.patch(user.id);
  // formAttrs = { action: "/users/1?_method=PATCH", method: "post" }

  return (
    <form {...formAttrs}>
      <input type="text" name="user[name]" defaultValue={user.name} />
      <button type="submit">Update</button>
    </form>
  );
}
```

### 3.5 Delete Actions

**Before:**
```typescript
function DeleteButton({ user }) {
  const handleDelete = () => {
    if (confirm('Delete user?')) {
      router.delete(`/users/${user.id}`);
    }
  };

  return <button onClick={handleDelete}>Delete</button>;
}
```

**After:**
```typescript
function DeleteButton({ user }) {
  const handleDelete = () => {
    if (confirm('Delete user?')) {
      const route = delete_user_path.delete(user.id);
      router.visit(route.url, { method: route.method });
    }
  };

  return <button onClick={handleDelete}>Delete</button>;
}
```

## Step 4: Setup Auto-Regeneration

Auto-regeneration with HMR keeps your routes in sync during development.

### 4.1 Install nb_vite Plugin

The `nbRoutes` Vite plugin is included with `nb_vite`:

```bash
# Already installed if using nb_vite
mix deps.get
```

### 4.2 Configure Vite Plugin

```typescript
// assets/vite.config.ts
import { defineConfig } from 'vite';
import phoenix from '@nordbeam/nb-vite';
import { nbRoutes } from '@nordbeam/nb-vite/nb-routes';  // NEW

export default defineConfig({
  plugins: [
    phoenix({
      input: ['js/app.ts'],
    }),
    nbRoutes({
      enabled: true,     // Enable auto-regeneration
      verbose: false,    // Set true for debugging
      debounce: 300      // Delay before regeneration (ms)
    })
  ],
});
```

### 4.3 Test Auto-Regeneration

1. Start Vite dev server:
   ```bash
   npm run dev
   # or
   mix phx.server
   ```

2. Edit your Phoenix router:
   ```elixir
   # lib/my_app_web/router.ex
   scope "/", MyAppWeb do
     pipe_through :browser

     get "/users", UserController, :index
     get "/users/:id", UserController, :show
     get "/posts", PostController, :index  # ADD THIS
   end
   ```

3. Save the file

4. Check console output:
   ```
   [nb-routes] Router file changed: lib/my_app_web/router.ex
   [nb-routes] Regenerating routes...
   [nb-routes] ✓ Routes regenerated successfully
   [nb-routes] HMR update sent to browser
   ```

5. Verify in browser console:
   ```typescript
   import { posts_path } from './routes';
   console.log(posts_path.url());  // => "/posts"
   ```

### 4.4 Advanced Configuration

```typescript
nbRoutes({
  enabled: process.env.NODE_ENV === 'development',
  routerPath: [
    'lib/my_app_web/router.ex',
    'lib/my_app_web/api_router.ex'  // Watch multiple routers
  ],
  command: 'mix nb_routes.gen --variant rich --with-forms',
  debounce: 500,  // Longer for slower machines
  verbose: true   // Debug mode
})
```

## Breaking Changes

### v0.2.0 - Rich Mode Introduction

#### Return Type Change

**Simple Mode (backward compatible):**
```typescript
user_path(1);  // => "/users/1" (string)
```

**Rich Mode (new behavior):**
```typescript
user_path(1);  // => { url: "/users/1", method: "get" } (object)
```

**Migration:** Use `.url` variant for backward compatibility:
```typescript
user_path.url(1);  // => "/users/1" (string)
```

#### TypeScript Type Changes

**Before (simple mode):**
```typescript
type user_path = (id: number, options?: RouteOptions) => string;
```

**After (rich mode without methods):**
```typescript
type user_path = (id: number, options?: RouteOptions) => RouteResult;
```

**After (rich mode with methods):**
```typescript
interface RouteHelperFunction {
  (id: number, options?: RouteOptions): RouteResult;
  get(id: number, options?: RouteOptions): RouteResult;
  head(id: number, options?: RouteOptions): RouteResult;
  url(id: number, options?: RouteOptions): string;
}
```

### No Breaking Changes for Simple Mode

Simple mode remains 100% backward compatible. If you stay on `:variant :simple`, nothing changes.

## Rollback Plan

If you need to rollback to simple mode:

### 1. Restore Configuration

```elixir
# config/config.exs
config :nb_routes,
  variant: :simple  # Back to simple mode
```

### 2. Regenerate Routes

```bash
mix nb_routes.gen
```

### 3. Revert Code Changes

If you used `.url` variants everywhere, remove them:
```bash
# Find and replace (be careful!)
# user_path.url( → user_path(
```

### 4. Update TypeScript Imports

Remove rich mode types:
```typescript
// Remove these imports
import type { RouteResult, FormAttributes } from './routes';
```

## FAQ

### Q: Do I need to migrate to rich mode?

**A:** No. Simple mode is still fully supported and works great if you only need URL strings.

### Q: Can I use rich mode with non-Inertia apps?

**A:** Yes! Rich mode works with any JavaScript framework or vanilla JS.

### Q: What if I'm using Phoenix LiveView?

**A:** LiveView typically doesn't need JavaScript route helpers. Use Phoenix's `~p` sigil instead. However, if you do need JS routes (e.g., for Alpine.js components), rich mode works fine.

### Q: Will simple mode be deprecated?

**A:** No. Simple mode is a first-class citizen and will be supported indefinitely.

### Q: Can I mix simple and rich mode?

**A:** No. You must choose one mode per application. However, different apps can use different modes.

### Q: How do I migrate a large codebase?

**A:** Use the `.url` variant approach for minimal changes. Search and replace `route_helper(` with `route_helper.url(` throughout your codebase.

### Q: Do form helpers work with server-rendered forms?

**A:** Yes! Form helpers are designed for both client-side (Inertia.js) and server-rendered forms.

### Q: What about nested routes?

**A:** They work the same way in both modes:
```typescript
// Simple
user_post_path(1, 2);  // => "/users/1/posts/2"

// Rich
user_post_path(1, 2);  // => { url: "/users/1/posts/2", method: "get" }
user_post_path.url(1, 2);  // => "/users/1/posts/2"
```

### Q: Can I use query parameters with form helpers?

**A:** Yes:
```typescript
const formAttrs = update_user_path.form.patch(1, {
  query: { redirect: '/dashboard' }
});
// => { action: "/users/1?_method=PATCH&redirect=/dashboard", method: "post" }
```

### Q: How do I test routes in rich mode?

**A:** Test both the object and `.url` variant:
```typescript
test('user_path returns route object', () => {
  const route = user_path(1);
  expect(route.url).toBe('/users/1');
  expect(route.method).toBe('get');
});

test('user_path.url returns string', () => {
  expect(user_path.url(1)).toBe('/users/1');
});
```

### Q: Does auto-regeneration work in production?

**A:** No. Auto-regeneration is development-only. In production, routes are generated once during build.

### Q: What if regeneration fails?

**A:** The plugin logs errors to console. Common issues:
- Mix not in PATH
- Router compilation errors
- File permission issues

Check verbose logs with `verbose: true` in plugin config.

### Q: Can I disable auto-regeneration temporarily?

**A:** Yes:
```typescript
nbRoutes({
  enabled: false  // Disable temporarily
})
```

## Support

- **Documentation:** [README.md](README.md)
- **Issues:** [GitHub Issues](https://github.com/nordbeam/nb/issues)
- **Examples:** See [nb_routes/examples](examples/) directory

## Timeline Estimates

### Small Project (< 10 route helpers)
- **Path 1 (Stay Simple):** 0 minutes
- **Path 2 (Gradual Migration):** 1-2 hours
- **Path 3 (Full Rich):** 2-4 hours

### Medium Project (10-50 route helpers)
- **Path 1 (Stay Simple):** 0 minutes
- **Path 2 (Gradual Migration):** 4-8 hours
- **Path 3 (Full Rich):** 1-2 days

### Large Project (50+ route helpers)
- **Path 1 (Stay Simple):** 0 minutes
- **Path 2 (Gradual Migration):** 1-2 weeks
- **Path 3 (Full Rich):** 2-4 weeks

**Pro tip:** Start with `.url` variants for quick migration, then gradually refactor to full rich mode objects where it adds value.
