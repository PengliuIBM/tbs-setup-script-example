#FROM node:14.16.0-alpine as build
#WORKDIR /app
#ENV PATH /app/node_modules/.bin:$PATH
#COPY package.json ./
#COPY package-lock.json ./
#RUN npm ci --silent
#RUN npm install react-scripts@3.4.1 -g --silent
#COPY . ./
#RUN npm run build
FROM nginx:stable-alpine
COPY build/ /usr/share/nginx/html
EXPOSE 8000
CMD ["nginx", "-g", "daemon off;"]
