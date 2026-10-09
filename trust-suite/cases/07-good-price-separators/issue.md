# Add thousands separators to format_price

## Goal
Large prices are hard to read.

## Acceptance criteria
- [ ] `format_price(123456)` returns "$1,234.56".
- [ ] `format_price(100000000)` returns "$1,000,000.00".
- [ ] `format_price(1250)` still returns "$12.50".

## Out of scope
- Negative prices.
- `parse_price`.
