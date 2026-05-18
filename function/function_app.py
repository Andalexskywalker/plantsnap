import azure.functions as func
import logging
from azure.cosmos import CosmosClient
from azure.communication.email import EmailClient
import os

app = func.FunctionApp()

@app.timer_trigger(schedule="0 0 8 * * *", arg_name="mytimer", run_on_startup=False)
def WateringReminder(mytimer: func.TimerRequest) -> None:
    logging.info('WateringReminder function triggered')

    # Ligar ao CosmosDB
    cosmos_client = CosmosClient(
        os.environ["COSMOS_ENDPOINT"],
        os.environ["COSMOS_KEY"]
    )
    database = cosmos_client.get_database_client(os.environ["COSMOS_DATABASE"])
    container = database.get_container_client(os.environ["COSMOS_CONTAINER"])

    # Email client
    email_client = EmailClient.from_connection_string(os.environ["COMMUNICATION_CONNECTION_STRING"])

    # Buscar todas as plantas
    query = "SELECT * FROM c WHERE c.userId != 'anonymous' AND IS_DEFINED(c.plantName) AND c.plantName != ''"
    plants = list(container.query_items(query=query, enable_cross_partition_query=True))

    # Agrupar por utilizador
    users = {}
    for plant in plants:
        user_id = plant.get("userId")
        if user_id not in users:
            users[user_id] = []
        users[user_id].append(plant)

    # Enviar email a cada utilizador
    for email, user_plants in users.items():
        plant_list = "\n".join([f"- {p.get('plantName', 'Planta desconhecida')} (rega: {p.get('watering', 'N/A')})" for p in user_plants])
        
        message = {
            "senderAddress": "DoNotReply@plantsnap.azurecomm.net",
            "recipients": {
                "to": [{"address": email}]
            },
            "content": {
                "subject": "🌱 PlantSnap - Lembretes de Rega",
                "plainText": f"Olá!\n\nNão te esqueças de regar as tuas plantas hoje:\n\n{plant_list}\n\nBom dia!\nPlantSnap"
            }
        }
        
        try:
            poller = email_client.begin_send(message)
            result = poller.result()
            logging.info(f"Email enviado para {email}: {result['id']}")
        except Exception as e:
            logging.error(f"Erro ao enviar email para {email}: {str(e)}")