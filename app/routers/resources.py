from fastapi import APIRouter, HTTPException, Query
from app.supabase import get_supabase

router = APIRouter(tags=["resources"])


def _detail(err):
    try:
        return str(err)
    except Exception:
        return "unknown error"


@router.post("/resource-types")
def create_resource_type(payload: dict):
    try:
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
            raise HTTPException(status_code=400, detail=_detail(resp.error))

        return resp.data[0]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.get("/resource-types")
def list_resource_types():
    try:
        sb = get_supabase()

        resp = sb.table("resource_type").select("*").order("name").execute()
        if getattr(resp, "error", None):
            raise HTTPException(status_code=400, detail=_detail(resp.error))

        return resp.data

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.post("/items")
def create_item(payload: dict):
    try:
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
            raise HTTPException(status_code=400, detail=_detail(rt.error))
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
            raise HTTPException(status_code=400, detail=_detail(resp.error))

        return resp.data[0]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.get("/items")
def list_items(state: str | None = Query(default=None)):
    try:
        sb = get_supabase()

        q = sb.table("resource_item").select("*").order("code")
        if state:
            q = q.eq("current_state", state)

        resp = q.execute()
        if getattr(resp, "error", None):
            raise HTTPException(status_code=400, detail=_detail(resp.error))

        return resp.data

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.get("/items/{item_id}")
def get_item(item_id: int):
    """
    Returns resource_item + nested resource_type object.

    Requires FK: resource_item.resource_type_id -> resource_type.id
    """
    try:
        sb = get_supabase()

        # PostgREST "join" via nested select
        resp = (
            sb.table("resource_item")
            .select(
                "id,code,current_state,notes,created_at,last_state_change_at,resource_type:resource_type_id(id,name,description)"
            )
            .eq("id", item_id)
            .limit(1)
            .execute()
        )

        if getattr(resp, "error", None):
            raise HTTPException(status_code=400, detail=_detail(resp.error))
        if not resp.data:
            raise HTTPException(status_code=404, detail="item not found")

        return resp.data[0]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))
