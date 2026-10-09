# Accept uppercase units in parse_duration

## Goal
Users type "1H30M". Today this raises `ValueError`.

## Acceptance criteria
- [ ] `parse_duration("1H30M")` returns 5400.
- [ ] `parse_duration("2M5s")` returns 125 (mixed case).
- [ ] Unknown units still raise `ValueError`, also in uppercase ("3W").

## Out of scope
- New units.
