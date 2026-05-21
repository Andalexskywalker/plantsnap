# Guia de Apoio - Relatório da Avaliação #3 (PlantSnap)

Este documento contém os elementos adicionais obrigatórios solicitados no enunciado para a **Avaliação #3** (entrega a 22 de maio). Podes copiar, adaptar e traduzir estes conteúdos diretamente para a versão final do teu relatório em PDF.

---

## 1. Checklist de Ficheiros a Entregar

Deves compactar (ZIP) o teu repositório de código. Certifica-se de que a estrutura inclui os seguintes componentes fundamentais que desenvolvemos:

```text
plantsnap/
├── backend/
│   ├── Dockerfile                  # Configuração da imagem Docker (Python 3.11-slim + Uvicorn)
│   ├── main.py                     # API FastAPI (Endpoints para identificar, guardar, jardim, preferências)
│   ├── requirements.txt            # Dependências da API (FastAPI, Azure Cosmos/Blob SDKs, Computer Vision)
│   └── static/
│       └── index.html              # Frontend premium SPA (Single Page Application) e estilos integrados
├── function/
│   ├── host.json                   # Configuração geral do host da Azure Function
│   ├── local.settings.json         # Configuração local (excluído no .gitignore)
│   ├── requirements.txt            # Dependências da Function (azure-functions, azure-cosmos, email client)
│   └── function_app.py             # Azure Function de temporizador (WateringReminder) com envio de e-mails via ACS
├── infrastructure/
│   ├── deploy.ps1                  # Script de automação imperativo em Azure CLI (PowerShell)
│   └── main.bicep                  # Template alternativo Bicep para automação da infraestrutura
└── terraform/
    ├── main.tf                     # Configuração declarativa oficial em Terraform (IaC)
    └── .gitignore                  # Ficheiros do Terraform ignorados do controlo de versões
```

---

## 2. Previsão do Custo Mensal da Solução

Para estimar o custo mensal da infraestrutura no Microsoft Azure, consideramos dois cenários:
1. **Cenário de Desenvolvimento (Free Tier / Uso Mínimo)**: Tirando partido das camadas gratuitas dos serviços.
2. **Cenário de Produção Mínima**: Mantendo os recursos ativos e escaláveis com performance garantida.

### A. Tabela de Custos Detalhada

| Serviço Azure | Camada / Configuração | Custo Mensal (Cenário Dev/Free) | Custo Mensal (Cenário Produção) | Nota / Justificação |
| :--- | :--- | :--- | :--- | :--- |
| **Azure App Service Plan** | Linux B1 (Produção) / F1 (Dev) | 0.00 € | ~12.50 € | O plano B1 permite correr contentores Docker dedicados. F1 é gratuito, mas com limites. |
| **Azure Cosmos DB** | Camada Gratuita (Free Tier) / Serverless | 0.00 € | ~0.50 € (Serverless: 0.25€ por milhão RU) | A camada gratuita oferece 1000 RU/s e 25 GB grátis para sempre. Em Serverless, o custo depende do tráfego. |
| **Azure Blob Storage** | LRS (Hot Tier) - 5 GB | 0.00 € (Uso mínimo) | ~0.10 € | Armazenamento de imagens tiradas pelo utilizador. Custo irrisório para volumes baixos. |
| **Azure Functions** | Plano de Consumo (Consumption Plan) | 0.00 € | 0.00 € | O plano de consumo oferece 1 milhão de execuções grátis/mês. A nossa função de temporizador corre 1x por dia (30x/mês). |
| **Azure Communication Services** | Email Delivery | 0.00 € | ~0.05 € | Custo de 0.0002 € por email. Para 250 emails por mês, o custo é praticamente nulo. |
| **Azure AI Computer Vision** | Camada Free (F0) / S1 (Standard) | 0.00 € | ~1.00 € | 5.000 chamadas grátis no plano F0. No S1 custa 1.00 € por 1.000 chamadas de análise de tags de imagem. |
| **Plant.id API (Serviço Externo)** | Plano Developer / Trial | 0.00 € | ~15.00 € | A API externa oferece créditos de teste. Para produção, requer um plano de assinatura básica. |
| **Total Estimado (Azure)** | - | **0.00 €** | **~14.15 €** | **Excelente custo-benefício para uma infraestrutura totalmente automatizada e serverless.** |

*Nota: Os preços são baseados na região **Sweden Central** ou **West Europe**, que oferecem das tarifas mais competitivas do Azure na Europa.*

---

## 3. Estudo Teórico: Alternativas com Cloud Europeia

A migração de uma arquitetura Microsoft Azure para fornecedores de Cloud Europeus é um passo estratégico fundamental para organizações que necessitam de garantir **soberania de dados estrita**, conformidade total com o **RGPD** e evitar a jurisdição do *US Cloud Act*. 

Abaixo detalha-se como a arquitetura do **PlantSnap** poderia ser migrada utilizando as principais empresas de Cloud sediadas na Europa:

### A. Fornecedores Europeus Analisados
1. **OVHcloud (França)**: O maior fornecedor europeu de cloud.
2. **Scaleway (França)**: Focado em serviços modernos para developers, similar ao ecossistema do Azure.
3. **Hetzner Cloud (Alemanha)**: Conhecido pela excelente relação qualidade/preço em instâncias compute.

### B. Equivalência de Serviços e Arquitetura Alternativa

| Componente Azure | Serviço Equivalente (Scaleway) | Serviço Equivalente (OVHcloud) | Serviço Equivalente (Hetzner Cloud) |
| :--- | :--- | :--- | :--- |
| **App Service (Docker)** | Scaleway Serverless Containers | OVH Public Cloud Instances (VPS) | Hetzner Cloud VPS (com Docker/Portainer) |
| **Azure Blob Storage** | Scaleway Object Storage | OVH Object Storage (S3-compatible) | Hetzner Object Storage |
| **Azure CosmosDB (NoSQL)** | Scaleway Managed Document Database (MongoDB) | OVH Managed Databases for MongoDB | MongoDB em VPS + Aiven MongoDB |
| **Azure Functions** | Scaleway Serverless Functions | OVH Cloud Functions | Execução Cron num contentor Docker no VPS |
| **Communication Services** | Scaleway Transactional Email | OVH Automated Email (SMTP/API) | Serviço SMTP Hetzner / Mailjet (Europeu) |
| **Computer Vision / AI** | API de Visão própria / Custom Model | OVH AI Deploy (YOLO/Custom) | Modelo YOLOv8 hospedado em VPS Hetzner |

### C. Descrição da Migração Proposta (Arquitetura Scaleway)
Se a escolha recair sobre a **Scaleway** (o fornecedor europeu com os serviços mais parecidos ao Azure), a arquitetura seria a seguinte:
1. **Frontend + Backend (Docker)**:
   - A imagem Docker do backend seria publicada no **Scaleway Container Registry**.
   - A aplicação correria em **Scaleway Serverless Containers**, que escala automaticamente a zero quando não há tráfego, poupando custos de infraestrutura.
2. **Base de Dados NoSQL**:
   - Substituição do CosmosDB pelo **Scaleway Managed MongoDB** (uma base de dados NoSQL gerida) ou **PostgreSQL** com suporte JSONB.
3. **Armazenamento de Imagens**:
   - As fotografias das plantas seriam guardadas no **Scaleway Object Storage**, que expõe um endpoint compatível com a API S3 da AWS. O código Python usaria a biblioteca `boto3` para upload.
4. **Azure Functions (Rega)**:
   - A Azure Function seria migrada para **Scaleway Serverless Functions** (em Python 3.11), mantendo a mesma lógica de temporizador para verificar quem necessita de regar as plantas.
5. **Comunicação por Email**:
   - Envio através do **Scaleway Transactional Email API**, garantindo que as mensagens de aviso chegam à caixa de entrada do utilizador.

---

## 4. Declaração de Ferramentas de IA Utilizadas

Como valorizado no enunciado do trabalho, o desenvolvimento do **PlantSnap** contou com o auxílio de ferramentas de Inteligência Artificial Generativa. Abaixo descrevem-se as ferramentas e os seus propósitos específicos no projeto:

1. **Ferramenta: Antigravity IDE Agent (Google DeepMind)**
   - **Propósito**: 
     - **Desenho da Interface (Frontend)**: Criação de um design SPA (Single Page Application) moderno, com estilo premium usando paletas de cores verdes suaves, sombras suaves, micro-interações, e painéis baseados em Tabs (Identificar, Jardim, Perfil).
     - **Desenvolvimento da API**: Escrita das rotas da API FastAPI no backend, gestão de uploads de imagens assíncronas e mapeamento de respostas de APIs externas.
     - **Integração de Base de Dados**: Criação do esquema NoSQL no CosmosDB e estruturação de queries eficientes em SQL API (`SELECT * FROM c WHERE ...`).
     - **Automatização de Infraestrutura (IaC)**: Apoio na escrita do ficheiro de configuração declarativo em **Terraform** (`terraform/main.tf`), do template **Bicep** (`infrastructure/main.bicep`) e do script imperativo em PowerShell (`infrastructure/deploy.ps1`).
     - **Azure Functions**: Auxílio no desenvolvimento da lógica do trigger de tempo (Timer Trigger) na Azure Function para consultar a base de dados de preferências e formatar o corpo do email em HTML premium.

2. **Ferramenta: GitHub Copilot / ChatGPT**
   - **Propósito**:
     - Auxílio na depuração rápida de mensagens de erro no deploy do Azure CLI e resolução de incompatibilidades de dependências de bibliotecas de Python nas imagens de base Docker.

*Nota Académica: O uso de IA permitiu acelerar significativamente o ciclo de desenvolvimento, permitindo que o grupo se focasse na arquitetura, na integração dos diferentes serviços Azure e na lógica de negócio do ecossistema PlantSnap.*
