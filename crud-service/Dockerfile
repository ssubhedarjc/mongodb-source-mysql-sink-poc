FROM node:18-alpine

# Install MongoDB shell
RUN apk add --no-cache mongodb-tools

# Install mongosh
RUN wget -qO- https://downloads.mongodb.com/compass/mongosh-1.10.6-linux-x64.tgz | tar xvz -C /tmp \
    && mv /tmp/mongosh-1.10.6-linux-x64/bin/mongosh /usr/local/bin/ \
    && chmod +x /usr/local/bin/mongosh

WORKDIR /app

COPY crud-operations.js .
COPY package.json .

RUN npm install

CMD ["node", "crud-operations.js"]
