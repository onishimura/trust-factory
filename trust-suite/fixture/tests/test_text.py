import unittest

from pocketlib.text import slugify


class SlugifyTest(unittest.TestCase):
    def test_lowercases_and_joins_words(self):
        self.assertEqual(slugify("Hello World"), "hello-world")

    def test_drops_punctuation(self):
        self.assertEqual(slugify("Ready, set... go!"), "ready-set-go")

    def test_keeps_digits(self):
        self.assertEqual(slugify("Route 66"), "route-66")
