from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from azure.cosmos import CosmosClient
from azure.storage.blob import BlobServiceClient
from azure.ai.vision.imageanalysis import ImageAnalysisClient
from azure.ai.vision.imageanalysis.models import VisualFeatures
from azure.core.credentials import AzureKeyCredential
import httpx
import os
import uuid
import base64
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

load_dotenv()

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/app")
def serve_frontend():
    return FileResponse("static/index.html")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CosmosDB
cosmos_client = CosmosClient(os.getenv("COSMOS_ENDPOINT"), os.getenv("COSMOS_KEY"))
database = cosmos_client.get_database_client(os.getenv("COSMOS_DATABASE"))
container = database.get_container_client(os.getenv("COSMOS_CONTAINER"))

# BLOB Storage
blob_service_client = BlobServiceClient.from_connection_string(os.getenv("STORAGE_CONNECTION_STRING"))

# Azure Computer Vision
vision_client = ImageAnalysisClient(
    endpoint=os.getenv("VISION_ENDPOINT"),
    credential=AzureKeyCredential(os.getenv("VISION_KEY"))
)

# Plant.id
PLANTID_API_KEY = os.getenv("PLANTID_API_KEY")


#ENDPOINTS AQUI!!
@app.get("/")
def root():
    return {"message": "PlantSnap API is running!"}

@app.get("/health")
def health():
    try:
        container.read()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/identify")
async def identify_plant(file: UploadFile = File(...)):
    try:
        contents = await file.read()

        # 1. Azure Computer Vision - verificar se é uma planta
        vision_result = vision_client.analyze(
            image_data=contents,
            visual_features=[VisualFeatures.TAGS]
        )
        tags = [tag.name.lower() for tag in vision_result.tags.list]
        plant_tags = ["plant", "flower", "tree", "leaf", "vegetation", "herb", "shrub", "grass"]
        is_plant = any(tag in tags for tag in plant_tags)

        if not is_plant:
            raise HTTPException(status_code=400, detail="A imagem não parece ser uma planta. Tenta com outra foto!")

        # 2. Plant.id - identificar a planta
        image_base64 = base64.b64encode(contents).decode("utf-8")
        async with httpx.AsyncClient() as client:
            plantid_response = await client.post(
                "https://plant.id/api/v3/identification",
                headers={"Api-Key": PLANTID_API_KEY},
                json={
                    "images": [f"data:image/jpeg;base64,{image_base64}"],
                    "similar_images": True
                }
            )
        plantid_data = plantid_response.json()
        suggestion = plantid_data["result"]["classification"]["suggestions"][0]
        plant_name = suggestion["name"]
        probability = round(suggestion["probability"] * 100, 1)

        return {
            "plantName": plant_name,
            "probability": probability
        }

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@app.post("/save")
async def save_plant(request: Request, file: UploadFile = File(...), plantName: str = "", probability: float = 0.0):
    user_email = request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME", "anonymous")
    try:
        contents = await file.read()
        blob_name = f"{uuid.uuid4()}-{file.filename}"
        blob_client = blob_service_client.get_blob_client(
            container=os.getenv("STORAGE_CONTAINER"),
            blob=blob_name
        )
        blob_client.upload_blob(contents)
        blob_url = blob_client.url

        plant_record = {
            "id": str(uuid.uuid4()),
            "userId": user_email,
            "plantName": plantName,
            "probability": probability,
            "imageUrl": blob_url,
            "imageName": blob_name
        }
        container.create_item(plant_record)

        return {"message": "Planta guardada com sucesso!", "imageUrl": blob_url, "recordId": plant_record["id"]}
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@app.get("/garden")
async def get_garden(request: Request):
    from fastapi import Request
    user_email = request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME", "anonymous")
    
    query = f"SELECT * FROM c WHERE c.userId = '{user_email}' ORDER BY c._ts DESC"
    items = list(container.query_items(query=query, enable_cross_partition_query=True))
    
    return {"plants": items}