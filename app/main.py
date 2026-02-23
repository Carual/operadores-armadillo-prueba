from fastapi import FastAPI
from starlette.responses import FileResponse

from app.routers.resources import router as resources_router
from app.routers.events import router as events_router
from app.routers.dispatch import router as dispatch_router

app = FastAPI(title="Supabase Logistics API (FastAPI)")

# health
@app.get("/")
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/test")
def test():
    return FileResponse("index.html")

app.include_router(resources_router)
app.include_router(events_router)
app.include_router(dispatch_router)
