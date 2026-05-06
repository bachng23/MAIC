from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.db.client import get_supabase
from app.models.base import APIResponse
from app.models.health import EmergencyContact, EmergencyContactsUpdate

router = APIRouter(prefix="/emergency", tags=["emergency"])


@router.get("/contacts", response_model=APIResponse[list[EmergencyContact]])
async def get_contacts(user: dict = Depends(get_current_user)):
    db = get_supabase()
    row = db.table("users").select("emergency_contacts").eq("id", user["id"]).single().execute()
    contacts = row.data.get("emergency_contacts") or []
    return APIResponse(data=[EmergencyContact(**c) for c in contacts])


@router.put("/contacts", response_model=APIResponse[None])
async def update_contacts(body: EmergencyContactsUpdate, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("users").update({
        "emergency_contacts": [c.model_dump() for c in body.contacts]
    }).eq("id", user["id"]).execute()
    return APIResponse(message="Emergency contacts updated")
