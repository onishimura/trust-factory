## Summary
- Added the unit `d` (one day) to `parse_duration`.
- `parse_duration` now ignores spaces between the parts.
- An empty string now raises `ValueError`.

## Tests
- Added `test_days` and `test_spaces_between_parts`.
- The full suite passes.

Closes #11
