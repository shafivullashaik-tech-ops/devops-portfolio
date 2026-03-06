#!/bin/bash
#
# setup-backend.sh
# Sets up Terraform remote backend (S3 + DynamoDB)
#
# Usage: ./setup-backend.sh <environment> [aws-region]
# Example: ./setup-backend.sh dev us-east-1
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Environment argument required"
    echo "Usage: $0 <environment> [aws-region]"
    echo "Example: $0 dev us-east-1"
    exit 1
fi

ENVIRONMENT=$1
AWS_REGION=${2:-us-east-1}
BUCKET_NAME="devops-portfolio-tfstate-${ENVIRONMENT}"
DYNAMODB_TABLE="devops-portfolio-tfstate-lock-${ENVIRONMENT}"

log_info "Setting up Terraform backend for environment: ${ENVIRONMENT}"
log_info "Region: ${AWS_REGION}"

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    log_error "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_info "AWS Account ID: ${AWS_ACCOUNT_ID}"

# Create S3 bucket
log_info "Creating S3 bucket: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    # Bucket doesn't exist, create it
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --acl private
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}" \
            --acl private
    fi

    # Wait for bucket to be created
    aws s3api wait bucket-exists --bucket "${BUCKET_NAME}"
    log_info "S3 bucket created successfully"

    # Enable versioning
    log_info "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    log_info "Enabling default encryption on S3 bucket..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": false
            }]
        }'

    # Block public access
    log_info "Blocking public access on S3 bucket..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Add bucket policy
    log_info "Adding bucket policy..."
    cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF

    aws s3api put-bucket-policy \
        --bucket "${BUCKET_NAME}" \
        --policy file:///tmp/bucket-policy.json

    rm /tmp/bucket-policy.json

else
    log_warn "S3 bucket already exists: ${BUCKET_NAME}"
fi

# Create DynamoDB table
log_info "Creating DynamoDB table: ${DYNAMODB_TABLE}..."
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    log_warn "DynamoDB table already exists: ${DYNAMODB_TABLE}"
else
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "${AWS_REGION}" \
        --tags Key=Environment,Value="${ENVIRONMENT}" Key=ManagedBy,Value=Terraform \
        > /dev/null

    # Wait for table to be created
    log_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"

    log_info "DynamoDB table created successfully"
fi

# Display backend configuration
log_info "Backend setup complete!"
echo ""
echo -e "${GREEN}Add this to your Terraform backend configuration:${NC}"
echo ""
cat <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
  }
}
EOF
echo ""
log_info "Now run: cd terraform/environments/${ENVIRONMENT} && terraform init"
