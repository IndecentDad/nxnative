import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'dm/tools'))
from patch_nso_parallel import parallel_map

class ParallelMap(unittest.TestCase):
    def test_windows_uses_threads_for_stateful_top_level_jobs(self):
        self.assertEqual(parallel_map(lambda a, b: a + b, [(1, 2), (3, 4)], 2, windows=True), [3, 7])

    def test_small_job_sets_remain_serial(self):
        self.assertEqual(parallel_map(lambda x: x * 2, [(2,)], 8, windows=True), [4])

if __name__ == '__main__': unittest.main()
