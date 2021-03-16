#!/bin/bash

set -o errexit
set -o pipefail
# set -o xtrace

# Load libraries
# shellcheck disable=SC1091
. /opt/bitnami/base/functions

# Constants
INIT_SEM=/tmp/initialized.sem

# Functions

########################
# Replace a regex in a file
# Arguments:
#   $1 - filename
#   $2 - match regex
#   $3 - substitute regex
#   $4 - regex modifier
# Returns: none
#########################
replace_in_file() {
    local filename="${1:?filename is required}"
    local match_regex="${2:?match regex is required}"
    local substitute_regex="${3:?substitute regex is required}"
    local regex_modifier="${4:-}"
    local result

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    result="$(sed "${regex_modifier}s@${match_regex}@${substitute_regex}@g" "$filename")"
    echo "$result" > "$filename"
}

########################
# Wait for database to be ready
# Globals:
#   DATABASE_HOST
#   DB_PORT
# Arguments: none
# Returns: none
#########################
wait_for_db() {
  local db_host="${DB_HOST:-mariadb}"
  local db_port="${DB_PORT:-3306}"
  local db_address=$(getent hosts "$db_host" | awk '{ print $1 }')
  counter=0
  log "Connecting to mariadb at $db_address"
  while ! nc -z "$db_address" "$db_port" >/dev/null; do
    counter=$((counter+1))
    if [ $counter == 30 ]; then
      log "Error: Couldn't connect to mariadb."
      exit 1
    fi
    log "Trying to connect to mariadb at $db_address. Attempt $counter."
    sleep 5
  done
}

########################
# Setup the database configuration
# Arguments: none
# Returns: none
#########################
setup_db() {
  log "Configuring the database"
  php artisan migrate --force
}

enable_apache_and_vhost(){
  log "Enabling virtual host"
  sudo a2ensite lightbox-api
  sudo chmod -R 777 /app/storage /app/bootstrap/cache
}

setting_up_supervisor(){
  log "Configuring supervisor"
  log "Copying config files"
  log "cp -R /app/supervisor/local/* /etc/supervisor/"
  sudo cp -R /app/supervisor/local/* /etc/supervisor/
  log "Checking if supervisor log folder exists"
  if [[ ! -d /app/storage/logs/supervisor ]]; then
    mkdir /app/storage/logs/supervisor;
  fi
  log "Configuring log folder"
  if [[ -d /var/log/supervisor ]]; then
    sudo rm -rf /var/log/supervisor;
  fi
  if [[ ! -f /var/log/supervisor ]]; then
    sudo ln -s /app/storage/logs/supervisor /var/log/supervisor;
  fi
  log "starting supervisor"
  log "sudo supervisord -c /etc/supervisor/supervisord.conf"
  sudo supervisord -c /etc/supervisor/supervisord.conf
}

copy_config_files(){
  log "Copying config files"
  log "Copying php.ini"
  log "sudo cp /app/docker_config_files/php/php.ini /etc/php/7.3/apache2/php2.ini"
  sudo cp /app/docker_config_files/php/php.ini /etc/php/7.3/apache2/php.ini
}

print_welcome_page
if [ "${1}" == "sudo" -a "$2" == "apachectl" -a "$3" == "-D" -a "$4" == "FOREGROUND" ]; then
  if [[ ! -f /app/config/database.php ]]; then
    log "Creating laravel application"
    cp -a /tmp/app/. /app/
  fi

  log "Installing/Updating Laravel dependencies (composer)"
  if [[ -f composer.lock ]]; then
    log "composer install"
    log "IF YOU WANT TO RUN composer update DELETE composer.lock"
    COMPOSER_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-128M} composer install
    log "Dependencies installed"
  else
    log "composer update"
    COMPOSER_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-128M} composer update
    log "Dependencies updated"
  fi

  copy_config_files
  enable_apache_and_vhost
  setting_up_supervisor
  wait_for_db
  

  if [[ -f $INIT_SEM ]]; then
    echo "#########################################################################"
    echo "                                                                         "
    echo " App initialization skipped:                                             "
    echo " Delete the file $INIT_SEM and restart the container to reinitialize     "
    echo " You can alternatively run specific commands using docker-compose exec   "
    echo " e.g docker-compose exec myapp php artisan make:console FooCommand       "
    echo "                                                                         "
    echo "#########################################################################"
  else
    setup_db
    log "Initialization finished"
    touch $INIT_SEM
  fi
fi

exec tini -- "$@"
