# Dockerfile for dtctl - used by Argo Rollouts AnalysisTemplate
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    ca-certificates

# Install dtctl using official install script
RUN curl -fsSL https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.sh | sh && \
    mv /root/.local/bin/dtctl /usr/local/bin/dtctl && \
    chmod +x /usr/local/bin/dtctl

# Verify installation
RUN dtctl version

ENTRYPOINT ["/bin/bash"]
