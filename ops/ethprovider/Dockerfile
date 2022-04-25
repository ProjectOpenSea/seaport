FROM node:14.15.4-alpine3.12
WORKDIR /root
ENV HOME /root
RUN apk add --update --no-cache bash curl git jq
RUN npm config set unsafe-perm true && npm install -g npm@6.14.11
RUN curl https://raw.githubusercontent.com/vishnubob/wait-for-it/ed77b63706ea721766a62ff22d3a251d8b4a6a30/wait-for-it.sh > /bin/wait-for && chmod +x /bin/wait-for
RUN npm install -g hardhat
COPY entry.sh /entry.sh
ENV PATH="./node_modules/.bin:/root/node_modules/.bin:${PATH}"
ENTRYPOINT ["bash", "/entry.sh"]
