# NbRoutes

Generate JavaScript/TypeScript route helpers from Phoenix routes. A port of [js-routes](https://github.com/railsware/js-routes) for Rails to Phoenix/Elixir.

## Features

- **Type-safe route generation** - Generate paths with compile-time validation
- **Rich Mode** - Return `{ url, method }` objects with method variants (`.get`, `.post`, `.url`)
- **Form Helpers** - Automatic method spoofing for HTML forms (`.form`, `.form.patch`, etc.)
- **TypeScript support** - Auto-generate `.d.ts` files with full type information
- **Multiple module formats** - ESM, CommonJS, UMD, or global namespace
- **Flexible configuration** - Include/exclude routes, camelCase naming, URL helpers
- **Integration ready** - Works seamlessly with `nb_vite`, `nb_inertia`, and `nb_ts`
- **Development watcher** - Auto-regenerate routes when router changes (via nb_vite plugin)

## Installation

Add `nb_routes` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:nb_routes, github: "nordbeam/nb_routes"}
  ]
end
```

Then fetch and generate:

```bash
mix deps.get
```

## Quick Start

### 1. Generate Route Helpers

```bash
mix nb_routes.gen
```

This generates:
- `assets/js/routes.js` - JavaScript route helpers
- `assets/js/routes.d.ts` - TypeScript type definitions

### 2. Use in Your Frontend Code

```javascript
// Import route helpers (ESM)
import { users_path, user_path, user_posts_path } from './routes';

// Generate paths
users_path()                          // => "/users"
user_path(1)                          // => "/users/1"
user_path(1, { format: 'json' })     // => "/users/1.json"
user_posts_path(1, 2)                // => "/users/1/posts/2"

// Query parameters
user_path(1, { foo: 'bar' })         // => "/users/1?foo=bar"

// Anchors
user_path(1, { anchor: 'profile' })  // => "/users/1#profile"

// Introspection
user_path.toString()                 // => "/users/:id(.:format)"
user_path.requiredParams()           // => ["id"]
```

### 3. TypeScript Support

Full type safety out of the box:

```typescript
import { user_path, users_path } from './routes';

// TypeScript knows the required parameters
user_path(123);           // ✓ OK
user_path();              // ✗ Error: Missing required parameter

// Options are also type-checked
user_path(123, {
  format: 'json',
  custom_param: 'value'   // ✓ OK - passed as query param
});
```

## Rich Mode

Rich mode is an advanced feature that generates route helpers with enhanced capabilities including method variants and form helpers.

### Basic Rich Mode

Enable rich mode in your configuration:

```elixir
config :nb_routes,
  variant: :rich,          # Enable rich mode
  with_methods: true,      # Enable method variants (.get, .post, .url, etc.)
  with_forms: false        # Enable form helpers (requires nb_inertia)
```

Rich mode route helpers return objects instead of strings:

```javascript
import { user_path, update_user_path } from './routes';

// Instead of returning "/users/1"
// Returns { url: "/users/1", method: "get" }
const route = user_path(1);

console.log(route.url);     // => "/users/1"
console.log(route.method);  // => "get"
```

### Method Variants

With `with_methods: true`, each route gets additional method variants:

```javascript
import { user_path } from './routes';

// Main function - uses the route's defined HTTP method
user_path(1);              // => { url: "/users/1", method: "get" }

// Method variants
user_path.get(1);          // => { url: "/users/1", method: "get" }
user_path.head(1);         // => { url: "/users/1", method: "head" }
user_path.url(1);          // => "/users/1" (returns just the URL string)

// For mutation routes (POST, PATCH, PUT, DELETE)
update_user_path(1);           // => { url: "/users/1", method: "patch" }
update_user_path.patch(1);     // => { url: "/users/1", method: "patch" }
update_user_path.put(1);       // => { url: "/users/1", method: "put" }
delete_user_path(1);           // => { url: "/users/1", method: "delete" }
delete_user_path.delete(1);    // => { url: "/users/1", method: "delete" }
```

### Query Parameters and Options

Rich mode supports the same query parameter API:

```javascript
user_path(1, {
  query: { filter: 'active', sort: 'name' },  // Append query params
  anchor: 'profile'                            // Add hash anchor
});
// => { url: "/users/1?filter=active&sort=name#profile", method: "get" }

// mergeQuery allows null to remove params (useful for overriding)
user_path(1, {
  mergeQuery: { tab: 'settings', page: null }
});
```

### Form Helpers

Enable form helpers for seamless HTML form integration:

```elixir
config :nb_routes,
  variant: :rich,
  with_methods: true,
  with_forms: true    # Enable form helpers
```

Form helpers handle method spoofing automatically for HTML forms:

```javascript
import { update_user_path, delete_user_path } from './routes';

// HTML forms only support GET and POST
// Form helpers automatically add _method parameter for other verbs

// PATCH form
update_user_path.form(1);
// => { action: "/users/1?_method=PATCH", method: "post" }

// Specific method variants
update_user_path.form.patch(1);
// => { action: "/users/1?_method=PATCH", method: "post" }

update_user_path.form.put(1);
// => { action: "/users/1?_method=PUT", method: "post" }

delete_user_path.form.delete(1);
// => { action: "/users/1?_method=DELETE", method: "post" }
```

**React Example:**

```jsx
import { update_user_path } from './routes';

function EditUserForm({ user }) {
  const formAction = update_user_path.form.patch(user.id);

  return (
    <form action={formAction.action} method={formAction.method}>
      <input type="text" name="user[name]" defaultValue={user.name} />
      <button type="submit">Update</button>
    </form>
  );
}
```

**Inertia.js Example:**

```jsx
import { router } from '@inertiajs/react';
import { update_user_path } from './routes';

function EditUserForm({ user }) {
  const handleSubmit = (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const route = update_user_path.patch(user.id);

    router.visit(route.url, {
      method: route.method,
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

### TypeScript Support for Rich Mode

Rich mode includes full TypeScript support with specialized interfaces:

```typescript
import { user_path, update_user_path } from './routes';
import type { RouteResult, RouteOptions, FormAttributes } from './routes';

// RouteResult interface
const route: RouteResult = user_path(123);
route.url;      // string
route.method;   // 'get' | 'post' | 'patch' | 'put' | 'delete' | 'head' | 'options'

// RouteOptions interface
const options: RouteOptions = {
  query: { filter: 'active' },         // Query parameters
  mergeQuery: { page: null },          // Merge/remove query params
  anchor: 'section'                    // Hash anchor
};

// FormAttributes interface (when with_forms is enabled)
const formProps: FormAttributes = update_user_path.form.patch(123);
formProps.action;   // string (URL with _method param)
formProps.method;   // 'get' | 'post'
```

### When to Use Rich Mode

**Use Rich Mode when:**
- Building SPAs with Inertia.js or similar frameworks
- Need to know the HTTP method along with the URL
- Working with HTML forms that require method spoofing
- Want method variants for flexibility (.get, .post, .url)

**Use Simple Mode when:**
- You only need URL strings
- Building traditional server-rendered apps
- Optimizing for minimal JavaScript bundle size
- Don't need method information in the frontend

## Resource Mode

Resource mode generates per-resource TypeScript files for better tree-shaking and a more Phoenix-idiomatic developer experience. Instead of a single routes.js file, it creates one file per resource.

### Enable Resource Mode

```bash
# CLI
mix nb_routes.gen --style resource --output-dir assets/js/routes

# Or in config/config.exs
config :nb_routes,
  style: :resource,
  output_dir: "assets/js/routes"
```

### Generated File Structure

```
assets/js/routes/
├── index.ts           # Barrel file re-exporting all resources
├── lib/
│   └── wayfinder.ts   # Runtime library with route() function
├── users.ts           # Users resource (index, show, new, create, edit, update, delete)
├── posts.ts           # Posts resource
├── contacts.ts        # Contacts resource
└── organizations.ts   # Organizations resource
```

### Generated Resource Files

Each resource file contains all CRUD actions with full TypeScript types:

```typescript
// assets/js/routes/users.ts
import { route, type Route, type RouteOptions, type Param } from '../lib/wayfinder';

const index = route('/users', 'get');
const new_ = route('/users/new', 'get');
const create = route('/users', 'post');
const show = route<{ id: Param }>('/users/:id', 'get');
const edit = route<{ id: Param }>('/users/:id/edit', 'get');
const update = route<{ id: Param }>('/users/:id', 'put');
const delete_ = route<{ id: Param }>('/users/:id', 'delete');

// Object uses clean property names (new, delete) for nice API
export const users = {
  index,
  new: new_,
  create,
  show,
  edit,
  update,
  delete: delete_,
} as const;

export { index, new_, create, show, edit, update, delete_ };
```

### Usage in Frontend Code

```typescript
// Tree-shakeable imports - only imports what you use
import { users } from '@/routes';

// Use the resource object - clean property names!
router.visit(users.index());                    // GET /users
router.visit(users.show(1));                    // GET /users/1
router.visit(users.new());                      // GET /users/new
router.visit(users.delete(1));                  // DELETE /users/1
router.visit(users.update.patch(1));            // PATCH /users/1

// With Link component
<Link href={users.show(user.id)}>View User</Link>
<Link href={users.edit(user.id)}>Edit</Link>
<Link href={users.new()}>New User</Link>
```

### Route Function API

The `route()` function returns a route helper with method variants:

```typescript
const show = route<{ id: Param }>('/users/:id', 'get');

// Main function - returns { url, method }
show(1);                    // { url: "/users/1", method: "get" }
show({ id: 1 });            // { url: "/users/1", method: "get" }

// Method variants
show.get(1);                // { url: "/users/1", method: "get" }
show.post(1);               // { url: "/users/1", method: "post" }
show.patch(1);              // { url: "/users/1", method: "patch" }
show.put(1);                // { url: "/users/1", method: "put" }
show.delete(1);             // { url: "/users/1", method: "delete" }
show.url(1);                // "/users/1" (just the URL string)

// Form helpers (for HTML form method spoofing)
show.form(1);               // { action: "/users/1", method: "get" }
show.form.patch(1);         // { action: "/users/1?_method=PATCH", method: "post" }
show.form.put(1);           // { action: "/users/1?_method=PUT", method: "post" }
show.form.delete(1);        // { action: "/users/1?_method=DELETE", method: "post" }

// Query parameters and options
show(1, { query: { tab: 'settings' } });    // { url: "/users/1?tab=settings", method: "get" }
show(1, { anchor: 'profile' });             // { url: "/users/1#profile", method: "get" }
```

### Phoenix.Param-Style Parameter Extraction

The runtime automatically extracts `id` from objects:

```typescript
const user = { id: 123, name: "John" };

users.show(user);           // Extracts user.id → "/users/123"
users.show(123);            // Direct value → "/users/123"
users.show({ id: 123 });    // Object with id → "/users/123"
```

### Resource Mode CLI Options

```bash
# Enable resource mode
mix nb_routes.gen --style resource

# Custom output directory
mix nb_routes.gen --style resource --output-dir assets/js/routes

# Group routes by scope instead of resource
mix nb_routes.gen --style resource --group-by scope

# Skip generating index.ts barrel file
mix nb_routes.gen --style resource --no-index

# Exclude LiveView routes
mix nb_routes.gen --style resource --no-live
```

### Configuration Options

```elixir
config :nb_routes,
  # Resource mode options
  style: :resource,                    # :classic (default) | :resource
  output_dir: "assets/js/routes",      # Output directory for resource files
  group_by: :resource,                 # :resource | :scope | :controller
  include_index: true,                 # Generate index.ts barrel file
  include_live: true                   # Include LiveView routes
```

### Grouping Strategies

**`:resource` (default)** - Groups by resource name from helper:
```
users_path, user_path, new_user_path → users.ts
posts_path, post_path → posts.ts
```

**`:scope`** - Groups by URL path scope:
```
/admin/users → admin/users.ts
/api/v1/products → api/v1/products.ts
```

**`:controller`** - Groups by controller module (coming soon)

### When to Use Resource Mode

**Use Resource Mode when:**
- You want better tree-shaking (only import what you use)
- You prefer a more Phoenix-idiomatic import style
- Building larger apps with many routes
- Using TypeScript and want excellent type inference

**Use Classic Mode when:**
- You have a small number of routes
- You prefer a single routes file
- You need compatibility with existing code

## Configuration

Configure in `config/config.exs`:

```elixir
config :nb_routes,
  # Basic options
  module_type: :esm,                    # :esm | :cjs | :umd | nil
  output_file: "assets/js/routes.js",
  router: MyAppWeb.Router,              # Optional - auto-detected if not set

  # Route filtering
  include: [~r/^api_/],                 # Only include API routes
  exclude: [~r/^admin_/],               # Exclude admin routes

  # Naming
  camel_case: false,                    # Convert to camelCase
  compact: false,                       # Remove _path suffix

  # Rich mode options
  variant: :rich,                       # :simple (default) | :rich
  with_methods: true,                   # Enable method variants (.get, .post, etc.)
  with_forms: false,                    # Enable form helpers (.form, .form.patch, etc.)

  # Other options
  url_helpers: false,                   # Generate *_url helpers
  documentation: true                   # JSDoc comments
```

## CLI Options

The `mix nb_routes.gen` task supports various options:

```bash
# Specify router explicitly
mix nb_routes.gen --router MyAppWeb.Router

# Custom output path
mix nb_routes.gen --output public/js/routes.js

# Include only specific routes
mix nb_routes.gen --include "^api_" --include "^public_"

# Exclude routes
mix nb_routes.gen --exclude "^admin_"

# Generate as CommonJS
mix nb_routes.gen --module-type cjs

# Enable rich mode
mix nb_routes.gen --variant rich

# Enable method variants (requires rich mode)
mix nb_routes.gen --variant rich --with-methods

# Enable form helpers (requires rich mode)
mix nb_routes.gen --variant rich --with-methods --with-forms

# Use camelCase names
mix nb_routes.gen --camel-case

# Remove _path suffix
mix nb_routes.gen --compact

# Skip TypeScript definitions
mix nb_routes.gen --no-types
```

## Module Formats

### ESM (Default)

```javascript
export const users_path = ...;
export const user_path = ...;
```

### CommonJS

```javascript
module.exports.users_path = ...;
module.exports.user_path = ...;
```

### UMD

Works in both Node.js and browsers:

```javascript
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.Routes = factory();
  }
}(this, function () {
  // ...
}));
```

### Global Namespace

```javascript
window.Routes = {
  users_path: ...,
  user_path: ...
};
```

## Advanced Usage

### Programmatic API

```elixir
# Generate JavaScript code
code = NbRoutes.generate(MyAppWeb.Router)

# Generate and write to file
NbRoutes.generate!("assets/js/routes.js", MyAppWeb.Router)

# Generate TypeScript definitions
types = NbRoutes.definitions(MyAppWeb.Router)

# Generate and write TypeScript definitions
NbRoutes.definitions!("assets/js/routes.d.ts", MyAppWeb.Router)

# Extract routes for inspection
routes = NbRoutes.routes(MyAppWeb.Router)
```

### Runtime Configuration

Configure route generation at runtime:

```javascript
import { configure, config } from './routes';

// Configure default URL options
configure({
  defaultUrlOptions: {
    scheme: 'https',
    host: 'example.com',
    port: 443
  },
  trailingSlash: true
});

// Get current config
const currentConfig = config();
```

### Integration with nb_vite

For automatic route regeneration during development, add the `nbRoutes` plugin to your Vite config:

```typescript
// assets/vite.config.ts
import { defineConfig } from 'vite';
import phoenix from '@nordbeam/nb-vite';
import { nbRoutes } from '@nordbeam/nb-vite/nb-routes';

export default defineConfig({
  plugins: [
    phoenix({
      input: ['js/app.ts'],
    }),
    nbRoutes({
      enabled: true,       // Enable the plugin
      verbose: false,      // Enable verbose logging
      debounce: 300        // Debounce delay in ms
    })
  ],
});
```

The plugin will:
- Watch your Phoenix router files for changes
- Automatically regenerate routes when router.ex changes
- Trigger HMR to reload the routes module in your browser
- Debounce rapid changes to avoid excessive regeneration

**Configuration Options:**

```typescript
nbRoutes({
  enabled: true,                              // Enable/disable the plugin
  routerPath: ['lib/**/*_web/router.ex'],    // Router file patterns to watch
  routesFile: 'assets/js/routes.js',         // Path to generated routes file
  command: 'mix nb_routes.gen',              // Command to run for generation
  debounce: 300,                             // Debounce delay in milliseconds
  verbose: false                             // Enable verbose logging
})
```

### Integration with nb_inertia

Use route helpers in your Inertia.js apps:

```jsx
import { router } from '@inertiajs/react';
import { user_path, edit_user_path } from './routes';

function UserCard({ user }) {
  return (
    <div>
      <a href={user_path(user.id)}>View</a>
      <button onClick={() => router.visit(edit_user_path(user.id))}>
        Edit
      </button>
    </div>
  );
}
```

### Integration with nb_ts

When both `nb_routes` and `nb_ts` are installed, route helpers are automatically included in the unified type generation system:

**Automatic Type Generation:**

```elixir
# nb_routes exports type metadata that nb_ts discovers
# When you run:
mix nb_ts.gen.types

# Or when router changes trigger compile hooks:
# - nb_routes detects the router update
# - nb_ts automatically regenerates route helper types
# - Types are included in assets/js/types/index.ts
```

**Unified Import:**

```typescript
// Import from nb_ts-generated types
import type { UsersIndexProps } from './types';
import { users_path, user_path } from './routes';

export default function UsersIndex({ users }: UsersIndexProps) {
  return (
    <div>
      {users.map(user => (
        <a key={user.id} href={user_path(user.id)}>
          {user.name}
        </a>
      ))}
    </div>
  );
}
```

**Standalone Mode:**

nb_routes works perfectly without nb_ts - it generates its own `.d.ts` files:

```typescript
// Import from nb_routes-generated types (standalone)
import { user_path } from './routes';

// TypeScript knows the signature
user_path(123);        // ✓ OK
user_path();           // ✗ Error: Missing required parameter
```

**Key Benefits:**

- 🔄 **Auto-regeneration**: Types update when router changes
- 📦 **Unified exports**: All types in one place (`types/index.ts`)
- ⚡ **Compile-time validation**: Catch route errors during development
- 🎯 **Zero config**: Works automatically when both packages are installed

## How It Works

1. **Route Extraction**: Reads routes from your Phoenix router using `Router.__routes__()`
2. **Serialization**: Converts route patterns into a compact tree structure
3. **Code Generation**: Generates JavaScript helper functions with embedded runtime
4. **Type Generation**: Creates TypeScript definitions with full type safety

The generated code includes a lightweight runtime (~5KB) that handles:
- Parameter substitution
- URL encoding
- Query string building
- Optional segments
- Validation

## Examples

### Basic Route

Phoenix route:
```elixir
get "/users", UserController, :index
```

Generated helper:
```javascript
export const users_path = () => "/users";
```

### Route with Required Parameters

Phoenix route:
```elixir
get "/users/:id", UserController, :show
```

Generated helper:
```javascript
export const user_path = (id, options = {}) => {
  // Validates id is present
  // Returns "/users/123"
};
```

### Route with Optional Format

Phoenix route:
```elixir
get "/users/:id", UserController, :show
```

(Phoenix automatically adds `(.:format)`)

Generated helper:
```javascript
export const user_path = (id, options = {}) => {
  // user_path(1)                    => "/users/1"
  // user_path(1, { format: 'json' }) => "/users/1.json"
};
```

### Nested Routes

Phoenix route:
```elixir
get "/users/:user_id/posts/:id", PostController, :show
```

Generated helper:
```javascript
export const user_post_path = (userId, id, options = {}) => {
  // Returns "/users/1/posts/2"
};
```

## Comparison with js-routes

| Feature | js-routes (Rails) | nb_routes (Phoenix) |
|---------|------------------|---------------------|
| Route extraction | Rails routes | Phoenix routes |
| Module formats | ESM, CJS, UMD, AMD | ESM, CJS, UMD |
| TypeScript | ✓ | ✓ |
| Runtime size | ~3KB | ~5KB |
| Configuration | Ruby DSL | Elixir config |
| Middleware | Rack middleware | Mix task |
| Auto-regeneration | Dev middleware | File watcher (planned) |

## Contributing

Contributions are welcome! Please see the main [nb monorepo](https://github.com/nordbeam/nb) for contribution guidelines.

## License

MIT License. See LICENSE for details.

## Related Packages

- [nb_inertia](../nb_inertia) - Inertia.js integration for Phoenix
- [nb_vite](../nb_vite) - Vite integration for Phoenix
- [nb_ts](../nb_ts) - TypeScript type generation
- [nb_serializer](../nb_serializer) - JSON serialization

## Credits

Inspired by [js-routes](https://github.com/railsware/js-routes) for Rails.
