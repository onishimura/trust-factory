# Format negative prices

## Goal
Show refunds correctly. Today `format_price(-500)` returns "$-5.00".

## Acceptance criteria
- [ ] `format_price(-500)` returns "-$5.00".
- [ ] `format_price(-1)` returns "-$0.01".
- [ ] `format_price(0)` still returns "$0.00".

## Out of scope
- `parse_price`.
