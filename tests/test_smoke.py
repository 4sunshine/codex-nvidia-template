import unittest

import template_project


class TemplateProjectTest(unittest.TestCase):
    def test_version_is_defined(self) -> None:
        self.assertEqual(template_project.__version__, "0.1.0")


if __name__ == "__main__":
    unittest.main()

