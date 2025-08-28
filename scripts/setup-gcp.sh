#!/bin/bash

# 🚀 Google Cloud Setup Script for GitHub Actions CI/CD
# This script sets up all the necessary GCP resources for the CI/CD pipeline

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "Google Cloud CLI is not installed. Please install it first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
if [ -z "$PROJECT_ID" ]; then
    print_status "Enter your Google Cloud Project ID:"
    read -r PROJECT_ID
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "Project ID is required"
    exit 1
fi

print_status "Setting up CI/CD for project: $PROJECT_ID"

# Set the project
print_status "Setting active project..."
gcloud config set project "$PROJECT_ID"

# Enable required APIs
print_status "Enabling required Google Cloud APIs..."
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com

print_success "APIs enabled successfully"

# Create Artifact Registry repository
print_status "Creating Artifact Registry repository..."
if gcloud artifacts repositories describe feathers-repo --location=us-central1 &>/dev/null; then
    print_warning "Artifact Registry repository 'feathers-repo' already exists"
else
    gcloud artifacts repositories create feathers-repo \
      --repository-format=docker \
      --location=us-central1 \
      --description="Docker repository for Feathers backend"
    print_success "Artifact Registry repository created"
fi

# Create service account
SA_NAME="github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

print_status "Creating service account..."
if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    print_warning "Service account '$SA_EMAIL' already exists"
else
    gcloud iam service-accounts create "$SA_NAME" \
      --description="Service account for GitHub Actions CI/CD" \
      --display-name="GitHub Actions"
    print_success "Service account created"
fi

# Grant IAM roles
print_status "Granting IAM permissions..."

ROLES=(
    "roles/run.admin"
    "roles/storage.admin"
    "roles/artifactregistry.writer"
    "roles/iam.serviceAccountUser"
    "roles/logging.viewer"
)

for role in "${ROLES[@]}"; do
    print_status "Granting role: $role"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="$role" \
      --quiet
done

print_success "IAM permissions granted"

# Create service account key
KEY_FILE="github-actions-key.json"
print_status "Creating service account key..."

if [ -f "$KEY_FILE" ]; then
    print_warning "Key file '$KEY_FILE' already exists. Skipping key creation."
    print_warning "If you need a new key, delete the existing file and run this script again."
else
    gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account="$SA_EMAIL"
    print_success "Service account key created: $KEY_FILE"
fi

# Display setup summary
echo ""
echo "🎉 Setup Complete!"
echo "===================="
echo ""
echo "📋 Next Steps:"
echo "1. Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):"
echo ""
echo "   Secret Name: GCP_PROJECT_ID"
echo "   Value: $PROJECT_ID"
echo ""
echo "   Secret Name: GCP_SA_KEY"
echo "   Value: (contents of $KEY_FILE)"
echo ""
echo "2. Copy the contents of $KEY_FILE:"
if [ -f "$KEY_FILE" ]; then
    echo ""
    echo "   cat $KEY_FILE | pbcopy  # macOS"
    echo "   cat $KEY_FILE | xclip -selection clipboard  # Linux"
    echo ""
fi
echo "3. Push your code to the main branch to trigger the first deployment"
echo ""
echo "🔗 Useful Commands:"
echo "   View logs: gcloud logging read \"resource.type=cloud_run_revision\" --limit=50"
echo "   List services: gcloud run services list"
echo "   Delete service: gcloud run services delete feathers-backend --region=us-central1"
echo ""
echo "⚠️  Security Note:"
echo "   - Keep the $KEY_FILE secure and never commit it to version control"
echo "   - Consider using Workload Identity Federation for enhanced security"
echo "   - The service account has broad permissions for this demo"
echo ""

# Cleanup reminder
print_warning "Remember to delete $KEY_FILE after adding it to GitHub secrets!"
print_warning "rm $KEY_FILE"
