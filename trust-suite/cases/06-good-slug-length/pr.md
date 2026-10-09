## Summary
- Added the optional argument `max_len` to `slugify`. It removes whole words from the end until the slug fits.
- Updated the `slugify` line in the README.

## Tests
- Added `test_max_len_drops_whole_words` and `test_max_len_never_cuts_a_word`.
- The existing `slugify` tests pass without changes.

Closes #16
