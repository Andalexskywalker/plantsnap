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

    # Buscar todas as plantas de utilizadores autenticados
    query = "SELECT * FROM c WHERE c.userId != 'anonymous' AND IS_DEFINED(c.plantName) AND c.plantName != ''"
    plants = list(container.query_items(query=query, enable_cross_partition_query=True))

    # Buscar preferências de todos os utilizadores
    prefs_query = "SELECT * FROM c WHERE STARTSWITH(c.id, 'prefs-')"
    prefs_list = list(container.query_items(query=prefs_query, enable_cross_partition_query=True))
    prefs_map = {p["userId"]: p.get("notificationsEnabled", True) for p in prefs_list}

    # Agrupar plantas por utilizador
    users = {}
    for plant in plants:
        user_id = plant.get("userId")
        if user_id not in users:
            users[user_id] = []
        users[user_id].append(plant)

    # Enviar email a cada utilizador que tem notificações ativas
    for email, user_plants in users.items():
        # Verificar preferência — por defeito envia se não houver registo
        if not prefs_map.get(email, True):
            logging.info(f"Notificações desativadas para {email}, a ignorar.")
            continue

        # Construir lista de plantas em HTML
        plant_rows = ""
        for p in user_plants:
            name = p.get("plantName", "Planta desconhecida")
            watering = p.get("watering", "N/A")
            image_url = p.get("imageUrl", "")
            img_tag = f'<img src="{image_url}" style="width:50px;height:50px;object-fit:cover;border-radius:8px;margin-right:12px;" />' if image_url else ""
            plant_rows += f"""
            <tr>
                <td style="padding:12px 16px;border-bottom:1px solid #e8f5e9;vertical-align:middle;">
                    {img_tag}<strong style="color:#1a3c34;">{name}</strong>
                </td>
                <td style="padding:12px 16px;border-bottom:1px solid #e8f5e9;color:#2e7d32;font-weight:600;">
                    💧 {watering}
                </td>
            </tr>"""

        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"></head>
        <body style="margin:0;padding:0;background:#f0f4f0;font-family:Arial,sans-serif;">
            <div style="max-width:560px;margin:32px auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
                
                <!-- Header -->
                <div style="background:linear-gradient(135deg,#1a5c38,#2e7d32);padding:32px 24px;text-align:center;">
                    <div style="font-size:40px;margin-bottom:8px;">🌱</div>
                    <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:800;">PlantSnap</h1>
                    <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">Os teus lembretes de rega de hoje</p>
                </div>

                <!-- Body -->
                <div style="padding:24px;">
                    <p style="color:#333;font-size:15px;margin:0 0 20px;">Olá! 👋 Não te esqueças de regar as tuas plantas hoje:</p>

                    <table style="width:100%;border-collapse:collapse;background:#f9fbf9;border-radius:12px;overflow:hidden;">
                        <thead>
                            <tr style="background:#e8f5e9;">
                                <th style="padding:10px 16px;text-align:left;color:#1a5c38;font-size:13px;">Planta</th>
                                <th style="padding:10px 16px;text-align:left;color:#1a5c38;font-size:13px;">Rega</th>
                            </tr>
                        </thead>
                        <tbody>
                            {plant_rows}
                        </tbody>
                    </table>

                    <div style="margin-top:24px;text-align:center;">
                        <a href="https://plantsnap-app.azurewebsites.net/app" style="display:inline-block;background:#1a5c38;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:8px;font-weight:700;font-size:14px;">
                            Ver o meu Jardim →
                        </a>
                    </div>
                </div>

                <!-- Footer -->
                <div style="background:#f0f4f0;padding:16px 24px;text-align:center;border-top:1px solid #e0e0e0;">
                    <p style="color:#999;font-size:12px;margin:0;">
                        Recebeste este email porque tens notificações ativas no PlantSnap.<br>
                        Podes desativá-las na aba <strong>Perfil</strong> da aplicação.
                    </p>
                </div>

            </div>
        </body>
        </html>
        """

        message = {
            "senderAddress": "DoNotReply@38995e80-977e-4b66-b67c-124dd2a1b7ba.azurecomm.net",
            "recipients": {
                "to": [{"address": email}]
            },
            "content": {
                "subject": "🌱 PlantSnap - Lembretes de Rega",
                "html": html_body
            }
        }

        try:
            poller = email_client.begin_send(message)
            result = poller.result()
            logging.info(f"Email enviado para {email}: {result['id']}")
        except Exception as e:
            logging.error(f"Erro ao enviar email para {email}: {str(e)}")