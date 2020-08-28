#!/bin/sh

clear
echo "working on project ${BC_PROJECT}"
echo "----------------------------------------------------------------------------------------------" 
oc project ${BC_PROJECT}
oc status  --suggest

echo "----------------------------------------------------------------------------------------------" 
echo "Welcome"
echo "Typically you will setup the Tekton pipeline first as a one time activity."
echo "Next, you can run the pipeline as many times as you like."

PS3='Please enter your choice: '
options=("setup basic pipeline" "run pipeline" "add sonar scan to pipeline" "setup pipeline with push to ICR" "run pipeline with push to ICR" "switch branch" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "setup basic pipeline")

            echo "setup pipeline in namespace ${BC_PROJECT}"

            #1 setup tekton resources
            echo "************************ setup Tekton PipelineResources ******************************************"
            cp ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${DOCKER_USERNAME}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            oc apply -f ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            #oc get PipelineResources
            tkn resources list

            #2 - setup tekton tasks to interact with OpenShift
            # credits: https://github.com/openshift/pipelines-tutorial/
            # licensed under Apache 2.0
            echo "************************ setup Tekton Tasks for interacting with OpenShift ******************************************"
            oc apply -f 01_apply_manifest_task.yaml
            oc apply -f 02_update_deployment_task.yaml
            oc apply -f 03_restart_deployment_task.yaml
            oc apply -f 04_build_vfs_storage.yaml
            oc apply -f 05_java_sonarqube_task.yaml
            oc apply -f 06_VA_scan.yaml
            tkn task list

            #3 - setup tekton pipeline 
            echo "************************ setup Tekton Pipeline ******************************************"
            #oc apply -f pipeline.yaml
            oc apply -f pipeline-vfs.yaml
            tkn pipeline list

            #4 - recreate access key
            echo "************************ recreate access key to dockerhub ******************************************"
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://index.docker.io/v1/ \
            --docker-username=${DOCKER_USERNAME} \
            --docker-password=${DOCKER_PASSWORD} \
            --docker-email=${DOCKER_EMAIL}
            #oc get secret regcred

            # 6 - give the default service account the access keys to the registry 
            echo " overwhelming the deployer with irrelevant information (hint: not a best practice)"
            echo " did you know that the human working memory has room to hold 4 facts"
            echo " I might just have pushed out some relevant facts"
            oc secrets link default regcred --for=pull

            break
            ;;
        "run pipeline")

            echo "************************ Run Tekton Pipeline ******************************************"
            echo "run pipeline in namespace ${BC_PROJECT} using following configuration:"
            tkn resource list | grep inventory

            tkn pipeline start build-and-deploy-java -r git-repo=git-source-inventory -r image=docker-image-inventory -p deployment-name=catalog-lightblue-deployment
            break
            ;;
        "setup triggers")
            echo "setup triggers in namespace ${BC_PROJECT}"
            break
            ;;
        "add sonar scan to pipeline")

            #1 setup tekton resources
            echo "************************ setup Tekton PipelineResources ******************************************"
            cp ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${DOCKER_USERNAME}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            oc apply -f ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            #oc get PipelineResources
            tkn resources list

            #4 - recreate access key
            echo "************************ recreate access key to dockerhub ******************************************"
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://index.docker.io/v1/ \
            --docker-username=${DOCKER_USERNAME} \
            --docker-password=${DOCKER_PASSWORD} \
            --docker-email=${DOCKER_EMAIL}
            #oc get secret regcred            

            oc apply -f pipeline-vfs-sonar.yaml
            tkn pipeline list

            echo "using SONARQUBE_URL=${SONARQUBE_URL}"
            oc delete configmap sonarqube-config-java 2>/dev/null
            oc create configmap sonarqube-config-java \
              --from-literal SONARQUBE_URL=${SONARQUBE_URL}
            
            # TODO: make project name configurable             
            oc delete secret sonarqube-access-java 2>/dev/null
            oc create secret generic sonarqube-access-java \
              --from-literal SONARQUBE_PROJECT=${SONARQUBE_PROJECT} \
              --from-literal SONARQUBE_LOGIN=${SONARQUBE_LOGIN} 

            break
            ;;
       "setup pipeline with push to ICR")

            # Recreate access token to IBM Container Registry
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://${IBM_REGISTRY_URL}/v1/ \
            --docker-username=iamapikey \
            --docker-password=${IBM_ID_APIKEY} \
            --docker-email=${IBM_ID_EMAIL}

            # Update Tekton Resources to push 
            cp ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${IBM_REGISTRY_NS}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/index.docker.io/${IBM_REGISTRY_URL}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            #cat ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml
            oc apply -f ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-inventory-pipeline-resources.yaml.mod

            #oc get PipelineResources
            tkn resources list

            echo "************************ setup Tekton Pipeline with IBM VA scan ******************************************"
            oc apply -f pipeline-vfs-icr.yaml
            #oc apply -f pipeline-full.yaml
            tkn pipeline list

            oc delete secret ibmcloud-apikey 2>/dev/null
            oc create secret generic ibmcloud-apikey --from-literal APIKEY=${IBM_ID_APIKEY}

            oc delete configmap ibmcloud-config 2>/dev/null
            oc create configmap ibmcloud-config \
             --from-literal RESOURCE_GROUP=default \
             --from-literal REGION=eu-de

            break
            ;;            
        "run pipeline with push to ICR")

            echo "************************ Run Tekton Pipeline ******************************************"
            echo "run pipeline in namespace ${BC_PROJECT} using following configuration:"
            tkn resource list | grep inventory

            tkn pipeline start build-and-deploy-java \
              -r git-repo=git-source-inventory \
              -r image=docker-image-inventory \
              -p deployment-name=catalog-lightblue-deployment \
              -p image-url-name=${IBM_REGISTRY_URL}/${IBM_REGISTRY_NS}/lightbluecompute-catalog:latest \
              -p scan-image-name=true
            break
            ;;
        "switch branch")
            echo "switching branch"
            ./mod_branch.sh
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
echo "hello kitty catt"
