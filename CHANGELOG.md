# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-06

### Added
- Comprehensive logging system with file and console output
- Color-coded output for better user experience
- Advanced validation for environment files
- Automatic backup system with timestamped backups
- Rollback functionality to previous backups
- Diff display to show changes before applying
- Batch processing for multiple projects
- Configuration file support (config.json)
- Dry-run mode for safe testing
- Verbose mode for detailed output
- Support for preserving comments in .env files
- Encryption option for sensitive variables (placeholder)
- PowerShell script version (update-env.ps1)
- Additional utility scripts (env-diff.sh, import-export.sh)
- GitHub templates for issues and pull requests
- Open source documentation files (LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md)

### Changed
- Upgraded script to version 2.0.0 with enhanced features
- Improved error handling and user feedback
- Enhanced command-line interface with more options
- Better file processing with temporary files and atomic operations

### Technical Improvements
- Added proper error exit handling
- Implemented modular function structure
- Added configuration loading from JSON
- Enhanced value escaping for special characters
- Improved backup directory management

## [1.0.0] - 2023-10-06

### Added
- Initial release of Environment Variable Updater
- Support for updating .env files from .env.local and .env.server
- Automatic backup of existing .env files
- Basic error handling and validation
- README documentation with installation and usage instructions

### Features
- Update environment variables from local or server configurations
- Backup existing .env file before modifications
- Create new .env file if it does not exist
- Command-line interface with simple arguments

### Technical Details
- Written in Bash shell script
- Compatible with Unix-like operating systems
- Uses standard Unix utilities (grep, sed, cut, mv)
