# 第一个阶段：使用 OpenSSL 生成证书文件
FROM alpine/openssl:latest AS openssl

# 生成私钥和证书
RUN openssl ecparam -genkey -name prime256v1 -out /private.key && \
    openssl req -new -x509 -days 36500 -key /private.key -out /cert.pem -subj "/CN=mozilla.org"

# 第二个阶段：使用 Alpine 镜像并复制证书文件
FROM alpine:latest
ARG TARGETARCH
ENV ARCH=$TARGETARCH

# 设置工作目录
WORKDIR /sing-box

# 从第一个阶段的 OpenSSL 镜像中复制证书文件到当前镜像
COPY --from=openssl /private.key /sing-box/cert/private.key
COPY --from=openssl /cert.pem /sing-box/cert/cert.pem
COPY docker_init.sh /sing-box/init.sh

RUN set -ex &&\
  apk add --no-cache supervisor wget nginx bash &&\
  mkdir -p /sing-box/conf /sing-box/subscribe /sing-box/logs &&\
  chmod +x /sing-box/init.sh &&\
  rm -rf /var/cache/apk/*

CMD [ "./init.sh" ]