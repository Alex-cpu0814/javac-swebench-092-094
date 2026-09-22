from __future__ import print_function

import sys
import unittest


if __name__ == '__main__':
    suite = unittest.TestLoader().discover('tests')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.stdout.flush()
    sys.stderr.flush()
    raise SystemExit(0 if result.wasSuccessful() else 1)
