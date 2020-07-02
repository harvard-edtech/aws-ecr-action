FROM node:10-alpine

# setting this here prevents dev dependencies from installing
ENV NODE_ENV production

# copy the app code into the /app path
COPY ./ /app
WORKDIR /app

# install dependencies
RUN npm install

# run the build
RUN npm run build

EXPOSE 8080
ENV PORT 8080
CMD ["npm", "start"]
