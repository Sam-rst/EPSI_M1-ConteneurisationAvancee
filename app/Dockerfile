# syntax=docker/dockerfile:1.7

# =============================================================================
# Image runtime pour l'application gestion-produits (PHP + Apache).
# =============================================================================
# - Pilotes PDO MySQL et PostgreSQL embarqués : la même image sert pour la
#   version prod (MySQL) et pour la version dev (PostgreSQL), sélectionnée
#   à l'exécution via la variable d'environnement DB_DRIVER.
# - Apache écoute sur le port 80 ; le TLS est terminé en amont par Traefik
#   (cf. docker/ et k8s/).
# - Les uploads de fichiers sont écrits dans /var/www/html/uploads, à monter
#   en volume persistant côté Docker / PVC côté Kubernetes.
# =============================================================================

FROM php:8.2-apache AS runtime

# Métadonnées d'image (OCI labels) ------------------------------------------------
LABEL org.opencontainers.image.title="gestion-produits"
LABEL org.opencontainers.image.description="TP EPSI M1 — application de gestion de produits (PHP + PDO)"
LABEL org.opencontainers.image.source="https://github.com/samrst/infra-tp-cont"
LABEL org.opencontainers.image.licenses="MIT"

# Extensions PHP -----------------------------------------------------------------
# pdo_mysql et pdo_pgsql sont fournis par les sources de PHP, mais pdo_pgsql
# requiert libpq-dev pour la compilation. On supprime les paquets de build à la
# fin pour garder l'image légère.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libpq-dev \
        ; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql pdo_pgsql; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# Configuration Apache -----------------------------------------------------------
# Activation du module rewrite (pratique pour les URL propres) + petit hardening :
# on n'expose pas la version PHP via les en-têtes HTTP.
RUN a2enmod rewrite headers; \
    { \
      echo 'expose_php = Off'; \
      echo 'display_errors = Off'; \
      echo 'log_errors = On'; \
      echo 'error_log = /proc/self/fd/2'; \
      echo 'upload_max_filesize = 16M'; \
      echo 'post_max_size = 20M'; \
    } > /usr/local/etc/php/conf.d/zz-app.ini

# Code applicatif ----------------------------------------------------------------
# Les sources sont copiées depuis php/www du repo. Le dossier uploads est
# initialement vide ; il sera monté en volume en runtime.
WORKDIR /var/www/html
COPY --chown=www-data:www-data php/www/ /var/www/html/

# Permissions : www-data doit pouvoir écrire dans uploads.
RUN mkdir -p /var/www/html/uploads \
    && chown -R www-data:www-data /var/www/html/uploads \
    && chmod -R 775 /var/www/html/uploads

# Healthcheck --------------------------------------------------------------------
# Vérifie que Apache répond. La page de login (/) renvoie 200, ce qui est
# suffisant pour le LB / orchestrateur.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://localhost/ >/dev/null || exit 1

# curl est nécessaire pour le healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 80
