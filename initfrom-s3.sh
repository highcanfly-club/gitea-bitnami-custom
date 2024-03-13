#!/bin/bash
BACKUP_DIR=/bitnami/gitea/backups
FILESTORE_DIR=/bitnami/gitea
export MC_CONFIG_DIR=bitnami/gitea/.mc

# test if variables GITEA_DATABASE_HOST, GITEA_DATABASE_NAME, GITEA_DATABASE_USERNAME, GITEA_DATABASE_PASSWORD are set
if [ -z "${GITEA_DATABASE_HOST}" ] || [ -z "${GITEA_DATABASE_NAME}" ] || [ -z "${GITEA_DATABASE_USERNAME}" ] || [ -z "${GITEA_DATABASE_PASSWORD}" ]; then
    echo "GITEA_DATABASE_HOST, GITEA_DATABASE_NAME, GITEA_DATABASE_USERNAME, GITEA_DATABASE_PASSWORD are not set"
    exit 1
fi
# default database port is 5432
GITEA_DATABASE_PORT_NUMBER=${GITEA_DATABASE_PORT_NUMBER:-5432}

# Test if we can connect to database with psql
if ! PGPASSWORD=${GITEA_DATABASE_PASSWORD} psql -h ${GITEA_DATABASE_HOST} -p ${GITEA_DATABASE_PORT_NUMBER} -U ${GITEA_DATABASE_USERNAME} -d ${GITEA_DATABASE_NAME} -c '\q'; then
    echo "Could not connect to the database"
    exit 1
fi

# test if variables S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are set
if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_PATH}" ]; then
    echo "S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are not set"
    exit 1
fi

# test if mc is installed
if [ -z "$(which mc)" ]; then
    echo "mc is not installed"
    exit 1
fi

#  Test if mc alias s3backup exists
if [ -z "$(mc alias list | grep s3backup)" ]; then
    echo "s3backup alias not found"
    echo "create s3backup alias"
    mc alias set s3backup ${S3_ENDPOINT} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}
fi

# create a backup directory
mkdir -p ${BACKUP_DIR}

# Find latest backup file in s3 if S3_GITEA_FILE is not set
if [ -z "${S3_GITEA_FILE}" ]; then
    LATEST_BACKUP=$(mc ls s3backup/${S3_BUCKET}/${S3_PATH} | sort -r | head -n 1 | awk '{print $6}')
else
    LATEST_BACKUP=${S3_GITEA_FILE}
fi
mc cp s3backup/${S3_BUCKET}/${S3_PATH}/${LATEST_BACKUP} ${BACKUP_DIR}/${LATEST_BACKUP}

# If the backup extension is .enc, decrypt it
if [ "${LATEST_BACKUP##*.}" == "enc" ]; then
    LATEST_BACKUP_BASE=$(echo $LATEST_BACKUP | sed 's/.enc//')
    DECRYPT=""
    if [ -n "$CRYPTOKEN" ]; then
        echo "Archive is encrypted, decrypting"
        DECRYPT="-pass pass:$CRYPTOKEN"
    else
        echo "CRYPTOKEN is not set but backup file is encrypted"
        exit 1
    fi
    openssl aes-256-cbc -a -d -md sha256 $DECRYPT -in ${BACKUP_DIR}/${LATEST_BACKUP} -out - >${BACKUP_DIR}/${LATEST_BACKUP_BASE}
    rm -f ${BACKUP_DIR}/${LATEST_BACKUP}
    LATEST_BACKUP=${LATEST_BACKUP_BASE}
fi
# Unzip the backup file to /tmp
TMP_DIR=$(mktemp -d)
unzip -o ${BACKUP_DIR}/${LATEST_BACKUP} -d ${TMP_DIR}

# Connect to the PostgreSQL database server
export PGPASSWORD=${GITEA_DATABASE_PASSWORD}

# Drop the existing database
echo "Drop the existing database"
psql -v ON_ERROR_STOP=1 -h ${GITEA_DATABASE_HOST} -p ${GITEA_DATABASE_PORT_NUMBER} -U ${GITEA_DATABASE_USERNAME} -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${GITEA_DATABASE_NAME}' AND pid <> pg_backend_pid();"
psql -v ON_ERROR_STOP=1 -h ${GITEA_DATABASE_HOST} -p ${GITEA_DATABASE_PORT_NUMBER} -U ${GITEA_DATABASE_USERNAME} -d postgres -c '\c' -c "DROP DATABASE IF EXISTS ${GITEA_DATABASE_NAME};"

# Create a new database
echo "Create a new database"
psql -v ON_ERROR_STOP=1 -h ${GITEA_DATABASE_HOST} -p ${GITEA_DATABASE_PORT_NUMBER} -U ${GITEA_DATABASE_USERNAME} -d postgres -c "CREATE DATABASE ${GITEA_DATABASE_NAME};"

# Restore the database from the dump
echo "Restore the database from the dump"
# Start a background job that prints a dot every second
while sleep 1; do printf "."; done &

# Save the PID of the background job to a variable
BG_JOB_PID=$!
# Run the psql command and redirect its output to ${BACKUP_DIR}/${LATEST_BACKUP_BASE}.log
psql -v ON_ERROR_STOP=1 -h ${GITEA_DATABASE_HOST} -p ${GITEA_DATABASE_PORT_NUMBER} -U ${GITEA_DATABASE_USERNAME} -d ${GITEA_DATABASE_NAME} -f ${TMP_DIR}/gitea-db.sql > ${BACKUP_DIR}/${LATEST_BACKUP_BASE}.log 2>&1

# Kill the background job
kill $BG_JOB_PID

# Print a new line
echo
echo "Restore filestore"
# Remove the filestore directory
mkdir -p ${FILESTORE_DIR}/custom/conf
mkdir -p ${FILESTORE_DIR}/data
mkdir -p ${FILESTORE_DIR}/log
mkdir -p ${FILESTORE_DIR}/gitea-repositories
cp -av ${TMP_DIR}/app.ini ${FILESTORE_DIR}/custom/conf/app.ini
cp -av ${TMP_DIR}/data/* ${FILESTORE_DIR}/data/
cp -av ${TMP_DIR}/log/* ${FILESTORE_DIR}/log/
cp -av ${TMP_DIR}/repos ${FILESTORE_DIR}/data/git/repositories
rm -rf ${TMP_DIR}
rm -f ${BACKUP_DIR}/${LATEST_BACKUP}
