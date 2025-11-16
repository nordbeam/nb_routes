# NbRoutes

Generate JavaScript/TypeScript route helpers from Phoenix routes. A port of [js-routes](https://github.com/railsware/js-routes) for Rails to Phoenix/Elixir.

## Features

- **Type-safe route generation** - Generate paths with compile-time validation
- **TypeScript support** - Auto-generate `.d.ts` files with full type information
- **Multiple module formats** - ESM, CommonJS, UMD, or global namespace
- **Flexible configuration** - Include/exclude routes, camelCase naming, URL helpers
- **Integration ready** - Works seamlessly with `nb_vite`, `nb_inertia`, and `nb_ts`
- **Development watcher** - Auto-regenerate routes when router changes

## Installation

Add `nb_routes` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:nb_routes, "~> 0.1.0"}
  ]
end
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

## Configuration

Configure in `config/config.exs`:

```elixir
config :nb_routes,
  module_type: :esm,                    # :esm | :cjs | :umd | nil
  output_file: "assets/js/routes.js",
  router: MyAppWeb.Router,              # Optional - auto-detected if not set
  include: [~r/^api_/],                 # Only include API routes
  exclude: [~r/^admin_/],               # Exclude admin routes
  camel_case: false,                    # Convert to camelCase
  compact: false,                       # Remove _path suffix
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

For automatic route regeneration during development, add to `config/dev.exs`:

```elixir
config :nb_routes,
  watch: true  # Auto-regenerate on router changes
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
