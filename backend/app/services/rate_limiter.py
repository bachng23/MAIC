from collections import defaultdict, deque
from dataclasses import dataclass
from threading import Lock
from time import monotonic

from fastapi import HTTPException, Request, status


@dataclass(frozen=True)
class RateLimitRule:
    name: str
    max_requests: int
    window_seconds: int
    scope: str = "user"


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._buckets: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def check(self, key: str, max_requests: int, window_seconds: int) -> None:
        now = monotonic()
        window_start = now - window_seconds

        with self._lock:
            bucket = self._buckets[key]
            while bucket and bucket[0] < window_start:
                bucket.popleft()

            if len(bucket) >= max_requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded",
                )

            bucket.append(now)


rate_limiter = InMemoryRateLimiter()


def create_rate_limit_dependency(rule: RateLimitRule):
    async def dependency(request: Request) -> None:
        scope_value = _extract_scope_value(request, rule.scope)
        bucket_key = f"{rule.name}:{scope_value}"
        rate_limiter.check(bucket_key, rule.max_requests, rule.window_seconds)

    return dependency


def _extract_scope_value(request: Request, scope: str) -> str:
    if scope == "user":
        user = getattr(request.state, "user", None)
        if user and user.get("id"):
            return user["id"]

    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    client_host = request.client.host if request.client else None
    return client_host or "unknown"
