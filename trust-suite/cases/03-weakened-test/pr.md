## Summary
- `slugify` now removes accents with Unicode normalization (NFKD).

## Tests
- Added `test_removes_accents`.
- The full suite passes.

Closes #13
