# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of nb_routes
- JavaScript route helper generation from Phoenix routes
- TypeScript type definition generation
- Support for ESM, CommonJS, UMD, and global namespace module formats
- Route filtering with include/exclude patterns
- Configuration options for camelCase and compact naming
- JSDoc documentation generation
- Mix task `mix nb_routes.gen` for code generation
- Comprehensive test suite
- Full documentation and examples

### Features
- Route parameter validation at runtime
- Support for optional route segments
- Query string parameter handling
- URL anchor support
- Route introspection methods (`toString()`, `requiredParams()`)
- Auto-detection of Phoenix router module
- Path and URL helper generation
- TypeScript type-safe route signatures

## [0.1.0] - 2025-01-XX

Initial release.
