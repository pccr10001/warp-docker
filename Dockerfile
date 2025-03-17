FROM ubuntu:22.04 AS builder
RUN apt update && apt install build-essential git -y && \
    git clone --recurse-submodules https://github.com/heiher/hev-socks5-tunnel src && \
    cd /src && make 


FROM ubuntu:22.04

ARG WARP_VERSION
ARG GOST_VERSION
ARG COMMIT_SHA
ARG TARGETPLATFORM

LABEL org.opencontainers.image.authors="pccr10001"
LABEL org.opencontainers.image.url="https://github.com/pccr10001/warp-docker"
LABEL WARP_VERSION=${WARP_VERSION}
LABEL GOST_VERSION=${GOST_VERSION}
LABEL COMMIT_SHA=${COMMIT_SHA}

# install dependencies
RUN case ${TARGETPLATFORM} in \
      "linux/amd64")   export ARCH="amd64" ;; \
      "linux/arm64")   export ARCH="armv8" ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    echo "Building for ${TARGETPLATFORM} with GOST ${GOST_VERSION}" &&\
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl gnupg lsb-release sudo && \
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    apt-get clean

COPY --from=builder /src/bin/hev-socks5-tunnel /opt/tun2socks

# Accept Cloudflare WARP TOS
RUN mkdir -p /root/.local/share/warp && \
    echo -n 'yes' > /root/.local/share/warp/accepted-tos.txt

ENV WARP_SLEEP=2
ENV REGISTER_WHEN_MDM_EXISTS=
ENV WARP_LICENSE_KEY=


HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD /healthcheck/index.sh

ADD ./entrypoint.sh /entrypoint.sh
ADD ./healthcheck /healthcheck
ADD ./hs5t.yml /opt/hs5t.yml
ADD ./routes.sh /opt/routes.sh

RUN chmod +x /entrypoint.sh && \
    chmod +x /healthcheck/index.sh && \
    chmod +x /opt/tun2socks && \
    chmod +x /opt/routes.sh

ENTRYPOINT ["/entrypoint.sh"]
