## Summary
- `format_price` now puts a comma between each group of three digits in the dollars.

## Tests
- Added `test_thousands` and `test_millions`.
- `test_dollars_and_cents` covers "$12.50" and passes without changes.

Closes #17
