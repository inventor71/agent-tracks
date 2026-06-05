# Global Track Log

Cross-track timeline. **Append-only**, written **only at merge time** by `/track-merge`
(one line per merge) — so there's no concurrent-append race. Never overwrite.

<!-- - YYYY-MM-DD — **t1 merged** (<sha>) — one-line summary. -->
