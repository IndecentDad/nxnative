"""Parallel execution for patch_nso read-only scan jobs."""
from concurrent.futures import ThreadPoolExecutor
import multiprocessing
import os

def parallel_map(fn, jobs, workers, windows=None):
    jobs = list(jobs)
    if workers < 2 or len(jobs) < 2:
        return [fn(*job) for job in jobs]
    windows = os.name == 'nt' if windows is None else windows
    count = min(workers, len(jobs))
    if windows:
        # patch_nso performs substantial work at module scope; spawn would re-run that work in every child.
        with ThreadPoolExecutor(max_workers=count) as pool:
            return list(pool.map(lambda job: fn(*job), jobs))
    with multiprocessing.get_context('fork').Pool(count) as pool:
        return pool.starmap(fn, jobs)
