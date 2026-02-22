from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timezone
from app.supabase import get_supabase

router = APIRouter(tags=["dispatch"])


def _detail(err):
    try:
        return str(err)
    except Exception:
        return "unknown error"


def utcnow_iso():
    return datetime.now(timezone.utc).isoformat()


def parse_ts(val):
    if not val:
        return None
    return datetime.fromisoformat(str(val).replace("Z", "+00:00"))


def _fetch_events_for_dispatch(sb, dispatch_id):
    links = (
        sb.table("dispatch_event")
        .select("event_id")
        .eq("dispatch_id", dispatch_id)
        .execute()
    )
    if getattr(links, "error", None):
        raise HTTPException(status_code=400, detail=_detail(links.error))

    event_ids = [x["event_id"] for x in links.data]
    if not event_ids:
        return []

    ev = (
        sb.table("event")
        .select("id,name,event_date,location,notes,created_at")
        .in_("id", event_ids)
        .order("event_date")
        .execute()
    )
    if getattr(ev, "error", None):
        raise HTTPException(status_code=400, detail=_detail(ev.error))

    by_id = {e["id"]: e for e in ev.data}
    return [by_id[eid] for eid in event_ids if eid in by_id]


@router.post("/dispatches")
def create_dispatch(payload: dict):
    try:
        sb = get_supabase()

        if payload.get("resource_item_id") is None:
            raise HTTPException(status_code=400, detail="resource_item_id is required")

        resource_item_id = payload["resource_item_id"]
        event_ids=[]
        if payload.get("event_id") and not payload.get("event_ids"):
            event_ids = [payload["event_id"]]
        elif payload.get("event_ids") and not payload.get("event_id"):
            event_ids = payload["event_ids"]
        elif payload.get("event_ids") and payload.get("event_id"):
            raise HTTPException(status_code=400, detail="Provide either event_id or event_ids, not both")

        item = (
            sb.table("resource_item")
            .select("id")
            .eq("id", resource_item_id)
            .limit(1)
            .execute()
        )
        if getattr(item, "error", None):
            raise HTTPException(status_code=400, detail=_detail(item.error))
        if not item.data:
            raise HTTPException(status_code=404, detail="resource_item_id not found")

        open_d = (
            sb.table("dispatch")
            .select("id")
            .eq("resource_item_id", resource_item_id)
            .is_("returned_at", None)
            .limit(1)
            .execute()
        )
        if getattr(open_d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(open_d.error))
        if open_d.data:
            raise HTTPException(
                status_code=409,
                detail=f"Item already checked out (open dispatch id={open_d.data[0]['id']})",
            )

        if event_ids:
            ev = sb.table("event").select("id").in_("id", event_ids).execute()
            if getattr(ev, "error", None):
                raise HTTPException(status_code=400, detail=_detail(ev.error))
            found = {row["id"] for row in ev.data}
            missing = [eid for eid in event_ids if eid not in found]
            if missing:
                raise HTTPException(
                    status_code=404, detail=f"event_id(s) not found: {missing}"
                )

        dispatched_at = payload.get("dispatched_at") or utcnow_iso()

        d_ins = (
            sb.table("dispatch")
            .insert(
                {
                    "resource_item_id": resource_item_id,
                    "dispatched_at": dispatched_at,
                    "dispatch_note": payload.get("dispatch_note"),
                    "returned_at": None,
                    "return_note": None,
                }
            )
            .execute()
        )
        if getattr(d_ins, "error", None):
            raise HTTPException(status_code=409, detail=_detail(d_ins.error))

        drow = d_ins.data[0]
        dispatch_id = drow["id"]

        if event_ids:
            link = (
                sb.table("dispatch_event")
                .insert(
                    [{"dispatch_id": dispatch_id, "event_id": eid} for eid in event_ids]
                )
                .execute()
            )
            if getattr(link, "error", None):
                raise HTTPException(status_code=409, detail=_detail(link.error))

        upd = (
            sb.table("resource_item")
            .update(
                {"current_state": "CHECKED_OUT", "last_state_change_at": utcnow_iso()}
            )
            .eq("id", resource_item_id)
            .execute()
        )
        if getattr(upd, "error", None):
            raise HTTPException(status_code=400, detail=_detail(upd.error))

        events = _fetch_events_for_dispatch(sb, dispatch_id)

        return {
            "id": dispatch_id,
            "resource_item_id": resource_item_id,
            "dispatched_at": parse_ts(drow["dispatched_at"]),
            "dispatch_note": drow.get("dispatch_note"),
            "returned_at": None,
            "return_note": None,
            "events": events,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.post("/dispatches/{dispatch_id}/return")
def return_dispatch(dispatch_id: int, payload: dict | None = None):
    print("nice")
    returned_at = utcnow_iso()
    return_note = None
    if type(payload) == dict:
        ## Esto permite cambiar la fecha de devolución, lo cual puede ser útil para corregir errores, pero también puede ser riesgoso. En un caso real, quizás se quiera limitar esto a un rango razonable (ej. no permitir cambiar la fecha a algo muy antiguo o al futuro).
        if payload.get("returned_at"):
            returned_at = payload["returned_at"]
        if payload.get("return_note"):
            return_note = payload["return_note"]

    try:
        sb = get_supabase()

        d = sb.table("dispatch").select("*").eq("id", dispatch_id).limit(1).execute()
        if getattr(d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(d.error))
        if not d.data:
            raise HTTPException(status_code=404, detail="dispatch not found")

        drow = d.data[0]
        if drow.get("returned_at") is not None:
            raise HTTPException(status_code=409, detail="dispatch already returned")
        print(returned_at, return_note)
        upd_d = (
            sb.table("dispatch")
            .update({"returned_at": returned_at, "return_note": return_note})
            .eq("id", dispatch_id)
            .execute()
        )
        if getattr(upd_d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(upd_d.error))

        upd_i = (
            sb.table("resource_item")
            .update(
                {"current_state": "IN_WAREHOUSE", "last_state_change_at": utcnow_iso()}
            )
            .eq("id", drow["resource_item_id"])
            .execute()
        )
        if getattr(upd_i, "error", None):
            raise HTTPException(status_code=400, detail=_detail(upd_i.error))

        d2 = sb.table("dispatch").select("*").eq("id", dispatch_id).limit(1).execute()
        if getattr(d2, "error", None):
            raise HTTPException(status_code=400, detail=_detail(d2.error))
        row = d2.data[0]

        events = _fetch_events_for_dispatch(sb, dispatch_id)

        return {
            "id": row["id"],
            "resource_item_id": row["resource_item_id"],
            "dispatched_at": parse_ts(row["dispatched_at"]),
            "dispatch_note": row.get("dispatch_note"),
            "returned_at": parse_ts(row.get("returned_at")),
            "return_note": row.get("return_note"),
            "events": events,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.get("/dispatches")
def list_dispatches(open_only: bool = Query(default=False)):
    try:
        sb = get_supabase()

        q = (
            sb.table("dispatch")
            .select("*")
            .order("dispatched_at", desc=True)
            .order("id", desc=True)
        )
        if open_only:
            q = q.is_("returned_at", None)

        d = q.execute()
        if getattr(d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(d.error))

        out = []
        for row in d.data:
            events = _fetch_events_for_dispatch(sb, row["id"])
            out.append(
                {
                    "id": row["id"],
                    "resource_item_id": row["resource_item_id"],
                    "dispatched_at": parse_ts(row["dispatched_at"]),
                    "dispatch_note": row.get("dispatch_note"),
                    "returned_at": parse_ts(row.get("returned_at")),
                    "return_note": row.get("return_note"),
                    "events": events,
                }
            )
        return out

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))

@router.get("/dispatches/{dispatch_id}")
def get_dispatch(dispatch_id: int):
    try:
        sb = get_supabase()

        d = sb.table("dispatch").select("*").eq("id", dispatch_id).limit(1).execute()
        if getattr(d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(d.error))
        if not d.data:
            raise HTTPException(status_code=404, detail="dispatch not found")

        row = d.data[0]
        events = _fetch_events_for_dispatch(sb, dispatch_id)

        return {
            "id": row["id"],
            "resource_item_id": row["resource_item_id"],
            "dispatched_at": parse_ts(row["dispatched_at"]),
            "dispatch_note": row.get("dispatch_note"),
            "returned_at": parse_ts(row.get("returned_at")),
            "return_note": row.get("return_note"),
            "events": events,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))


@router.get("/items/{item_id}/trace")
def item_trace(item_id: int):
    try:
        sb = get_supabase()

        item = (
            sb.table("resource_item")
            .select("id,code,current_state")
            .eq("id", item_id)
            .limit(1)
            .execute()
        )
        if getattr(item, "error", None):
            raise HTTPException(status_code=400, detail=_detail(item.error))
        if not item.data:
            raise HTTPException(status_code=404, detail="item not found")

        item_row = item.data[0]

        open_d = (
            sb.table("dispatch")
            .select("id")
            .eq("resource_item_id", item_id)
            .is_("returned_at", None)
            .limit(1)
            .execute()
        )
        if getattr(open_d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(open_d.error))
        open_dispatch_id = open_d.data[0]["id"] if open_d.data else None

        all_d = (
            sb.table("dispatch")
            .select("*")
            .eq("resource_item_id", item_id)
            .order("dispatched_at", desc=True)
            .order("id", desc=True)
            .execute()
        )
        if getattr(all_d, "error", None):
            raise HTTPException(status_code=400, detail=_detail(all_d.error))

        dispatches = []
        last_dispatch = None

        for idx, row in enumerate(all_d.data):
            events = _fetch_events_for_dispatch(sb, row["id"])
            dto = {
                "id": row["id"],
                "resource_item_id": row["resource_item_id"],
                "dispatched_at": parse_ts(row["dispatched_at"]),
                "dispatch_note": row.get("dispatch_note"),
                "returned_at": parse_ts(row.get("returned_at")),
                "return_note": row.get("return_note"),
                "events": events,
            }
            dispatches.append(dto)
            if idx == 0:
                last_dispatch = dto

        return {
            "resource_item_id": item_row["id"],
            "code": item_row["code"],
            "current_state": item_row["current_state"],
            "open_dispatch_id": open_dispatch_id,
            "last_dispatch": last_dispatch,
            "dispatches": dispatches,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=_detail(e))
