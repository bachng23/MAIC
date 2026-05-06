import pytest
from fastapi import HTTPException

from app.services.rate_limiter import InMemoryRateLimiter


def test_rate_limiter_allows_requests_under_limit() -> None:
    limiter = InMemoryRateLimiter()

    limiter.check("bucket", max_requests=2, window_seconds=60)
    limiter.check("bucket", max_requests=2, window_seconds=60)


def test_rate_limiter_blocks_requests_over_limit() -> None:
    limiter = InMemoryRateLimiter()
    limiter.check("bucket", max_requests=1, window_seconds=60)

    with pytest.raises(HTTPException) as exc_info:
        limiter.check("bucket", max_requests=1, window_seconds=60)

    assert exc_info.value.status_code == 429
