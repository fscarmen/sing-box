# 使用 Alpine 镜像
FROM alpine:latest
ARG TARGETARCH
ENV ARCH=$TARGETARCH

# 设置工作目录
WORKDIR /sing-box

# 复制初始化脚本
COPY docker_init.sh /sing-box/init.sh

# 安装依赖并生成证书
RUN set -ex &&\
  apk add --no-cache supervisor wget nginx bash openssl &&\
  mkdir -p /sing-box/cert /sing-box/conf /sing-box/subscribe /sing-box/logs &&\
  chmod +x /sing-box/init.sh &&\
  rm -rf /var/cache/apk/*

CMD [ "./init.sh" ]