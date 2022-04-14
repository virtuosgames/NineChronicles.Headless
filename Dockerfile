FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build-env
WORKDIR /app
ARG COMMIT

# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM

# Copy csproj and restore as distinct layers
COPY ./Lib9c/Lib9c/Lib9c.csproj ./Lib9c/
COPY ./Libplanet.Headless/Libplanet.Headless.csproj ./Libplanet.Headless/
COPY ./NineChronicles.RPC.Shared/NineChronicles.RPC.Shared/NineChronicles.RPC.Shared.csproj ./NineChronicles.RPC.Shared/
COPY ./NineChronicles.Headless/NineChronicles.Headless.csproj ./NineChronicles.Headless/
COPY ./NineChronicles.Headless.Executable/NineChronicles.Headless.Executable.csproj ./NineChronicles.Headless.Executable/
RUN dotnet restore Lib9c
RUN dotnet restore Libplanet.Headless
RUN dotnet restore NineChronicles.RPC.Shared
RUN dotnet restore NineChronicles.Headless
RUN dotnet restore NineChronicles.Headless.Executable

# Copy everything else and build
COPY . ./
SHELL ["/bin/bash", "-c"]
RUN echo "$TARGETPLATFORM"
RUN dotnet publish NineChronicles.Headless.Executable/NineChronicles.Headless.Executable.csproj \
    -c Release \
    -r `case $TARGETPLATFORM in "linux/arm64") echo "linux-arm64" ;; "linux/amd64") echo "linux-x64" ;; esac` \
    -o out \
    --self-contained \
    --version-suffix $COMMIT

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:6.0-bullseye-slim
WORKDIR /app
RUN apt-get update && apt-get install -y libc6-dev
COPY --from=build-env /app/out .

# Install native deps & utilities for production
RUN apt-get update \
    && apt-get install -y --allow-unauthenticated \
        libc6-dev jq curl \
     && rm -rf /var/lib/apt/lists/*

VOLUME /data

ENTRYPOINT ["dotnet", "NineChronicles.Headless.Executable.dll"]
