#!/bin/bash
set -e

function main() {
  sanitize "${INPUT_ACCESS_KEY_ID}" "access_key_id"
  sanitize "${INPUT_SECRET_ACCESS_KEY}" "secret_access_key"
  sanitize "${INPUT_REGION}" "region"
  sanitize "${INPUT_ACCOUNT_ID}" "account_id"
  sanitize "${INPUT_REPO}" "repo"

  ACCOUNT_URL="$INPUT_ACCOUNT_ID.dkr.ecr.$INPUT_REGION.amazonaws.com"

  local TAGS=$INPUT_TAGS
  local GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD | sed -e 's/\//-/g')

  if [ "${INPUT_ADD_BRANCH_TAG}" = true ]; then
    echo "== INCLUDING GIT BRANCH IMAGE TAG ${GIT_BRANCH}"
    TAGS="$TAGS,$GIT_BRANCH"
  fi

  if [ "${INPUT_ADD_PACKAGE_VERSION_TAG_FOR_BRANCH}" = "${GIT_BRANCH}" ]; then
    package_version=$(node -p "require('./package.json').version")
    echo "== INCLUDING PACKAGE VERSION IMAGE TAG ${package_version}"
    TAGS="$TAGS,$package_version"
  fi

  local ECR_REPO_URL=https://console.aws.amazon.com/ecr/repositories/${INPUT_REPO}/

  slack_notify "Build triggered for ${INPUT_REPO}@${GIT_BRANCH}\nECR Repository: <${ECR_REPO_URL}|${INPUT_REPO}>"
  aws_configure
  assume_role
  login
  docker_build $TAGS $ACCOUNT_URL
  create_ecr_repo $INPUT_CREATE_REPO
  docker_push_to_ecr $TAGS $ACCOUNT_URL
}

function sanitize() {
  if [ -z "${1}" ]; then
    echo >&2 "Unable to find the ${2}. Did you set with.${2}?"
    exit 1
  fi
}

function aws_configure() {
  export AWS_ACCESS_KEY_ID=$INPUT_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY=$INPUT_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION=$INPUT_REGION
}

function login() {
  echo "== START LOGIN"
  LOGIN_COMMAND=$(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
  $LOGIN_COMMAND
  echo "== FINISHED LOGIN"
}

function assume_role() {
  if [ "${INPUT_ASSUME_ROLE}" != "" ]; then
    sanitize "${INPUT_ASSUME_ROLE}" "assume_role"
    echo "== START ASSUME ROLE"
    ROLE="arn:aws:iam::${INPUT_ACCOUNT_ID}:role/${INPUT_ASSUME_ROLE}"
    CREDENTIALS=$(aws sts assume-role --role-arn ${ROLE} --role-session-name ecrpush --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
    read id key token <<<${CREDENTIALS}
    export AWS_ACCESS_KEY_ID="${id}"
    export AWS_SECRET_ACCESS_KEY="${key}"
    export AWS_SESSION_TOKEN="${token}"
    echo "== FINISHED ASSUME ROLE"
  fi
}

function create_ecr_repo() {
  if [ "${1}" = true ]; then
    echo "== START CREATE REPO"
    aws ecr describe-repositories --region $AWS_DEFAULT_REGION --repository-names $INPUT_REPO >/dev/null 2>&1 ||
      aws ecr create-repository --region $AWS_DEFAULT_REGION --repository-name $INPUT_REPO
    echo "== FINISHED CREATE REPO"
  fi
}

function docker_build() {
  echo "== START DOCKERIZE"
  local TAG=$1
  local ACCOUNT_URL=$2
  local docker_tag_args=""
  local DOCKER_TAGS=$(echo "$TAG" | tr "," "\n")
  for tag in $DOCKER_TAGS; do
    docker_tag_args="$docker_tag_args -t $ACCOUNT_URL/$INPUT_REPO:$tag"
  done
  docker_tag_args="$docker_tag_args -t ${INPUT_REPO}:scan-me"
  echo ::set-output name=image_for_scanning::${INPUT_REPO}:scan-me

  local DOCKERFILE=$INPUT_DOCKERFILE

  if [ -f $DOCKERFILE ]; then
    echo "== USING PROVIDED Dockerfile"
  else
    echo "== USING GENERIC Dockerfile"
    DOCKERFILE=$(mktemp)
    cat <<EOF >$DOCKERFILE
FROM node:14-alpine

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
EOF

    echo "== CREATING GENERIC .dockeringore"
    # Must go in the root of the build context
    cat <<EOF >$INPUT_PATH/.dockerignore
# ignore all dot files/dirs
.*

# except for .dockerignore
# https://codefresh.io/docker-tutorial/not-ignore-dockerignore-2/
!.dockerignore

node_modules
test
build
dist
*.md
*.log
EOF
  fi

  docker build $INPUT_EXTRA_BUILD_ARGS -f $DOCKERFILE $docker_tag_args $INPUT_PATH
  echo "== FINISHED DOCKERIZE"
}

function docker_push_to_ecr() {
  echo "== START PUSH TO ECR"
  local TAG=$1
  local ACCOUNT_URL=$2
  local DOCKER_TAGS=$(echo "$TAG" | tr "," "\n")
  for tag in $DOCKER_TAGS; do
    image_with_tag=$INPUT_REPO:$tag
    docker push $ACCOUNT_URL/$image_with_tag
  done

  echo "== FINISHED PUSH TO ECR"
}

function slack_notify() {
  local MESSAGE=$1
  if [ ! -z "${INPUT_SLACK_WEBHOOK_URL}" ]; then
    curl $INPUT_SLACK_WEBHOOK_URL \
      -X POST -H 'Content-type: application/json' \
      --data @<(
        cat <<EOF
        {
          "blocks": [
            {
              "type": "section",
              "text": {
                "type": "mrkdwn",
                "text": "$MESSAGE"
              }
            }
          ]
        }
EOF
      )

  fi
}

main
