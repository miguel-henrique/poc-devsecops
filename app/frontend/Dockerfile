FROM nginxinc/nginx-unprivileged:1.27-alpine

# Rendered by Terraform (upstream list); must exist before docker build.
COPY generated/default.conf /etc/nginx/conf.d/default.conf

COPY --chown=101:101 static /usr/share/nginx/html

USER nginx

HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
    CMD wget -qO- http://127.0.0.1:8080/ || exit 1
