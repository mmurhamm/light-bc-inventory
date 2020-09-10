# Docker Hub Section - not used
#export DOCKER_USERNAME=''
#export DOCKER_PASSWORD=''
#export DOCKER_EMAIL=''

# Git Section
export GIT_USERNAME='kitty-catt'

# SonarQube Server Section
# Login to SonarQube Server, make a project and generate a token for it.
export SONARQUBE_URL='http://sonarqube-sonarqube.tools.svc.cluster.local:9000'
export SONARQUBE_PROJECT='bc-light-inventory'
export SONARQUBE_LOGIN='7904fb70bc5d1fd4c01fcac93351d9b8577dc0d0'

# The target namespace or project in OpenShift
export BC_PROJECT="bc-light"

# ICR with VA Scan
export IBM_ID_APIKEY=IO0y6D49IUwXVDfMmx8KWN5pw1WDUUVe9qPKfDu1bGsv
export IBM_ID_EMAIL=ronald.van.de.kuil@nl.ibm.com
export IBM_REGISTRY_URL='de.icr.io'
export IBM_REGISTRY_NS=kitty-catt

# Quay registry with vulnerability scan
# export QUAY_USERNAME=''
# export QUAY_PASSWORD=''

./setup-bc-inventory-api.sh
