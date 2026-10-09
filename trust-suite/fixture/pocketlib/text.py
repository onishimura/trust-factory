"""Text helpers."""
import re


def slugify(text):
    """Make a URL slug: lowercase ASCII letters and digits, words joined with "-"."""
    return "-".join(re.findall(r"[a-z0-9]+", text.lower()))
