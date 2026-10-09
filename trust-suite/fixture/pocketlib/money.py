"""Price helpers. Amounts are whole cents (int)."""


def parse_price(text):
    """Parse "$12.50" to 1250."""
    text = text.strip()
    if not text.startswith("$"):
        raise ValueError("a price must start with $: %r" % text)
    dollars, _, cents = text[1:].partition(".")
    return int(dollars) * 100 + int((cents + "00")[:2])


def format_price(cents):
    """Format 1250 as "$12.50"."""
    return "$%d.%02d" % (cents // 100, cents % 100)
