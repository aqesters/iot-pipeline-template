# Node-RED image with the extra palette nodes this pipeline needs baked in
# at build time (rather than installed at container start) so deploys are
# reproducible and don't need outbound npm access at every boot — important
# for client sites with locked-down egress.
#
# Extra nodes must be installed into /data (Node-RED's userDir, where it
# scans package.json for palette dependencies) — NOT into
# /usr/src/node-red, which is Node-RED's own application code and isn't
# scanned for user-added nodes. This follows the pattern documented at
# https://github.com/node-red/node-red-docker/wiki/Quick-Custom-Image.
# The base image's own WORKDIR is already /data, which is why `.` below
# resolves there.
FROM nodered/node-red:3.1.9-18

# Build tools for the npm install layer only, in case a client deployment
# later adds nodes with native bindings (Modbus/OPC-UA libraries commonly
# need node-gyp). Removed again in the same effective layer set so the
# final image doesn't carry the extra weight.
USER root
RUN apk add --no-cache --virtual .build-deps python3 make g++

USER node-red
WORKDIR /data

COPY --chown=node-red:node-red data/package.json .
RUN npm install --unsafe-perm --no-update-notifier --no-audit --omit=dev \
    && npm cache clean --force

USER root
RUN apk del .build-deps
USER node-red

# Seed the named volume mounted at /data. Docker populates a fresh (empty)
# named volume from the image's directory contents the first time it's
# mounted, so a brand new deploy starts with this exact flow, settings, and
# node_modules already in place. On redeploys, the existing volume (with
# whatever's been edited in the Node-RED editor since) takes precedence and
# these baked-in files are simply not copied again. See settings.js for
# flowFile / credentialSecret handling.
COPY --chown=node-red:node-red data/flows.json /data/flows.json
COPY --chown=node-red:node-red data/settings.js /data/settings.js

ENV NODE_RED_ENABLE_PROJECTS=false
