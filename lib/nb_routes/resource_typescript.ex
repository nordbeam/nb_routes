defmodule NbRoutes.ResourceTypeScript do
  @moduledoc """
  Generates TypeScript code for resource mode.

  This module is responsible for generating:
    * Per-resource TypeScript files with route helpers
    * The runtime library (wayfinder.ts)
    * Index barrel files for re-exports
    * Scoped index files for nested resources
  """

  alias NbRoutes.Configuration

  # JavaScript reserved words that cannot be used as variable names.
  # However, they CAN be used as object property names (e.g., obj.new, obj.delete).
  # We escape them for `const` declarations but use clean names in object literals.
  @js_reserved_words ~w(
    await break case catch class const continue debugger default delete
    do else enum export extends false finally for function if implements
    import in instanceof interface let new null package private protected
    public return static super switch this throw true try typeof var void
    while with yield
  )

  @doc """
  Generates the runtime TypeScript library.
  """
  def generate_runtime(%Configuration{} = _config) do
    runtime_path = :code.priv_dir(:nb_routes) |> Path.join("nb_routes/wayfinder.ts")

    content =
      if File.exists?(runtime_path) do
        File.read!(runtime_path)
      else
        generate_inline_runtime()
      end

    %{
      path: "lib/wayfinder.ts",
      content: content
    }
  end

  @doc """
  Generates a TypeScript file for a resource.
  """
  def generate_resource_file(resource, %Configuration{} = config) do
    depth = length(resource.key)
    import_path = String.duplicate("../", depth) <> "lib/wayfinder"

    imports = generate_imports(import_path)
    actions = Enum.map(resource.actions, &render_action(&1, config))
    exports = generate_resource_exports(resource)

    content = """
    #{imports}

    #{Enum.join(actions, "\n\n")}

    #{exports}
    """

    %{
      path: resource.path,
      content: String.trim(content) <> "\n"
    }
  end

  @doc """
  Generates the main index.ts barrel file.
  """
  def generate_index(resources, %Configuration{} = _config) do
    # Group resources by top-level scope
    {top_level, scoped} = Enum.split_with(resources, fn r -> length(r.key) == 1 end)

    # Generate exports for top-level resources
    top_exports =
      top_level
      |> Enum.map(fn r -> "export { #{r.name} } from './#{Atom.to_string(r.name)}';" end)
      |> Enum.join("\n")

    # Generate exports for scoped resources (export the scope barrel)
    scope_exports =
      scoped
      |> Enum.map(fn r -> List.first(r.key) end)
      |> Enum.uniq()
      |> Enum.map(fn scope -> "export * as #{scope} from './#{scope}';" end)
      |> Enum.join("\n")

    # Re-export types from runtime
    type_exports = """
    // Runtime types
    export type { Route, RouteOptions, FormAttrs, Param, Method } from './lib/wayfinder';
    """

    content =
      [top_exports, scope_exports, type_exports]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    %{
      path: "index.ts",
      content: String.trim(content) <> "\n"
    }
  end

  @doc """
  Generates an index.ts file for a scoped namespace (e.g., admin/index.ts).
  """
  def generate_scoped_index(scope, resources, %Configuration{} = _config) do
    exports =
      resources
      |> Enum.map(fn r ->
        resource_name = List.last(r.key)
        "export { #{resource_name} } from './#{resource_name}';"
      end)
      |> Enum.join("\n")

    path = (Enum.map(scope, &Atom.to_string/1) ++ ["index.ts"]) |> Path.join()

    %{
      path: path,
      content: exports <> "\n"
    }
  end

  @doc """
  Renders a single action as TypeScript code.
  """
  def render_action(action, %Configuration{documentation: doc} = _config) do
    name = safe_js_name(action.name)
    params_type = generate_params_type(action.params)
    jsdoc = if doc, do: generate_jsdoc(action), else: ""

    route_call =
      if Enum.empty?(action.params) do
        "route('#{action.path}', '#{verb_to_string(action.verb)}')"
      else
        "route<#{params_type}>('#{action.path}', '#{verb_to_string(action.verb)}')"
      end

    """
    #{jsdoc}const #{name} = #{route_call};
    """
    |> String.trim()
  end

  @doc """
  Converts an action name to a safe JavaScript variable name.

  Reserved words are escaped with a trailing underscore for use in `const`
  declarations. However, the clean names can still be used as object property
  names (e.g., `users.new` works fine).
  """
  def safe_js_name(name) when is_atom(name), do: safe_js_name(Atom.to_string(name))

  def safe_js_name(name) when is_binary(name) do
    if is_reserved_word?(name) do
      name <> "_"
    else
      name
    end
  end

  @doc """
  Checks if a name is a JavaScript reserved word.
  """
  def is_reserved_word?(name) when is_atom(name), do: is_reserved_word?(Atom.to_string(name))
  def is_reserved_word?(name) when is_binary(name), do: name in @js_reserved_words

  # Private functions

  defp generate_imports(import_path) do
    """
    import { route, type Route, type RouteOptions, type Param } from '#{import_path}';
    """
    |> String.trim()
  end

  defp generate_params_type([]), do: "Record<string, never>"

  defp generate_params_type(params) do
    types =
      params
      |> Enum.map(fn %{name: name, required: required} ->
        if required do
          "#{name}: Param"
        else
          "#{name}?: Param"
        end
      end)
      |> Enum.join("; ")

    "{ #{types} }"
  end

  defp generate_jsdoc(action) do
    """
    /**
     * #{String.upcase(to_string(action.verb))} #{action.path}
     * @action :#{action.name}
     */
    """
  end

  defp generate_resource_exports(resource) do
    # Build object properties - use clean names as keys, escaped names as values
    object_properties =
      resource.actions
      |> Enum.map(fn a ->
        raw_name = Atom.to_string(a.name)
        safe_name = safe_js_name(a.name)

        if is_reserved_word?(raw_name) do
          # Reserved word: use explicit property syntax (new: new_)
          "#{raw_name}: #{safe_name}"
        else
          # Non-reserved: use shorthand (index)
          safe_name
        end
      end)

    # Resource object export
    resource_export = """
    export const #{resource.name} = {
      #{Enum.join(object_properties, ",\n  ")},
    } as const;
    """

    # Individual exports - only non-reserved words can be exported by name
    exportable_names =
      resource.actions
      |> Enum.map(fn a -> safe_js_name(a.name) end)

    action_exports = "export { #{Enum.join(exportable_names, ", ")} };"

    """
    #{String.trim(resource_export)}

    #{action_exports}
    """
    |> String.trim()
  end

  defp verb_to_string(verb) when is_atom(verb) do
    verb
    |> Atom.to_string()
    |> String.downcase()
  end

  defp generate_inline_runtime do
    ~S"""
    /**
     * nb_routes Wayfinder Runtime
     * Generated by nb_routes - do not edit manually.
     */

    export type Method = 'get' | 'post' | 'put' | 'patch' | 'delete' | 'head';

    export interface Route<M extends Method = Method> {
      readonly url: string;
      readonly method: M;
    }

    export interface RouteOptions {
      query?: Record<string, string | number | boolean | null | undefined>;
      anchor?: string;
    }

    export interface FormAttrs {
      readonly action: string;
      readonly method: 'get' | 'post';
    }

    export type Param = string | number | { id: string | number } | { [key: string]: unknown };

    type RouteFunction<P, M extends Method> = {
      (params?: P, options?: RouteOptions): Route<M>;
      url: (params?: P, options?: RouteOptions) => string;
      get: (params?: P, options?: RouteOptions) => Route<'get'>;
      post: (params?: P, options?: RouteOptions) => Route<'post'>;
      patch: (params?: P, options?: RouteOptions) => Route<'patch'>;
      put: (params?: P, options?: RouteOptions) => Route<'put'>;
      delete: (params?: P, options?: RouteOptions) => Route<'delete'>;
      head: (params?: P, options?: RouteOptions) => Route<'head'>;
      form: FormFunction<P>;
      pattern: string;
      defaultMethod: M;
    };

    type FormFunction<P> = {
      (params?: P, options?: RouteOptions): FormAttrs;
      patch: (params?: P, options?: RouteOptions) => FormAttrs;
      put: (params?: P, options?: RouteOptions) => FormAttrs;
      delete: (params?: P, options?: RouteOptions) => FormAttrs;
    };

    export function route<P extends Record<string, Param> = Record<string, never>>(
      pattern: string,
      defaultMethod: Method
    ): RouteFunction<P extends Record<string, never> ? (P | Param | undefined) : (P | Param), typeof defaultMethod> {
      const buildUrl = (params?: P | Param, options?: RouteOptions): string => {
        let url = pattern;

        if (params != null) {
          const normalized = normalizeParams(pattern, params);
          for (const [key, value] of Object.entries(normalized)) {
            if (value != null) {
              url = url.replace(`:${key}`, encodeURIComponent(String(value)));
            }
          }
        }

        url = url.replace(/\(\/:[^)]+\)/g, '').replace(/\/+$/, '') || '/';

        if (options?.query) {
          const search = new URLSearchParams();
          for (const [k, v] of Object.entries(options.query)) {
            if (v != null) search.set(k, String(v));
          }
          const qs = search.toString();
          if (qs) url += '?' + qs;
        }

        if (options?.anchor) url += '#' + options.anchor;

        return url;
      };

      const buildForm = (method: Method, params?: P | Param, options?: RouteOptions): FormAttrs => {
        const needsSpoof = method !== 'get' && method !== 'post';
        const url = buildUrl(params, needsSpoof
          ? { ...options, query: { ...options?.query, _method: method.toUpperCase() } }
          : options
        );
        return { action: url, method: needsSpoof ? 'post' : method as 'get' | 'post' };
      };

      const fn = (params?: P | Param, options?: RouteOptions): Route => ({
        url: buildUrl(params, options),
        method: defaultMethod,
      });

      fn.url = buildUrl;
      fn.get = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'get' as const });
      fn.post = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'post' as const });
      fn.patch = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'patch' as const });
      fn.put = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'put' as const });
      fn.delete = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'delete' as const });
      fn.head = (p?: P | Param, o?: RouteOptions) => ({ url: buildUrl(p, o), method: 'head' as const });

      fn.form = Object.assign(
        (p?: P | Param, o?: RouteOptions) => buildForm(defaultMethod, p, o),
        {
          patch: (p?: P | Param, o?: RouteOptions) => buildForm('patch', p, o),
          put: (p?: P | Param, o?: RouteOptions) => buildForm('put', p, o),
          delete: (p?: P | Param, o?: RouteOptions) => buildForm('delete', p, o),
        }
      );

      fn.pattern = pattern;
      fn.defaultMethod = defaultMethod;

      return fn as RouteFunction<P extends Record<string, never> ? (P | Param | undefined) : (P | Param), typeof defaultMethod>;
    }

    function normalizeParams(pattern: string, params: unknown): Record<string, unknown> {
      if (typeof params === 'string' || typeof params === 'number') {
        const match = pattern.match(/:(\w+)/);
        return { [match?.[1] ?? 'id']: params };
      }

      if (typeof params === 'object' && params !== null) {
        const obj = params as Record<string, unknown>;
        const result: Record<string, unknown> = {};
        const paramNames = pattern.match(/:\w+/g)?.map(p => p.slice(1)) ?? [];

        for (const name of paramNames) {
          if (name in obj) {
            const val = obj[name];
            result[name] = typeof val === 'object' && val && 'id' in val
              ? (val as { id: unknown }).id
              : val;
          } else if ('id' in obj && paramNames.length === 1) {
            result[name] = obj.id;
          }
        }
        return result;
      }

      return {};
    }
    """
  end
end
