#!/bin/bash
#
# Deploy script for TechModa Serverless Capstone
# This script runs sam deploy to deploy the application to AWS
#

set -e

echo "Deploying SAM application..."
echo "============================="
echo ""

# Check if samconfig.toml exists
if [ ! -f "samconfig.toml" ]; then
    echo "Warning: samconfig.toml not found"
    echo "Creating from template..."
    cp samconfig.toml.example samconfig.toml
    echo ""
    echo "Running guided deployment..."
    sam deploy --guided
else
    echo "Using existing samconfig.toml"
    sam deploy
fi

echo ""
echo "Deployment complete!"
echo "Check the Outputs section above for your API URL"
