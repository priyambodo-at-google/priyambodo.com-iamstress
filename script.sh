# INITIALIZE COMMON VARIABLE

#References: https://cloud.google.com/architecture/distributed-load-testing-using-gke 
#GitHub: https://github.com/GoogleCloudPlatform/distributed-load-testing-using-kubernetes

cd /Users/priyambodo/Desktop/Coding/00.github-priyambodo-at-google/public/priyambodo.com/priyambodo.com-iamstress

export GKE_CLUSTER=autopilot-locust-stresstest
export AR_REPO=iamstress-artifactregistry
export REGION=us-central1
export ZONE=us-central1-b
export SAMPLE_APP_LOCATION=us-central

export GKE_NODE_TYPE=e2-standard-4
export GKE_SCOPE="https://www.googleapis.com/auth/cloud-platform"
export PROJECT=$(gcloud config get-value project)
export PROJECT=work-mylab-machinelearning
export SAMPLE_APP_TARGET=${PROJECT}.appspot.com
export NETWORK_NAME=vpc-default-by-doddipriyambodo
export SERVICE_ACCOUNT=iamstress-serviceaccount

gcloud config set project ${PROJECT}
gcloud config set compute/zone ${ZONE}

#Create a GKE cluster

gcloud iam service-accounts create iamstress-serviceaccount
gcloud projects add-iam-policy-binding  ${PROJECT} --member=serviceAccount:${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com --role=roles/artifactregistry.reader
gcloud projects add-iam-policy-binding  ${PROJECT} --member=serviceAccount:${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com --role=roles/container.nodeServiceAccount

gcloud container clusters create ${GKE_CLUSTER} \
--service-account=${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com \
--region ${REGION} \
--network ${NETWORK_NAME} \
--machine-type ${GKE_NODE_TYPE} \
--enable-autoscaling \
--num-nodes 3 \
--min-nodes 3 \
--max-nodes 10 \
--scopes "${GKE_SCOPE}"

gcloud container clusters get-credentials ${GKE_CLUSTER} \
   --region ${REGION} \
   --project ${PROJECT}

#Set up the environment

git clone https://github.com/GoogleCloudPlatform/distributed-load-testing-using-kubernetes
cd distributed-load-testing-using-kubernetes

#Build the container image

gcloud artifacts repositories create ${AR_REPO} \
    --repository-format=docker  \
    --location=${REGION} \
    --description="Distributed load testing with GKE and Locust"

export LOCUST_IMAGE_NAME=locust-tasks
export LOCUST_IMAGE_TAG=latest
gcloud builds submit \
    --tag ${REGION}-docker.pkg.dev/${PROJECT}/${AR_REPO}/${LOCUST_IMAGE_NAME}:${LOCUST_IMAGE_TAG} \
    docker-image

#Verify Docker
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT}/${AR_REPO} | \
    grep ${LOCUST_IMAGE_NAME}

#Deploy the sample application
gcloud app create --region=${SAMPLE_APP_LOCATION}
gcloud app deploy sample-webapp/app.yaml \
--project=${PROJECT}

#Deploy the Locust master and worker Pods

envsubst < kubernetes-config/locust-master-controller.yaml.tpl | kubectl apply -f -
envsubst < kubernetes-config/locust-master-service.yaml.tpl | kubectl apply -f -
#change the replica of the workloads in here
envsubst < kubernetes-config/locust-worker-controller.yaml.tpl | kubectl apply -f -

kubectl get pods -o wide
priyambodo-macbookpro1:distributed-load-testing-using-kubernetes priyambodo$ kubectl get pods -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP          NODE                                                  NOMINATED NODE   READINESS GATES
locust-master-b7f775696-w79g4    1/1     Running   0          113s   10.20.2.4   gke-autopilot-locust-str-default-pool-c6f392e1-c8q7   <none>           <none>
locust-worker-78579bd547-5rm5g   1/1     Running   0          94s    10.20.8.4   gke-autopilot-locust-str-default-pool-e406c5c9-65gg   <none>           <none>
locust-worker-78579bd547-gl2ps   1/1     Running   0          94s    10.20.4.3   gke-autopilot-locust-str-default-pool-186b55b6-2ltw   <none>           <none>
locust-worker-78579bd547-plwvl   1/1     Running   0          94s    10.20.0.4   gke-autopilot-locust-str-default-pool-c6f392e1-7bnn   <none>           <none>
locust-worker-78579bd547-sc4rf   1/1     Running   0          94s    10.20.7.4   gke-autopilot-locust-str-default-pool-e406c5c9-lv3q   <none>           <none>
locust-worker-78579bd547-vkxn9   1/1     Running   0          94s    10.20.3.4   gke-autopilot-locust-str-default-pool-186b55b6-z1zj   <none>           <none>

kubectl get services
priyambodo-macbookpro1:distributed-load-testing-using-kubernetes priyambodo$ kubectl get services
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
kubernetes          ClusterIP      10.27.112.1     <none>        443/TCP             8m8s
locust-master       ClusterIP      10.27.121.242   <none>        5557/TCP,5558/TCP   2m53s
locust-master-web   LoadBalancer   10.27.122.172   10.128.0.58   8089:30523/TCP      2m52s

kubectl get svc locust-master-web --watch


#Connect to Locust web front end

export INTERNAL_LB_IP=$(kubectl get svc locust-master-web  \
                               -o jsonpath="{.status.loadBalancer.ingress[0].ip}") && \
                               echo $INTERNAL_LB_IP

#Create a Tunnel Proxy using nginx, so you can browse through your Laptop
export PROXY_VM=locust-nginx-proxy
export NETWORK_NAME=vpc-default-by-doddipriyambodo
gcloud compute instances create-with-container ${PROXY_VM} \
   --zone ${ZONE} \
   --container-image gcr.io/cloud-marketplace/google/nginx1:latest \
   --container-mount-host-path=host-path=/tmp/server.conf,mount-path=/etc/nginx/conf.d/default.conf \
   --network ${NETWORK_NAME}  
   --metadata=startup-script="#! /bin/bash
     cat <<EOF  > /tmp/server.conf
     server {
         listen 8089;
         location / {
             proxy_pass http://${INTERNAL_LB_IP}:8089;
         }
     }
EOF"
gcloud compute ssh --zone ${ZONE} ${PROXY_VM} -- -N -L 8089:localhost:8089
gcloud compute instances delete ${PROXY_VM} --zone ${ZONE}

# Run a basic load test on your sample application
https://localhost:8089

# Scale Up the Pod
kubectl scale deployment/locust-worker --replicas=20

#Delete the Cluster
gcloud container clusters delete ${GKE_CLUSTER} --region ${REGION}

#Check the Pods & Services
kubectl get pods -o wide
kubectl get services
