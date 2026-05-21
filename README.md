# 🌱 PlantSnap - AI Plant Identifier & Care Assistant

O **PlantSnap** é uma aplicação web original e moderna baseada na plataforma cloud **Microsoft Azure**. A aplicação permite aos utilizadores identificar plantas a partir de fotografias usando Inteligência Artificial, obter instruções detalhadas de rega e cuidados, guardar as plantas num jardim virtual pessoal e receber notificações/lembretes de rega automáticos por e-mail.

Este projeto foi desenvolvido como mini-projeto para a unidade curricular de Computação em Nuvem e cumpre todos os requisitos obrigatórios das entregas de avaliação.

---

## 🛠️ Arquitetura do Sistema e Serviços Utilizados

A arquitetura do **PlantSnap** foi desenhada seguindo princípios de escalabilidade, descentralização e computação serverless:

1. **Frontend**: Interface Web Premium de página única (SPA), responsiva e moderna, com um design baseado em abas (Identificar, Jardim, Perfil). Desenvolvida em HTML5, CSS3 (Vanilla) e JavaScript.
2. **Backend (Docker Container)**: API REST desenvolvida em **FastAPI** (Python 3.11). Toda a lógica da API é empacotada num contentor Docker e corre no **Azure App Service**.
3. **Base de Dados (CosmosDB)**: Base de dados NoSQL (SQL API) para armazenar os registos das plantas guardadas pelos utilizadores (`userId`, `plantName`, `watering`, `imageUrl`, etc.) e as respetivas preferências de notificação.
4. **Armazenamento Cloud (Azure Blob Storage)**: Armazenamento binário público no container `plant-images` para alojar as fotografias das plantas carregadas pelos utilizadores.
5. **Computação Serverless (Azure Function)**: Uma função com trigger de temporizador (`WateringReminder`) escrita em Python que executa periodicamente para recolher as plantas no CosmosDB e enviar e-mails de aviso de rega.
6. **Azure Communication Services (ACS)**: Serviço adicional para envio automático de e-mails transacionais com templates HTML premium responsivos.
7. **Integração de APIs de Inteligência Artificial**:
   - **Azure Computer Vision**: Analisa a imagem no backend para certificar que se trata de uma planta antes de submeter ao motor de identificação.
   - **Plant.id API & KB**: Identifica a espécie exata da planta, calcula a probabilidade e recolhe dados detalhados de rega e descrição botânica.

---

## 🚀 Como Executar Localmente

### 1. Requisitos Prévios
- Python 3.11+ instalado
- Docker instalado (opcional, para testar a imagem do container)
- Variáveis de ambiente configuradas num ficheiro `.env` na raiz do backend

### 2. Configurar o Backend
Aceda à pasta `backend/` e instale as dependências:
```bash
cd backend
pip install -r requirements.txt
```

Crie um ficheiro `.env` com as chaves necessárias:
```env
COSMOS_ENDPOINT="https://plantsnap-cosmos.documents.azure.com:443/"
COSMOS_KEY="<tua-chave-cosmos>"
COSMOS_DATABASE="plantsnap"
COSMOS_CONTAINER="plants"
STORAGE_CONNECTION_STRING="<tua-connection-string-storage>"
STORAGE_CONTAINER="plant-images"
VISION_ENDPOINT="https://<teu-vision-resource>.cognitiveservices.azure.com/"
VISION_KEY="<tua-chave-vision>"
PLANTID_API_KEY="<tua-chave-plantid>"
```

Inicie o servidor de desenvolvimento:
```bash
uvicorn main:app --reload
```
A aplicação estará disponível em `http://localhost:8000/app`.

### 3. Configurar a Azure Function
Aceda à pasta `function/` e instale as dependências localmente para testes:
```bash
cd function
pip install -r requirements.txt
```
Configure as variáveis correspondentes no ficheiro `local.settings.json` e inicie a ferramenta Core Tools da Azure:
```bash
func start
```

---

## 🤖 Automação de Infraestrutura (IaC)

A infraestrutura na cloud do projeto pode ser provisionada automaticamente de duas formas:

### Opção A: Terraform (Recomendada)
Toda a infraestrutura está declarada no diretório `/terraform` recorrendo a ficheiros de configuração HCL.
1. Instale o Terraform.
2. Faça login no Azure CLI: `az login`.
3. Navegue até à pasta e inicialize o Terraform:
   ```bash
   cd terraform
   terraform init
   ```
4. Planeie e aplique as alterações:
   ```bash
   terraform plan
   terraform apply
   ```

### Opção B: Script PowerShell + Azure CLI / Bicep
Caso prefira provisionar por script imperativo ou Bicep:
1. Abra a consola do PowerShell com permissões adequadas.
2. Execute o script de deployment localizado em `/infrastructure`:
   ```powershell
   ./infrastructure/deploy.ps1
   ```
   *O script irá criar o grupo de recursos, ACR, CosmosDB, Storage Accounts, App Service e a Function App automaticamente.*

---

## 👥 Equipa e Divisão de Tarefas
*Consulte o relatório em PDF na entrega para obter a listagem de membros do grupo, o cronograma/diagrama de Gantt e a divisão detalhada de tarefas.*
