# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-04-10

### Added

- Req plugin with automatic GCS authentication via request step
- Three authentication modes: named Goth process, inline credentials, and application config
- Automatic token caching with managed Goth processes for inline/app-config credentials
- Background token sweeper to stop idle managed Goth processes
- Bucket operations: list, get, create, update, delete
- Object operations: list, get, download, upload, delete, copy, compose
- `Req.Test`-friendly design (auth step is skipped when `:auth` is already set)
