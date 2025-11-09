FROM python:3.12-alpine

# Install Docker CLI + Compose v2 plugin
RUN apk add --no-cache docker-cli docker-cli-compose

# Copy your script into PATH and make it executable
# (Make sure the file exists next to this Dockerfile)
COPY hasta-la-vista-baby /usr/local/bin/hasta-la-vista-baby
RUN chmod +x /usr/local/bin/hasta-la-vista-baby
