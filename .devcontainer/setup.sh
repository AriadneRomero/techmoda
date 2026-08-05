#!/bin/bash

echo "================================================"
echo "TechModa Serverless Capstone - Environment Setup"
echo "================================================"
echo ""

# Install AWS SAM CLI
echo "Installing AWS SAM CLI..."
pip3 install --user aws-sam-cli

# Add SAM to PATH
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
export PATH=$PATH:$HOME/.local/bin

# Verify installations
echo ""
echo "Verifying installations..."
echo "------------------------"
echo "Node.js version:"
node --version
echo ""
echo "npm version:"
npm --version
echo ""
echo "AWS CLI version:"
aws --version
echo ""
echo "SAM CLI version:"
sam --version
echo ""

echo "================================================"
echo "Environment setup complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Configure AWS credentials (see AWS_CREDENTIALS_SETUP.md)"
echo "2. Review the README.md for project overview"
echo "3. Start implementing Lambda functions!"
echo ""
