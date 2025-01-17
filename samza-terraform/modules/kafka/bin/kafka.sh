#!/bin/sh

KAFKA_TARBALL="https://archive.apache.org/dist/kafka/2.1.1/kafka_2.11-2.1.1.tgz"
KAFKA_PORT=9092
SERVICE_NAME="kafka"
SERVICE_WAIT_TIMEOUT_SEC=120


METRICS_COLLECTOR_TARBALL="samza-metrics-collector-release-linux-0.0.2.tar.gz"
METRICS_COLLECTOR_TARBALL_URI="https://github.com/dnishimura/samza-metrics-collector/releases/download/0.0.2/$METRICS_COLLECTOR_TARBALL"
METRICS_COLLECTOR_DIR=samza-metrics-collector-release

BASE_DIR="$(pwd)"
DEPLOY_ROOT_DIR="${BASE_DIR}/deploy"

DOWNLOAD_CACHE_DIR="${BASE_DIR}/.download"
mkdir -p "${DOWNLOAD_CACHE_DIR}"

download() {
  PACKAGE_FILE_NAME="${DOWNLOAD_CACHE_DIR}/${SERVICE_NAME}"
  if [ -f "${PACKAGE_FILE_NAME}.tar.gz" ]; then
    echo "Using previously downloaded file ${PACKAGE_FILE_NAME}"
  else
    echo "Downloading ${KAFKA_TARBALL}"
    curl "${KAFKA_TARBALL}" > "${PACKAGE_FILE_NAME}.tmp"
    mv "${PACKAGE_FILE_NAME}.tmp" "${PACKAGE_FILE_NAME}.tar.gz"
  fi
  rm -rf "${DEPLOY_ROOT_DIR}"
  mkdir -p "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}"
  tar -xf "${PACKAGE_FILE_NAME}.tar.gz" --strip-components=1 -C "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}"

  pushd $DOWNLOAD_CACHE_DIR
  wget $METRICS_COLLECTOR_TARBALL_URI
  tar -zxf $METRICS_COLLECTOR_TARBALL
  mv $METRICS_COLLECTOR_DIR $DEPLOY_ROOT_DIR/
  popd
}

wait_for_service() {
  echo "Waiting for $SERVICE_NAME to start..."
  local CURRENT_WAIT_TIME=0

  while [ $(echo | nc -w1 localhost $KAFKA_PORT >/dev/null 2>&1 ;echo $?) -ne 0 ]; do
      printf '.'
      sleep 1
      if [ $((++CURRENT_WAIT_TIME)) -eq $SERVICE_WAIT_TIMEOUT_SEC ]; then
        printf "\nError: timed out while waiting for $SERVICE_NAME to start.\n"
        exit 1
      fi
  done
  printf '\n'
  echo "$SERVICE_NAME has started";
}

install_java() {
  sudo apt install -y openjdk-8-jre-headless
}

setup_java() {
  export JAVA_HOME=`readlink -f /usr/bin/java | sed "s:/bin/java::"`
}

install_kafka() {
  download
  # have to use SIGTERM since nohup on appears to ignore SIGINT
  # and Kafka switched to SIGINT in KAFKA-1031.
  sed -i.bak 's/SIGINT/SIGTERM/g' "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}/bin/kafka-server-stop.sh"
  cp server.properties "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}/config/"
}

start_kafka() {
  setup_java

  if [ -f "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}/bin/kafka-server-start.sh" ]; then
    mkdir -p "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}/logs"
    cd "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}"
    nohup bin/kafka-server-start.sh config/server.properties > logs/kafka.log 2>&1 &
    cd - > /dev/null
    wait_for_service "kafka" $KAFKA_PORT
    echo "Starting $DEPLOY_ROOT_DIR/$METRICS_COLLECTOR_DIR/samza-metrics-collector"
    LD_LIBRARY_PATH=$DEPLOY_ROOT_DIR/$METRICS_COLLECTOR_DIR nohup $DEPLOY_ROOT_DIR/$METRICS_COLLECTOR_DIR/samza-metrics-collector > $DEPLOY_ROOT_DIR/$SERVICE_NAME/logs/samza-metrics-collector.log 2>&1 &
    sleep 3
  else
    echo 'ERROR: Kafka is not installed at: ${DEPLOY_ROOT_DIR}/${SERVICE_NAME}'
  fi
}

stop_kafka() {
  setup_java
  if [ -f "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}/bin/kafka-server-stop.sh" ]; then
    cd "${DEPLOY_ROOT_DIR}/${SERVICE_NAME}"
    bin/kafka-server-stop.sh || true # tolerate nonzero exit status if Kafka isn't running
    cd - > /dev/null
  else
    echo "ERROR: Kafka is not installed at: ${DEPLOY_ROOT_DIR}/${SERVICE_NAME}"
  fi
}

case $1 in
  start)
    install_kafka
    start_kafka
    exit 0
  ;;

  stop)
    stop_kafka
    exit 0
  ;;
esac

echo "Usage: $0 stop|start"
