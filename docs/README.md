# SHN-01 Documentation

Complete documentation for the SHN-01 OpenComputers control system.

## Table of Contents

### Getting Started
- **[Getting Started Guide](getting-started.md)** - Installation, first boot, and basic operations
  - Installation steps
  - First boot walkthrough
  - Flashing your first node
  - Connecting nodes to the hive
  - Running node scripts
  - Basic console commands

### Understanding the System
- **[Architecture Overview](architecture.md)** - System design and component interactions
  - Boot sequence
  - Core subsystems
  - Network architecture (protocols, sequences, sessions)
  - Client bootstrap flow (2-stage system)
  - Message queue and rate limiting

### Development
- **[Development Guide](development-guide.md)** - Creating custom protocols, sequences, and scripts
  - Creating custom protocols
  - Creating custom sequences
  - Writing node scripts
  - Adding console commands
  - Class system patterns
  - Event system usage
  - Best practices

### Reference
- **[API Reference](api-reference.md)** - Core classes, functions, and events
  - Core classes (`node`, `protocol`, `sequence`, `message`)
  - Global functions
  - Event system
  - File system utilities
  - Database API
  - Crypto utilities

- **[Configuration Reference](configuration.md)** - Settings, conventions, and tuning
  - Database keys
  - Port assignments
  - File naming conventions
  - Path resolution
  - Rate limiting configuration
  - Debug settings

## Quick Links

- [Main README](../README.md) - Project overview and mission statement
- [License](../LICENSE) - MIT License

## About SHN-01

SHN-01 is a minimalist, terminal-driven control system for OpenComputers networks. It provides:

- **Remote node management** - Flash and control distributed nodes from a central hive
- **Real-time code execution** - Deploy and update node scripts without manual intervention
- **Network orchestration** - Coordinate multi-node operations with session-based protocols
- **Tier 1 compatibility** - Runs on minimal hardware (single-block computers)

## Version

Current version: **v0.1-dev**

## Contributing

This is an OpenComputers-based project. Changes are validated by running code in-game or via emulator. For contribution guidelines, see the main README.

## License

MIT License - Copyright (c) 2025 Maximilian Köhler
