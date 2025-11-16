# CLAUDE.md - nb_routes

Developer guidance for Claude Code when working with the nb_routes package.

## Package Overview

**nb_routes** generates JavaScript/TypeScript route helpers from Phoenix routes. It's a port of [js-routes](https://github.com/railsware/js-routes) for Rails to the Phoenix/Elixir ecosystem.

**Location**: `/Users/assim/Projects/nb/nb_routes`

## Architecture

### Core Components

1. **NbRoutes** (`lib/nb_routes.ex`)
   - Main public API
   - Orchestrates route generation and file writing
   - Functions: `generate/2`, `generate!/3`, `definitions/2`, `definitions!/3`, `routes/2`

2. **NbRoutes.Configuration** (`lib/nb_routes/configuration.ex`)
   - Configuration struct with validation
   - Options: module_type, output_file, include/exclude patterns, camel_case, variant (simple/rich), with_methods, with_forms, etc.

3. **NbRoutes.Route** (`lib/nb_routes/route.ex`)
   - Represents a single Phoenix route
   - Converts Phoenix.Router.Route to internal format
   - Handles name generation (camelCase, compact, etc.)

4. **NbRoutes.Generator** (`lib/nb_routes/generator.ex`)
   - Extracts routes from Phoenix router via `__routes__()`
   - Filters routes based on include/exclude patterns
   - Auto-detects router module

5. **NbRoutes.Serializer** (`lib/nb_routes/serializer.ex`)
   - Serializes route segments into JavaScript-compatible format
   - Node types: `:literal`, `:param`, `:glob`, `:optional`
   - Generates parameter metadata (required/optional/defaults)

6. **NbRoutes.CodeGenerator** (`lib/nb_routes/code_generator.ex`)
   - Generates JavaScript code (ESM, CJS, UMD, or global)
   - Embeds runtime library
   - Adds JSDoc documentation

7. **NbRoutes.TypeGenerator** (`lib/nb_routes/type_generator.ex`)
   - Generates TypeScript `.d.ts` files
   - Type-safe route helper signatures
   - Introspection method types

8. **JavaScript Runtime** (`priv/nb_routes/runtime.js`)
   - RouteBuilder class
   - Handles parameter extraction, validation, URL building
   - Support for query strings, anchors, absolute URLs

9. **Mix Task** (`lib/mix/tasks/nb_routes.gen.ex`)
   - CLI interface: `mix nb_routes.gen`
   - Command-line options for configuration

### Data Flow

```
Phoenix Router
  ↓
Generator.extract_routes()
  ↓
[Route structs]
  ↓
Serializer.serialize()
  ↓
Route specifications
  ↓
CodeGenerator.generate() / TypeGenerator.generate()
  ↓
JavaScript + TypeScript files
```

### Route Serialization Format

Routes are serialized into a compact tree structure:

```elixir
# Route: /users/:id/posts(.:format)
# Serialized to:
[
  "/users/",
  [:param, "id"],
  "/posts",
  [:optional, [".", [:param, "format"]]]
]

# Parameters:
%{
  "id" => %{required: true},
  "format" => %{}
}
```

## Rich Mode Implementation

### Overview

Rich mode is an advanced route generation variant that returns objects instead of strings:

```javascript
// Simple mode
user_path(1)  // => "/users/1"

// Rich mode
user_path(1)  // => { url: "/users/1", method: "get" }
```

### Architecture

**Configuration Options (Configuration.ex):**
- `variant`: `:simple` | `:rich` - Controls helper output format
- `with_methods`: `boolean` - Enables method variants (`.get`, `.post`, etc.)
- `with_forms`: `boolean` - Enables form helpers (`.form`, `.form.patch`, etc.)

**Code Generation Flow:**

1. **Mode Detection** (`CodeGenerator.generate_route_helper/5` - line 279-286)
   - Checks `config.variant`
   - Branches to either `generate_simple_route_helper/4` or `generate_rich_route_helper/5`

2. **Rich Helper Generation** (`generate_rich_route_helper/5` - line 306-350)
   - Generates main function returning `{ url, method }`
   - Uses `Object.assign` pattern to add variants as properties
   - Calls `_buildUrl` helper for URL construction

3. **Method Variants** (`generate_method_variants/5` - line 373-429)
   - Generated when `with_methods: true`
   - Creates `.get`, `.head`, `.url` variants for all routes
   - Adds method-specific variant for the route's HTTP verb (`.post`, `.patch`, `.put`, `.delete`)

4. **Form Helpers** (`generate_form_variants/4` - line 435-486)
   - Generated when `with_forms: true` and route is a mutation (POST/PATCH/PUT/DELETE)
   - Creates `.form` property with nested structure
   - Uses `_buildFormAction` for method spoofing

### Helper Functions

**`_buildUrl` (lines 92-149):**
- Replaces `:param` placeholders in URL pattern
- Handles `query` and `mergeQuery` options
- Adds anchor hash if provided
- Exported in rich mode for direct use

**`_buildFormAction` (lines 151-190):**
- Wraps `_buildUrl` for form-specific logic
- Adds `_method` query parameter for non-GET/POST methods (method spoofing)
- Returns URL suitable for HTML form action attributes

### TypeScript Type Generation

**Rich Mode Interfaces** (`TypeGenerator.generate_types/1` - lines 45-144):

1. **RouteResult** (lines 54-60)
   ```typescript
   interface RouteResult {
     url: string;
     method: 'get' | 'post' | 'patch' | 'put' | 'delete' | 'head' | 'options';
   }
   ```

2. **RouteOptions** (lines 74-82 for rich, 166-173 for rich)
   ```typescript
   interface RouteOptions {
     anchor?: string;
     query?: Record<string, RouteParameter>;
     mergeQuery?: Record<string, RouteParameter | null | undefined>;
   }
   ```

3. **FormAttributes** (lines 63-70)
   ```typescript
   interface FormAttributes {
     action: string;  // URL with _method param
     method: 'get' | 'post';
   }
   ```

4. **RouteHelper / RouteHelperWithForm** (lines 107-141)
   - Different interfaces based on `with_forms` config
   - RouteHelperWithForm includes `.form` property
   - Applied per-route based on HTTP method (only mutation routes get form helpers)

### Export Strategy

Rich mode exports additional helpers (`generate_exports/1` - lines 507-599):

**ESM exports (lines 507-513):**
```javascript
export const configure = (options) => _builder.configure(options);
export const config = () => _builder.getConfig();
export { _buildUrl };  // Only in rich mode
```

**CommonJS exports (lines 524-530):**
```javascript
module.exports._buildUrl = _buildUrl;  // Only in rich mode
```

### Testing

Rich mode tests in `test/nb_routes/code_generator_test.exs`:

1. **Basic rich mode** (lines 49-69): Object.assign pattern
2. **Method variants** (lines 92-114): .get, .head, .url variants
3. **Form helpers** (lines 237-305): .form, .form.patch, .form.put, .form.delete
4. **_buildUrl export** (lines 199-205): Exported in ESM
5. **_buildFormAction helper** (lines 306-326): Method spoofing logic

## Key Design Decisions

1. **Optional Dependencies**: None - nb_routes is standalone
2. **Dual Mode System**: Supports both simple mode (URL strings) and rich mode (objects with method info)
3. **Module Formats**: Supports ESM, CJS, UMD, and global namespace
4. **Code Generation**: Compile-time generation via Mix task
5. **Route Introspection**: Uses `Phoenix.Router.__routes__()`
6. **Method Variants**: Rich mode provides `.get`, `.post`, `.url` variants for flexibility
7. **Form Integration**: Optional form helpers with automatic method spoofing for HTML forms

## Common Development Tasks

### Adding New Configuration Options

1. Update `NbRoutes.Configuration` struct
2. Add validation in `Configuration.validate/1`
3. Update `Mix.Tasks.NbRoutes.Gen` to accept CLI flag
4. Update `CodeGenerator` or `TypeGenerator` to use the option
5. Update README.md and documentation

### Modifying Route Serialization

1. Update segment parsing in `NbRoutes.Route.parse_path_segments/1`
2. Update serialization in `NbRoutes.Serializer.serialize_segment/1`
3. Update JavaScript runtime in `priv/nb_routes/runtime.js` (`_evaluateNode`)
4. Add tests in `test/nb_routes/serializer_test.exs`

### Changing Generated Code Format

1. Update `NbRoutes.CodeGenerator.generate_*/1` functions
2. Ensure runtime compatibility
3. Update examples in README.md
4. Test with different module formats

### Adding New Module Format

1. Add format to `Configuration.module_type` typespec
2. Update `CodeGenerator.generate_exports/1` with new case
3. Update `Configuration.validate/1` to accept new type
4. Add tests

## Testing Strategy

### Unit Tests

Each module has corresponding tests:
- `test/nb_routes/configuration_test.exs`
- `test/nb_routes/route_test.exs`
- `test/nb_routes/serializer_test.exs`

Run tests:
```bash
cd nb_routes
mix test
```

### Integration Tests

For full integration testing, create a test Phoenix app:

```bash
cd /tmp
mix phx.new test_app
cd test_app

# Add nb_routes as path dependency
# Edit mix.exs:
{:nb_routes, path: "/Users/assim/Projects/nb/nb_routes"}

mix deps.get
mix nb_routes.gen
```

### Manual Testing

Test generated output:

```bash
# Generate routes
mix nb_routes.gen

# Inspect output
cat assets/js/routes.js
cat assets/js/routes.d.ts

# Test with Node.js
node -e "const {users_path} = require('./assets/js/routes.js'); console.log(users_path())"
```

## File Organization

```
nb_routes/
├── lib/
│   ├── nb_routes.ex                 # Main API
│   ├── nb_routes/
│   │   ├── configuration.ex         # Config struct
│   │   ├── route.ex                 # Route representation
│   │   ├── generator.ex             # Route extraction
│   │   ├── serializer.ex            # Serialization
│   │   ├── code_generator.ex        # JavaScript generation
│   │   └── type_generator.ex        # TypeScript generation
│   └── mix/tasks/
│       └── nb_routes.gen.ex         # Mix task
├── priv/
│   └── nb_routes/
│       └── runtime.js               # JavaScript runtime
├── test/
│   ├── test_helper.exs
│   ├── nb_routes_test.exs
│   └── nb_routes/                   # Module-specific tests
├── mix.exs
├── README.md                        # User documentation
└── CLAUDE.md                        # This file
```

## Integration with Other nb_* Packages

### Standalone

nb_routes has no dependencies on other nb_* packages. It works independently.

### With nb_vite

**Integration Status**: ✅ Fully integrated

Routes are auto-regenerated when router changes using the `vite-plugin-nb-routes` Vite plugin.

#### Implementation

**Plugin Location**: `nb_vite/priv/nb_vite/src/vite-plugin-nb-routes.ts`

**Features:**
1. **File Watching**: Uses Vite's built-in watcher to detect router.ex changes
2. **Auto-regeneration**: Spawns `mix nb_routes.gen` when changes detected
3. **HMR Integration**: Invalidates routes module and triggers hot reload
4. **Debouncing**: Prevents excessive regeneration during rapid changes (default: 300ms)
5. **Configurable**: Supports custom router paths, commands, and options

**Usage** (`assets/vite.config.ts`):
```typescript
import { defineConfig } from 'vite';
import phoenix from '@nordbeam/nb-vite';
import { nbRoutes } from '@nordbeam/nb-vite/nb-routes';

export default defineConfig({
  plugins: [
    phoenix({ input: ['js/app.ts'] }),
    nbRoutes({
      enabled: true,
      routerPath: ['lib/**/*_web/router.ex'],
      routesFile: 'assets/js/routes.js',
      command: 'mix nb_routes.gen',
      debounce: 300,
      verbose: false
    })
  ]
});
```

**How it works:**
1. Plugin registers with Vite's `configureServer` hook
2. Listens to Vite's file watcher for changes
3. Matches changed files against router patterns
4. Triggers debounced regeneration
5. Invalidates routes module in Vite's module graph
6. Sends HMR update to browser

**Key Functions** (in vite-plugin-nb-routes.ts):
- `regenerateRoutes()` (lines 87-128): Spawns mix command
- `debouncedRegenerate()` (lines 133-142): Debounces regeneration
- `invalidateRoutesModule()` (lines 147-180): HMR invalidation
- `matchesRouterPattern()` (lines 185-197): Pattern matching

### With nb_inertia

Route helpers are commonly used in Inertia.js frontends:

```typescript
import { router } from '@inertiajs/react';
import { user_path } from './routes';

router.visit(user_path(user.id));
```

### With nb_ts

**Integration Status**: ✅ Fully integrated (optional)

nb_routes integrates with nb_ts for unified type generation and automatic regeneration:

#### How It Works

1. **Type Metadata Export**: nb_routes exports route metadata via `__nb_routes_type_metadata__/0`
2. **Compile Hooks**: Registers `@after_compile` hook with nb_ts (when available)
3. **Auto-discovery**: nb_ts can discover the router and generate route types
4. **Conditional Compilation**: Uses `Code.ensure_loaded?(NbTs.CompileHooks)` - no hard dependency

#### Integration Functions

**In `lib/nb_routes.ex`:**

```elixir
# Compile hook (line 57-62)
if Code.ensure_loaded?(NbTs.CompileHooks) do
  @after_compile {NbTs.CompileHooks, :__after_compile__}
end

# Router detection (line 225-228)
def __nb_routes_router__ do
  config = build_config([])
  config.router || Generator.detect_router()
end

# Type metadata export (line 259-277)
def __nb_routes_type_metadata__ do
  case __nb_routes_router__() do
    nil -> []
    router ->
      routes = Generator.extract_routes(router, [])
      Enum.map(routes, fn route ->
        %{
          name: route.name,
          path: route.path,
          verb: route.verb,
          required_params: route.required_params,
          optional_params: route.optional_params
        }
      end)
  end
end
```

#### Usage Modes

**Standalone Mode** (nb_routes only):
```bash
mix nb_routes.gen
# Generates:
# - assets/js/routes.js
# - assets/js/routes.d.ts (standalone types)
```

**Unified Mode** (nb_routes + nb_ts):
```bash
mix nb_ts.gen.types
# nb_ts discovers routes automatically
# Generates:
# - assets/js/routes.js (from nb_routes)
# - assets/js/types/index.ts (includes route types from nb_ts)
```

**Auto-regeneration** (when router changes):
```elixir
# In router module (e.g., lib/my_app_web/router.ex)
# When router is recompiled:
# 1. nb_routes @after_compile hook fires
# 2. nb_ts is notified
# 3. Route types are regenerated automatically
```

#### Benefits

- **Zero Configuration**: Works automatically when both installed
- **Optional Dependency**: nb_routes works standalone
- **Unified Types**: All types in one location (`types/index.ts`)
- **Auto-regeneration**: Types update on router changes
- **Type Safety**: Full TypeScript support for route helpers

#### Testing Integration

To test nb_ts integration:

```bash
# Create test app with both packages
cd /tmp
mix phx.new test_app
cd test_app

# Add dependencies
# In mix.exs:
{:nb_routes, path: "/Users/assim/Projects/nb/nb_routes"},
{:nb_ts, path: "/Users/assim/Projects/nb/nb_ts"}

mix deps.get
mix compile

# Test unified generation
mix nb_ts.gen.types

# Verify route types are included
cat assets/js/types/index.ts
```

### With nb_serializer

Route helpers can accept serializer output:

```typescript
// Serializer output
const user = { id: 123, name: "John" };

// Route helper extracts id automatically
user_path(user);  // => "/users/123"
```

## Common Issues and Solutions

### Issue: Routes not being generated

**Cause**: Router module not found or not compiled

**Solution**:
1. Ensure router is compiled: `mix compile`
2. Check router module name
3. Specify router explicitly: `mix nb_routes.gen --router MyAppWeb.Router`

### Issue: TypeScript types not matching runtime

**Cause**: Mismatch between TypeGenerator and CodeGenerator output

**Solution**:
1. Ensure both use same route list
2. Verify parameter extraction logic matches
3. Test with actual TypeScript code

### Issue: Runtime errors with complex routes

**Cause**: Serialization doesn't handle edge case

**Solution**:
1. Add test case reproducing the issue
2. Update `Route.parse_path_segments/1`
3. Update JavaScript runtime to handle new node type
4. Verify with integration test

### Issue: Generated code too large

**Cause**: Runtime library is embedded in every file

**Solution** (planned):
1. Extract runtime to separate file
2. Import runtime in generated code
3. Update CodeGenerator to reference external runtime

## Future Enhancements

### High Priority

1. **File Watcher** - Auto-regenerate on router changes
   - Watch `lib/*_web/router.ex`
   - Integration with nb_vite dev server
   - Module: `NbRoutes.Watcher`

2. **Igniter Installer** - Automated setup
   - `mix igniter.install nb_routes`
   - Add to assets config
   - Configure gitignore

3. **URL Helpers** - Generate `*_url` helpers
   - Absolute URLs with host/port
   - Already planned in Configuration

### Medium Priority

4. **Advanced TypeScript Types**
   - Conditional types for required vs optional params
   - Union types for format parameter
   - Generic route helper type

5. **Performance Optimization**
   - External runtime file (not embedded)
   - Tree-shaking friendly exports
   - Minification option

6. **Scope Support**
   - Preserve Phoenix scope information
   - Namespace route helpers by scope

### Low Priority

7. **Plugin System**
   - Custom serializers
   - Custom code generators
   - Middleware hooks

8. **CLI Enhancements**
   - Interactive mode
   - Diff preview before writing
   - Statistics and analysis

## Debugging Tips

### Enable Verbose Output

Add IO.inspect calls to trace execution:

```elixir
routes = Generator.extract_routes(router, opts)
IO.inspect(routes, label: "Extracted Routes")
```

### Inspect Generated Code

Generate to stdout instead of file:

```elixir
code = NbRoutes.generate(MyAppWeb.Router)
IO.puts(code)
```

### Test JavaScript Runtime Directly

```javascript
// In browser console or Node.js
const builder = new RouteBuilder();
const route = builder.route(
  { id: { required: true } },
  ["/users/", ["param", "id"]],
  false
);
console.log(route(123));  // => "/users/123"
```

### Check Route Extraction

```elixir
# In IEx
routes = MyAppWeb.Router.__routes__()
Enum.filter(routes, & &1.helper == "user")
```

## Dependencies

Current dependencies:
- `phoenix` (~> 1.7) - For route introspection
- `ex_doc` (dev) - For documentation generation

No runtime dependencies on other nb_* packages.

## Publishing Checklist

Before publishing to Hex:

1. Run all tests: `mix test`
2. Run formatter: `mix format`
3. Generate docs: `mix docs`
4. Update CHANGELOG.md
5. Update version in mix.exs
6. Verify package files: `mix hex.build`
7. Publish: `mix hex.publish`

## Related Resources

- **Source**: https://github.com/nordbeam/nb/tree/main/nb_routes
- **Inspiration**: https://github.com/railsware/js-routes
- **Phoenix Routing**: https://hexdocs.pm/phoenix/routing.html
- **Monorepo CLAUDE.md**: ../CLAUDE.md
