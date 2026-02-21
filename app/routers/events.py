from fastapi import APIRouter, HTTPException
from app.supabase_client import get_supabase

router = APIRouter(tags=["events"])


@router.post("/events")
def create_event(payload: dict):
    sb = get_supabase()
    if not payload.get("event_date"):
        raise HTTPException(
            status_code=400, detail="event_date is required (YYYY-MM-DD)"
        )
    location = str(payload.get("location", "")).strip()
    if not location:
        raise HTTPException(status_code=400, detail="location is required")

    resp = (
        sb.table("event")
        .insert(
            {
                "name": payload.get("name"),
                "event_date": payload["event_date"],
                "location": location,
                "notes": payload.get("notes"),
            }
        )
        .execute()
    )
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data[0]


@router.get("/events")
def list_events():
    sb = get_supabase()
    resp = sb.table("event").select("*").order("event_date").order("id").execute()
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data
