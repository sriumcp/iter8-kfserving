# Create the image for use within start and finish handles
FROM debian:buster-slim

# Install kubectl
RUN   apt update && \
      apt install -y curl && \
      curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
      chmod +x ./kubectl && \
      mv ./kubectl /usr/local/bin/kubectl

# Install wget
RUN   apt-get update \
      && apt-get install -y wget \
      && rm -rf /var/lib/apt/lists/*

# Install yq
RUN   wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64 \
      -O /usr/bin/yq && \
      chmod +x /usr/bin/yq

# Work from root
WORKDIR /

# Copy folders needed by handler scripts
COPY ./handlers /handlers
COPY ./patches /patches