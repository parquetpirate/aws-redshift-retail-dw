# Official Ubuntu image as base
FROM ubuntu:latest

# Image maintainer
LABEL maintainer="Erick F Ribeiro"

# Update system packages and install required dependencies
RUN apt-get update && \
    apt-get install -y wget unzip curl git openssh-client iputils-ping postgresql postgresql-contrib

# Define the Terraform version (adjust as needed)
ENV TERRAFORM_VERSION=1.15.8

# Download and install Terraform
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Create the /iac folder as a mount point for a volume
RUN mkdir /iac

# Create the Downloads folder and install AWS CLI (to access AWS)
RUN mkdir Downloads && \
    cd Downloads && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# Set the default command to run when the container starts
CMD ["/bin/bash"]
