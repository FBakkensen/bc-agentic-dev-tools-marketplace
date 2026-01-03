# Contributing to bc-agentic-dev-tools

Thank you for your interest in contributing to the Business Central agentic development tools!

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Search existing issues before creating a new one
- Provide clear steps to reproduce bugs
- Include your environment details (OS, PowerShell version, etc.)

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear, descriptive messages
6. Push to your fork
7. Open a Pull Request

### Code Guidelines

- Follow existing code patterns and structure
- Write clear comments for complex logic
- Update documentation when adding features
- Test PowerShell scripts on PowerShell 7.2+

### Plugin Development

When adding or modifying plugins:

1. Follow the existing plugin structure:
   ```
   plugins/plugin-name/
   ├── plugin.json
   └── skills/
       └── plugin-name/
           ├── SKILL.md
           ├── scripts/
           └── config/
   ```

2. Update `plugin.json` with accurate metadata
3. Write comprehensive `SKILL.md` documentation
4. Test with multiple AI assistants if possible

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove)
- Reference issue numbers when applicable

## Questions?

Open a GitHub Discussion for general questions or ideas.
