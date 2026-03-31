from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import json
import asyncio

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast_status(self, pet_id: str, status: str, details: dict = None):
        message = {"pet_id": str(pet_id), "status": status}
        if details:
            message["details"] = details
            
        for connection in self.active_connections:
            await connection.send_text(json.dumps(message))

manager = ConnectionManager()

@router.websocket("/ws/scans")
async def websocket_endpoint(websocket: WebSocket):
    """
    Subscribes the frontend client to real-time status updates of YOLO CV processing.
    The Flutter app will connect here while bursts upload.
    """
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive silently, waiting for broadcast events
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
