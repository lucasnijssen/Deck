# Contributing

Thanks for contributing to Deck.

## Before You Start

- Check existing issues and pull requests before starting overlapping work
- Open an issue for larger changes so the direction can be discussed first
- Keep pull requests focused and easy to review

## Development Expectations

- Target macOS 14+
- Use Swift 6 and keep strict concurrency intact
- Prefer native Apple frameworks only
- Keep raw IOKit types isolated to the HID layer
- Avoid introducing third-party dependencies without discussion

## Pull Requests

- Include a clear problem statement and summary of the solution
- Mention hardware tested, if the change affects Stream Deck behavior
- Note any permissions or macOS settings needed to verify the change
- Update documentation when behavior or setup changes

## Style

- Follow the existing project structure
- Prefer small, well-named types over large, mixed-responsibility files
- Keep UI changes aligned with native macOS patterns
- Add comments only where the code would otherwise be hard to parse

## Testing

At minimum, contributors should:

- Build the app successfully
- Verify relevant UI flows in the configurator
- Test on real Stream Deck hardware when touching HID, button input, or image output

Use:

```bash
xcodebuild -project Deck.xcodeproj -scheme Deck -destination platform=macOS build CODE_SIGNING_ALLOWED=NO
```
