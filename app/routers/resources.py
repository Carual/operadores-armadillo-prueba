from fastapi import APIRouter, HTTPException, Query
from app.supabase_client import get_supabase

router = APIRouter(tags=["resources"])


@router.post("/resource-types")
def create_resource_type(payload: dict):
    sb = get_supabase()
    name = str(payload.get("name", "")).strip()
    if not name:
        raise HTTPException(status_code=400, detail="name is required")

    resp = (
        sb.table("resource_type")
        .insert({"name": name, "description": payload.get("description")})
        .execute()
    )
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data[0]


@router.get("/resource-types")
def list_resource_types():
    sb = get_supabase()
    resp = sb.table("resource_type").select("*").order("name").execute()
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data


@router.post("/items")
def create_item(payload: dict):
    sb = get_supabase()
    if payload.get("resource_type_id") is None:
        raise HTTPException(status_code=400, detail="resource_type_id is required")
    code = str(payload.get("code", "")).strip()
    if not code:
        raise HTTPException(status_code=400, detail="code is required")

    rt = (
        sb.table("resource_type")
        .select("id")
        .eq("id", payload["resource_type_id"])
        .limit(1)
        .execute()
    )
    if getattr(rt, "error", None):
        raise HTTPException(status_code=400, detail=str(rt.error))
    if not rt.data:
        raise HTTPException(status_code=404, detail="resource_type_id not found")

    resp = (
        sb.table("resource_item")
        .insert(
            {
                "resource_type_id": payload["resource_type_id"],
                "code": code,
                "notes": payload.get("notes"),
            }
        )
        .execute()
    )
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data[0]


@router.get("/items")
def list_items(state: str | None = Query(default=None)):
    sb = get_supabase()
    q = sb.table("resource_item").select("*").order("code")
    if state:
        q = q.eq("current_state", state)
    resp = q.execute()
    if getattr(resp, "error", None):
        raise HTTPException(status_code=400, detail=str(resp.error))
    return resp.data
