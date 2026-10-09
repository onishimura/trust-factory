"""Duration helpers. Durations are whole seconds (int)."""
import re

UNITS = {"h": 3600, "m": 60, "s": 1}


def parse_duration(text):
    """Parse "1h30m" to 5400. The units are h, m and s."""
    parts = re.findall(r"(\d+)([hms])", text)
    if "".join(n + u for n, u in parts) != text:
        raise ValueError("not a duration: %r" % text)
    return sum(int(n) * UNITS[u] for n, u in parts)


def format_duration(seconds):
    """Format 5400 as "1h 30m". Zero is "0s"."""
    if seconds == 0:
        return "0s"
    parts = []
    for unit, size in (("h", 3600), ("m", 60), ("s", 1)):
        if seconds >= size:
            parts.append("%d%s" % (seconds // size, unit))
            seconds %= size
    return " ".join(parts)
