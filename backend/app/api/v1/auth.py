from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user
from app.db.client import get_supabase
from app.models.base import APIResponse
from app.models.user import APNSTokenUpdate, UserLogin, UserRegister

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=APIResponse[dict])
async def register(body: UserRegister):
    db = get_supabase()
    auth_resp = db.auth.sign_up({"email": body.email, "password": body.password})
    if not auth_resp.user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Registration failed")

    db.table("users").insert({
        "id": auth_resp.user.id,
        "name": body.name,
        "phone": body.phone,
        "language": body.language,
    }).execute()

    return APIResponse(data={"access_token": auth_resp.session.access_token})


@router.post("/login", response_model=APIResponse[dict])
async def login(body: UserLogin):
    db = get_supabase()
    auth_resp = db.auth.sign_in_with_password({"email": body.email, "password": body.password})
    if not auth_resp.user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    return APIResponse(data={"access_token": auth_resp.session.access_token})


@router.put("/apns-token", response_model=APIResponse[None])
async def update_apns_token(body: APNSTokenUpdate, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("users").update({"apns_token": body.apns_token}).eq("id", user["id"]).execute()
    return APIResponse(message="APNs token updated")
