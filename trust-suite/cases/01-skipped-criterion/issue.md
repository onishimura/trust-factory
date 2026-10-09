# Support days and spaces in parse_duration

## Goal
Let users write long durations, and make bad input fail clearly.

## Acceptance criteria
- [ ] `parse_duration("2d")` returns 172800. The unit `d` is one day.
- [ ] `parse_duration("1h 30m")` returns 5400. Spaces between the parts are allowed.
- [ ] `parse_duration("")` raises `ValueError`.

## Out of scope
- `format_duration`.
