from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from azure.cosmos import CosmosClient
from azure.storage.blob import BlobServiceClient
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CosmosDB
COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")
COSMOS_KEY = os.getenv("COSMOS_KEY")
COSMOS_DATABASE = os.getenv("COSMOS_DATABASE")
COSMOS_CONTAINER = os.getenv("COSMOS_CONTAINER")

cosmos_client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
database = cosmos_client.get_database_client(COSMOS_DATABASE)
container = database.get_container_client(COSMOS_CONTAINER)

# BLOB Storage
STORAGE_CONNECTION_STRING = os.getenv("STORAGE_CONNECTION_STRING")
STORAGE_CONTAINER = os.getenv("STORAGE_CONTAINER")

blob_service_client = BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)

@app.get("/")
def root():
    return {"message": "PlantSnap API is running!"}

@app.get("/health")
def health():
    try:
        container.read()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/upload")
async def upload_plant_image(file: UploadFile = File(...)):
    try:
        # Upload imagem para BLOB Storage
        blob_name = f"{uuid.uuid4()}-{file.filename}"
        blob_client = blob_service_client.get_blob_client(
            container=STORAGE_CONTAINER,
            blob=blob_name
        )
        contents = await file.read()
        blob_client.upload_blob(contents)
        blob_url = blob_client.url

        # Guarda registo no CosmosDB
        plant_record = {
            "id": str(uuid.uuid4()),
            "userId": "anonymous",
            "imageName": blob_name,
            "imageUrl": blob_url,
            "status": "uploaded"
        }
        container.create_item(plant_record)

        return {
            "message": "Imagem carregada com sucesso!",
            "imageUrl": blob_url,
            "recordId": plant_record["id"]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))