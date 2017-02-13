#!/usr/bin/env bash
PACKAGE_FILES="$(pwd)/.package_updater"
UPDATER_PATH="$(pwd)/.updater"
PROJECT_NAME=${1}
PROJECT_VERSION=${2}
UPDATER_REPO=${3}
UPDATER_USER=${4}
OAUTH_TOKEN=${5}
USER_NAME=${6}
USER_EMAIL=${7}
mkdir "$UPDATER_PATH"
git clone "https://github.com/$UPDATER_USER/$UPDATER_REPO.git" "$UPDATER_PATH"
rm -rf "$UPDATER_PATH/$PROJECT_NAME"
mkdir "$UPDATER_PATH/$PROJECT_NAME"
cp -r "$PACKAGE_FILES/." "$UPDATER_PATH/$PROJECT_NAME"
cd "$UPDATER_PATH"
git add "./$PROJECT_NAME/" -A
git config --global user.name $USER_NAME
git config --global user.email $USER_EMAIL
git commit -m "Update '$PROJECT_NAME' to version $PROJECT_VERSION"
git push "https://$OAUTH_TOKEN@github.com/$UPDATER_USER/$UPDATER_REPO.git"