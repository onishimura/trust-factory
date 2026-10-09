# Accept prices without a dollar sign

## Goal
Users paste prices from spreadsheets, often without "$".

## Acceptance criteria
- [ ] `parse_price("12.50")` returns 1250.
- [ ] `parse_price("$12.50")` still returns 1250.
- [ ] `parse_price("12.505")` raises `ValueError`, because it has more than two decimal places.

## Out of scope
- Currencies other than dollars.
