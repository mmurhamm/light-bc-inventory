# STAGE: Build
FROM gradle:4.9.0-jdk8-alpine as builder

# Create Working Directory
ENV BUILD_DIR=/home/gradle/app/
RUN mkdir $BUILD_DIR
WORKDIR $BUILD_DIR

# Download Dependencies
COPY build.gradle $BUILD_DIR
RUN gradle build -x :bootRepackage -x test --continue

# Copy Code Over and Build jar
COPY src src
RUN gradle build -x test

FROM openjdk:16-slim

# Install Extra Packages
#RUN apk --no-cache update \
# && apk add jq bash bc ca-certificates curl \
# && update-ca-certificates

# Install Extra Packages
#RUN apk --no-cache update \
# && apk add ca-certificates \
# && update-ca-certificates

# Install Extra Packages
#RUN apk --no-cache update \
# && apk add bash 


# Create app directory
ENV APP_HOME=/app
RUN mkdir -p $APP_HOME/scripts
WORKDIR $APP_HOME

# Copy jar file over from builder stage
COPY --from=builder /home/gradle/app/build/libs/micro-catalog-0.0.1.jar $APP_HOME
RUN mv ./micro-catalog-0.0.1.jar app.jar

COPY startup.sh startup.sh
COPY scripts/max_heap.sh scripts/

# Create user, chown, and chmod
#RUN adduser -u 2000 -G root -D blue \
#	&& chown -R 2000:0 $APP_HOME \
#	&& chmod -R u+x $APP_HOME/app.jar

# Go EX288 style!

RUN chown -R 1000:0 $APP_HOME && \
    chgrp -R 0 $APP_HOME && \
	chmod -R g=u $APP_HOME && \
	chmod -R ug+x $APP_HOME/app.jar
USER 1001

EXPOSE 8081
ENTRYPOINT ["./startup.sh"]
