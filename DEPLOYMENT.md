# 🚀 GitHub Actions CI/CD Pipeline for Google Cloud Run

This guide will help you set up a complete CI/CD pipeline using GitHub Actions to deploy your Feathers.js backend to Google Cloud Run.

## 📋 Prerequisites

1. **Google Cloud Account** with billing enabled
2. **GitHub Repository** with your code
3. **Google Cloud CLI** installed locally (for initial setup)

## 🏗️ Architecture Overview

```
GitHub Push → GitHub Actions → Build Docker Image → Push to Artifact Registry → Deploy to Cloud Run
```

**Pipeline Jobs:**
1. **Test**: Run linting and unit tests
2. **Build & Push**: Build Docker image and push to Google Artifact Registry
3. **Deploy**: Deploy the image to Google Cloud Run

## 🔧 Setup Instructions

### Step 1: Enable Google Cloud APIs

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com
```

### Step 2: Create Artifact Registry Repository

```bash
# Create repository for Docker images
gcloud artifacts repositories create feathers-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Docker repository for Feathers backend"
```

### Step 3: Create Service Account

```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --description="Service account for GitHub Actions CI/CD" \
  --display-name="GitHub Actions"

# Get the service account email
export SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# Create and download service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=$SA_EMAIL
```

### Step 4: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GCP_PROJECT_ID` | your-project-id | Your Google Cloud Project ID |
| `GCP_SA_KEY` | Contents of key.json | Service Account JSON key |

### Step 5: Update Configuration

Update the following values in `.github/workflows/deploy.yml` if needed:

```yaml
env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GAR_LOCATION: us-central1 # Change if using different region
  SERVICE: feathers-backend # Change service name if needed
  REGION: us-central1 # Change deployment region if needed
```

## 🚀 Deployment Process

### Automatic Deployment
- Push to `main` or `master` branch triggers the full pipeline
- Pull requests only run tests (no deployment)

### Manual Deployment
- Go to Actions tab in GitHub
- Select "Build and Deploy to Cloud Run"
- Click "Run workflow"

## 📊 Pipeline Stages Explained

### 1. Test Stage
```yaml
- Checkout code
- Setup Node.js 18
- Install dependencies
- Run ESLint
- Run unit tests
```

### 2. Build & Push Stage
```yaml
- Authenticate with Google Cloud
- Build Docker image (production target)
- Tag with commit SHA
- Push to Artifact Registry
```

### 3. Deploy Stage
```yaml
- Deploy to Cloud Run
- Configure service settings:
  - Port: 3031
  - Memory: 512Mi
  - CPU: 1
  - Auto-scaling: 0-10 instances
  - Allow unauthenticated access
```

## 🔍 Monitoring & Debugging

### View Logs
```bash
# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=feathers-backend" --limit=50

# View build logs
gcloud logging read "resource.type=build" --limit=10
```

### Check Service Status
```bash
# Get service details
gcloud run services describe feathers-backend --region=us-central1

# List all services
gcloud run services list
```

## 🛠️ Troubleshooting

### Common Issues

1. **Permission Denied**
   - Check service account has correct IAM roles
   - Verify `GCP_SA_KEY` secret is valid JSON

2. **Build Fails**
   - Check Dockerfile syntax
   - Verify all dependencies in package.json
   - Check test failures in GitHub Actions logs

3. **Deployment Fails**
   - Check Cloud Run service limits
   - Verify port configuration (3031)
   - Check environment variables

### Useful Commands
```bash
# Delete service (if needed to start fresh)
gcloud run services delete feathers-backend --region=us-central1

# Update service manually
gcloud run deploy feathers-backend \
  --image=us-central1-docker.pkg.dev/PROJECT_ID/feathers-repo/feathers-backend:latest \
  --region=us-central1 \
  --port=3031 \
  --allow-unauthenticated
```

## 🎯 Interview Talking Points

This setup demonstrates knowledge of:
- **CI/CD Pipelines**: Multi-stage GitHub Actions workflow
- **Containerization**: Multi-stage Docker builds with security best practices
- **Cloud Services**: Google Cloud Run, Artifact Registry
- **Security**: Service accounts, IAM roles, secrets management
- **DevOps**: Infrastructure as Code, automated testing and deployment
- **Monitoring**: Health checks, logging, error handling

## 📚 Next Steps

1. Add environment-specific deployments (staging/production)
2. Implement blue-green deployments
3. Add monitoring and alerting
4. Set up automated rollbacks
5. Add security scanning to pipeline
