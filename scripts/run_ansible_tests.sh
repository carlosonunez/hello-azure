#!/usr/bin/env bash
SERVER_UNDER_TEST="ansible-test-$1"
PLAYBOOK_UNDER_TEST="${1}.yml"

_servers_available_to_test() {
  egrep -lr '^  tasks:' infra |\
    xargs -I {} basename {} |\
    sed 's/.yml$//' |\
    tr '\n' ',' |\
    sed 's/,$//'
}

usage() {
  cat <<-USAGE
Usage: $(basename $0) [server_under_test]
Runs Ansible tests locally with Docker

Mandatory arguments:
  [server_under_test]   The server under test.
                        Must be one of: [$(_servers_available_to_test)]

Other arguments:
  -h, --help            Prints this usage text.

This seems complicated! Why are we doing this?
===============================================

So our servers in this example use systemd to start their services. This seems to be
the most widely-accepted way of starting a Linux service at boot, but it
doesn't play well with Docker at all since Docker expects a one-shot process
to assume PID 1 instead of a long-running service manager like init.

To work around this without having to resort to complexities like SSHing
from one container to another, we:
  - Start the server under test with \`docker-compose up\`, then
  - Run ansible-playbook against it with \`docker-compose exec\` with this script, then
  - Tear everything down with \`docker-compose down\`.

For your convenience, a shortcut has been added for this script in
\`shortcuts\`. To use it, run: \`ansible_test [server_under_test]\`.

USAGE
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]
then
  usage
  exit 0
fi

server_under_test_exists() {
  docker-compose config --services | \
    grep -q "$SERVER_UNDER_TEST"
}

playbook_under_test_exists() {
  test -f "infra/$PLAYBOOK_UNDER_TEST"
}

setup() {
  docker-compose up -d "$SERVER_UNDER_TEST"
}

run_tests() {
  if [ "$DEBUG_MODE" == "true" ]
  then
    docker-compose exec "$SERVER_UNDER_TEST" ansible-playbook -vvv "$PLAYBOOK_UNDER_TEST"
  else
    docker-compose exec "$SERVER_UNDER_TEST" ansible-playbook "$PLAYBOOK_UNDER_TEST"
  fi
}

teardown() {
  docker-compose down
}

if ! server_under_test_exists
then
  >&2 echo "ERROR: Define this in your docker-compose.yml: $SERVER_UNDER_TEST"
  exit 1
fi

if ! playbook_under_test_exists
then
  >&2 echo "ERROR: Define a playbook called "$PLAYBOOK_UNDER_TEST" \
inside of the 'infra/' directory."
  exit 1
fi

setup && run_tests && teardown
