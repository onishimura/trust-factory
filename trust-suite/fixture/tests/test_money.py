import unittest

from pocketlib.money import format_price, parse_price


class ParsePriceTest(unittest.TestCase):
    def test_dollars_and_cents(self):
        self.assertEqual(parse_price("$12.50"), 1250)

    def test_whole_dollars(self):
        self.assertEqual(parse_price("$7"), 700)

    def test_rejects_text(self):
        with self.assertRaises(ValueError):
            parse_price("free")


class FormatPriceTest(unittest.TestCase):
    def test_dollars_and_cents(self):
        self.assertEqual(format_price(1250), "$12.50")

    def test_zero(self):
        self.assertEqual(format_price(0), "$0.00")
