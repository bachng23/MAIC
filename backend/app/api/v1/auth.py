from fastapi import APIRouter, Depends, HTTPException, status
from supabase_auth.errors import AuthApiError, AuthError

from app.api.deps import get_current_user
from app.db.client import get_supabase
from app.models.base import APIResponse
from app.models.user import APNSTokenUpdate, UserLogin, UserRegister
from app.services.notification_service import get_apns_status
from app.services.rate_limiter import RateLimitRule, create_rate_limit_dependency

router = APIRouter(prefix="/auth", tags=["auth"])
auth_write_rate_limit = create_rate_limit_dependency(
    RateLimitRule(name="auth-write", max_requests=10, window_seconds=60, scope="ip")
)
apns_status_rate_limit = create_rate_limit_dependency(
    RateLimitRule(name="auth-apns-status", max_requests=20, window_seconds=60, scope="ip")
)


@router.post("/register", response_model=APIResponse[dict])
async def register(body: UserRegister, _: None = Depends(auth_write_rate_limit)):
    db = get_supabase()
    try:
        auth_resp = db.auth.sign_up({"email": body.email, "password": body.password})
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e.message))
    except AuthError:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Auth service unavailable")
    except Exception:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Unexpected error")

    if not auth_resp.user or not auth_resp.session:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Registration failed")

    db.table("users").update({
        "name": body.name,
        "phone": body.phone,
        "language": body.language,
    }).eq("id", auth_resp.user.id).execute()

    return APIResponse(data={"access_token": auth_resp.session.access_token})


@router.post("/login", response_model=APIResponse[dict])
async def login(body: UserLogin, _: None = Depends(auth_write_rate_limit)):
    db = get_supabase()
    try:
        auth_resp = db.auth.sign_in_with_password({"email": body.email, "password": body.password})
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e.message))
    except AuthError:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Auth service unavailable")
    except Exception:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Unexpected error")

    if not auth_resp.user or not auth_resp.session:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    return APIResponse(data={"access_token": auth_resp.session.access_token})


@router.put("/apns-token", response_model=APIResponse[None])
async def update_apns_token(body: APNSTokenUpdate, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("users").update({"apns_token": body.apns_token}).eq("id", user["id"]).execute()
    return APIResponse(message="APNs token updated")


@router.get("/apns-status", response_model=APIResponse[dict])
async def apns_status(
    user: dict = Depends(get_current_user),
    _: None = Depends(apns_status_rate_limit),
):
    return APIResponse(data={"user_id": user["id"], **get_apns_status()})
