FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm config set fetch-timeout 300000

RUN npm install

COPY . .

EXPOSE 8000

CMD ["npm", "start"]