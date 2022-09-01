#!/bin/sh

#######################################################
# One click to deployment 
#######################################################

# Gitlab API Documentation https://docs.gitlab.com/ee/api/api_resources.html
## $1 : project name
## $2 : branch name
## $3 : port

export GITLAB_SERVER=https://gitlab.haas-495.pez.vmware.com
export GITLAB_TOKEN=YxGB-DNsy_YsUKwL6J7u
export JENKINS_SERVER=http://100.96.3.47:8080
export SEEDS_JOB_URL=https://gitlab.haas-495.pez.vmware.com/jeffrey/seed-dsl.git
export HELM_TEMPLATE_URL=https://gitlab.haas-495.pez.vmware.com/jeffrey/helm-template.git
export APP_PORT=$3


export JENKINS_URL=https://jenkins.haas-495.pez.vmware.com/
export JENKINS_CRET=jeffrey:11b039a0a0fa2121027095dd791531166d

function getNextBuildNr(){
  curl --silent --user $JENKINS_CRET -X GET -L $JENKINS_URL/job/$1/api/json | grep -o '"nextBuildNumber":\s*[0-9]*' | cut -d ":" -f 2
}

function getBuildState(){
  curl --silent --user $JENKINS_CRET -X GET -L $JENKINS_URL/job/$1/$2/api/json | grep -o '"result":\s*"[a-zA-Z]*"'
}

function waitForJob() {
  buildNr=$2
  jobname=$1
  state=""
  loopi=0

  while [[ "X${state}" == "X" && ${loopi} -lt 150 ]]
  do
     sleep 2
     state=$(getBuildState ${jobname} ${buildNr})
     let loopi++
     echo  ".\c"

  done
  echo ".\n"
  echo ${state} | grep -i "SUCCESS"
  return $?
}

project_info=""
repo_ssh_url=""
repo_http_url=""
new_project=1
jsonResult=$(curl -sS "$GITLAB_SERVER/api/v4/search?scope=projects&search=$1" -H "PRIVATE-TOKEN: $GITLAB_TOKEN")
firstId=$(echo $jsonResult | jq '.[0]["id"]')
projectId=-1

if [ $firstId != "null" ]
then
  loopi=$(echo $jsonResult | jq length)
  for ((ind=0; ind<$loopi; ind++)) 
  do
    prj_name=$(echo $jsonResult | jq -r ".[$ind].name")
    if [ $prj_name == $1 ]
    then
      project_info=$(echo $jsonResult | jq -r ".[$ind]")
      echo "Project existed!!"
      new_project=0
      #echo $project_info | jq .
      ######todo: if project existed, just push the source code to repo.    
      break
    fi
  done 
fi

echo "********************"
###Step 1
#####Create project in gitlab if needed
echo "Step 1: create project in gitlab..."
if [[ "X$project_info" == "X" || $firstId == "null" ]]
then
  project_info=$(curl -sS -d "name=$1&visibility=private" -X POST "$GITLAB_SERVER/api/v4/projects" -H "PRIVATE-TOKEN: $GITLAB_TOKEN")
fi

repo_ssh_url=$(echo $project_info | jq -r '.ssh_url_to_repo')
repo_http_url=$(echo $project_info | jq -r '.http_url_to_repo')
projectId=$(echo $project_info | jq -r '.id')
echo "Step 1 completed!"
echo "Project id $projectId"
echo "Project ssh url $repo_ssh_url"
echo "Project http rul $repo_http_url"

echo "********************"
###Step 2
###Create gitlab webhook
echo "Step 2: create gitlab webhook..."
if [ $new_project -eq 1 ]
then
  token_url="$JENKINS_SERVER/project/$1"
  curl -sS -w %{http_code} \
       -d "url=$token_url&push_events=true&merge_requests_events=true&token=$GITLAB_TOKEN" \
       -X POST "$GITLAB_SERVER/api/v4/projects/$projectId/hooks" \
       -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | grep "20[0-9]"
  if [ $? -ne 0 ]
  then
    echo "Creating webhook for project $1 failed, exited"
    exit 1
  fi
fi
echo "Step 2 completed!"

echo "********************"
###Step 3
####Create jenkins pipeline if needed
echo "Step 3 create jenkins pipeline..."
current_dir=$(pwd)
cd /tmp
rm -fR cicd
mkdir cicd
cd cicd
git clone $SEEDS_JOB_URL
cd `ls`
sed -i -e "s/^branchs_name.*/branchs_name = \"$2\"/" seeds.groovy
sed -i -e "s/^cur_job_name.*/cur_job_name = \"$1\"/" seeds.groovy
sed -i -e "s/^secret_token.*/secret_token = \"$GITLAB_TOKEN\"/" seeds.groovy
sed -i -e '1 s/^.*/\/\/'"$(date)"'/' seeds.groovy
git add seeds.groovy
git commit -m "create job job-$1"
git push -u origin master

echo "Step 3 completed!"

echo "********************"
###Step 4
####Create helm charts
echo "Step 4 create helm charts..."
###still in tmp directory
cd ..
#helm create $1-gitops
rm -fR $1-gitops
mkdir $1-gitops
cd $1-gitops
echo "Step 4: create heml chart in gitlab..."
project_info=$(curl -sS -d "name=$1-gitops&visibility=private" -X POST "$GITLAB_SERVER/api/v4/projects" -H "PRIVATE-TOKEN: $GITLAB_TOKEN")

helm_repo_ssh_url=$(echo $project_info | jq -r '.ssh_url_to_repo')
helm_repo_http_url=$(echo $project_info | jq -r '.http_url_to_repo')
helm_projectId=$(echo $project_info | jq -r '.id')
echo "Creating helm repo completed"
echo "Helm project id $helm_projectId"
echo "Helm project ssh url $helm_repo_ssh_url"
echo "Helm project http rul $helm_repo_http_url"

git clone $HELM_TEMPLATE_URL
cd `ls`
grep -rli 'testtbs' * | xargs -I@ sed -i -e 's/testtbs/'"$1"'/g' @
yq e '.service.port = env(APP_PORT)' -i values.yaml
git remote set-url origin $helm_repo_http_url
grep -rli "$1" * | xargs -I{} git add {}
#git add .
git commit -m "Initial commit"
git push -u origin master
echo "Step 4 completed!"

echo "*****************"
###Step 5
###Push code and monitor jenkins job state
echo "Step 5: push code and monitor jenkins job state..."
cd ${current_dir}
buildnumber=$(getNextBuildNr $1)
git init .
git remote add origin $repo_http_url
git add .
git commit -m "Init commit"
git push -u origin master

waitForJob $1 ${buildnumber}
ret=$?
if [ ${ret} != 0 ]
then
  echo "Jenkins job timeout or failed"
  kp image delete $1
  curl --request DELETE --header "PRIVATE-TOKEN: YxGB-DNsy_YsUKwL6J7u" "$GITLAB_SERVER/api/v4/projects/${projectId}"
  curl --request DELETE --header "PRIVATE-TOKEN: YxGB-DNsy_YsUKwL6J7u" "$GITLAB_SERVER/api/v4/projects/${helm_projectId}"
  rm -fR .git
  exit 1
fi
echo "Step 5 completed!!"


echo "*****************"
###Step 6
###
echo "Step 6: Create argoCD add..."
####create repository
argocd repo add $helm_repo_http_url \
  --type git \
  --username $GITLAB_USERNAME \
  --password $GITLAB_PASSWORD

####Create an app
argocd app create $1 \
  --repo $helm_repo_http_url \
  --path . \
  --dest-namespace testing \
  --dest-server https://kubernetes.default.svc \
  --project default \
  --revision master \
  --sync-policy automated
exit 0


