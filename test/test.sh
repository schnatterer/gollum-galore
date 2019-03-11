#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail


main() {

    loginAndCreatePage

}

loginAndCreatePage() {

  TOKEN=$(curl "http://localhost:8080/login"  --data "username=bob&password=secret")
  EXPECTED_CONTENT="ThisIsOurContent"
  curl "http://localhost:8080/create" --data \
    "page=Home&path="%"2F&format=markdown&content=${EXPECTED_CONTENT}&message=Created+Home+"%"28markdown"%"29" -H "Cookie: jwt_token=$TOKEN"
  curl "http://localhost:8080/Home" -H "Cookie: jwt_token=$TOKEN" | grep ${EXPECTED_CONTENT}

}

main "$@"



