# ===========================================================
#GitHub Actions CI/CD Pipeline: Deploy Nest App to AWS ECS
# ===========================================================
# This workflow automates:
#   1. Provisioning AWS infrastructure with Terraform
#   2. Building, scanning, and pushing a Docker image to 
#   3. Creating a new ECS task definition revision
#   4. Restarting the ECS Fargate service
#   5. Testing application health
#   6. Monitoring the deployment
#   7. Rolling back on failure
#   8. Sending Slack notifications
# ==========================================================

name: Deploy Nest App to AWS ECS

# ==========================================================
# TRIGGER: When should this workflow run?
# ==========================================================
on:
  push:
    branches:
      - main
    paths:
      - '.github/workflows/nest-app.yml
      - 'docker/nest-app/***
      - 'terraform-modules/nest-app/***

# ==========================================================
# ENVIRONMENT VARIABLES: Shared across all jobs
# ==========================================================
env:
AWS_ACCESS_KEY_ID: ${{ secrets. AWS_ACCESS_KEY_ID }} AWS_SECRET_ACCESS_KEY: ${{ secrets. AWS_SECRET_ACCESS_KEY}}
AWS REGION: us-east-1
AWS_ACCOUNT_ID: "651783246143"
TERRAFORM ACTION: apply PROJECT_NAME: nest
ENVIRONMENT: dev
RECORD_NAME: www
DOMAIN NAME: aosnotes 77.com
GITHUB USERNAME: azeez-aos
REPOSITORY_NAME: nest-app-code
SERVICE PROVIDER_FILE_NAME: AppServiceProvider APPLICATION_CODE_FILE_NAME: nest
RDS_DB_NAME: applicationdb
RDS_DB_USERNAME: admin
IMAGE_NAME: nest
IMAGE TAG: latest

jobs:
# ==========================================================
# JOB 1: Build AWS Infrastructure
# ==========================================================
deploy_aws_infrastructure:
  name: Build AWS infrastructure 
  runs-on: ubuntu-latest
  steps:
   - name: Checkout repository
     uses: actions/checkout@v4

   - name: Configure SSH access for Terraform modules 
     run: |
       mkdir -p /.ssh
       echo "${{secrets. SSH_PRIVATE KEY }}">~/.ssh/id_ed25 chmod 600/.ssh/id_ed25519
       ssh-keyscan github.com >> ~/.ssh/krown_hosts

   - name: Set up Terraform
     uses: hashicorp/setup-terraform@v3
     with:
       terraform_version: latest

   - name: Run Terraform init
     working-directory: ./terraform-modules/nest-app
     run: terraform init

   - name: Run Terraform plan
     working-directory: ./terraform-modules/nest-app 
     run: terraform plan -no-color

   - name: Run Terraform apply/destroy
     working-directory: ./terraform-modules/nest-app 
     run: terraform ${TERRAFORM_ACTION} -auto-approve
   
   - name: Export Terraform outputs
     if: env.TERRAFORM ACTION 'apply'
     working-directory:. /terraform-modules/nest-app
     run: |
       echo "DOMAIN NAME=$(terraform output -raw domain_name | cut -d-f1)" >> $GITHUB ENV 
       echo "RDS ENDPOINT=$(terraform output -raw rds_endpoint | cut -d ':' -f1)" >> $GITHUB_ENV
       echo "ECS TASK_DEFINITION_NAME-$(terraform output raw ecs_task_definition_name | cut -d-fl)" 
       echo "ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name | cut -d ''-F1)" >> $GITHUB_ENV 
       echo "ECS_SERVICE_NAME=$(terraform output raw ecs_service_name | cut -df1)" >> $GITHUB ENV
  outputs:
terraform_action: ${{ env. TERRAFORM_ACTION }}
domain_name: ${{ env.DOMAIN_NAME}}
rds_endpoint: ${{ env.RDS ENDPOINT }}
task_definition_name: ${{ env.ECS_TASK_DEFINITION_NAME}} ecs_cluster_name: ${{ env. ECS_CLUSTER_NAME}} ecs_service_name: ${{ env.ECS_SERVICE_NAME}}

# ==========================================================
# JOB 2: Build, Scan, and Push Docker Image to ECR
# ==========================================================
build_and_push_image:
  name: Build, scan, and push Docker image to ECR
  needs: deploy_aws_infrastructure
  if: needs.deploy_aws_infrastructure.outputs.terraform_action = 'destroy' 
  runs-on: ubuntu-latest
  steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Checkout make script executable 
      working-directory: ./docker/nest-app
      run: chmod +x build-image.sh push-image.sh

    - name: Build Docker image
      working-directory: ./docker/nest-app
      env:
        DOMAIN NAME: ${{ needs.deploy_aws_infrastructure.outputs.domain_name}} 
        RDS ENDPOINT: ${{ needs.deploy_aws_infrastructure.outputs.rds_endpoint}} 
        RDS_DB_PASSWORD: ${{ secrets. RDS_DB_PASSWORD }}
        PERSONAL_ACCESS_TOKEN: ${{ secrets. PERSONAL_ACCESS_TOKEN }}
      run: bash ./build-image.sh

    - name: Scan Docker image for vulnerabilities
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.IMAGE_NAME}}:${{ env.IMAGE_TAG}} severity: CRITICAL, HIGH
        exit-code: ${{ env.ENVIRONMENT == 'prod' && '1' || '@' }}
        format: json
        output: trivy-report.json

    - name: Generate vulnerability summary
      run: |
        CRITICAL-$(ja '[.Results[]?.Vulnerabilities[]? | select(.Severity--"CRITICAL")] | length' trivy-report.json) HIGH=$(jq [Results[]?.Vulnerabilities[]? | select(„Severity=="HIGH")] | length: trivy-report.json) 70
        HIGH-$(ja '[.Results[]?.Vulnerabilities[]? | select(.Severity--"CRITICAL")] | length' trivy-report.json) 
        TOTAL=$((CRITICAL + HIGH))

        if [ "$TOTAL" -eq 0 ]; then
        SUMMARY="   No vulnerabilities found"
        else
          SUMMARY=" $(TOTAL) vulnerabilities found ($(CRITICAL) Critical, ${HIGH) High)"
        fi

       echo "SCAN SUMMARY $SUMMARY" >> $GITHUB_ENV
       echo "$SUMMARY"

     name: Push Docker image to ECR 
     working-directory: ./docker/nest-app 
     run: bash ./push-image.sh

  outputs:
  scan_summary: ${{ env.SCAN_SUMMARY }}

# ==========================================================
# JOB 3: Create New Task Definition Revision
# ==========================================================
create_task_definition_revision:
  name: Create new task definition revision
  needs:
    - deploy_aws_infrastructure
    - build_and_push_image
  if: needs.deploy_aws_infrastructure.outputs.terraform_action != 'destroy'
  runs-on: ubuntu-latest
  steps:
    - name: Get current task definition revision
      env:
        ECS_FAMILY: ${{ needs.deploy_aws_infrastructure.outputs.task_definition_name}} 
      run: |
       CURRENT_REVISION-$(aws ecs describe-task-definition --task-definition "${ECS_FAMILY}" \ 
         --query 'taskDefinition.revision' --output text)
       echo "CURRENT_TASK_DEFINITION_REVISION=$CURRENT_REVISION" >> $GITHUB_ENV
    - name: Create new task definition revision
      env:
        ECS_FAMILY: ${{ needs.deploy_aws_infrastructure.outputs.task_definition_name }}
        ECS_IMAGE: ${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS REGION }).amazonaws.com/${{ env.IMAGE_NAME}}:${{ env.IN 
      run: |
        TASK DEFINITION=$(aws ecs describe-task-definition --task-definition "${ECS_FAMILY}")

        NEW TASK_DEFINITION=$(echo "$TASK_DEFINITION" | ja -arg IMAGE "${ECS_IMAGE}" \
          '.taskDefinition | .containerDefinitions[0].image = $IMAGE
          del(.taskDefinitionArn, .revision, status, .requiresAttributes, .compatibilities, registeredAt, .registeredBy 

        NEW_TASK_DEFINITION_REVISION=$(aws ecs register-task-definition --cli-input-json "$NEW TASK_DEFINITION" | ja tal
        echo "NEW_TASK_DEFINITION_REVISION=$NEW_TASK_DEFINITION_REVISION" >> $GITHUB_ENV

outputs:
  new_task_definition_revision: ${{ env.NEW_TASK_DEFINITION_REVISION }}
  current_task_definition_revision: ${{ env. CURRENT TASK_DEFINITION_REVISION }}

#==========================================================
#JOB 4: Restart ECS Fargate Service
#==========================================================
restart_ecs_service:
  name: Restart ECS Fargate service
  needs:
    - deploy_aws_infrastructure
    - create_task_definition_revision
  if: needs.deploy_aws_infrastructure.outputs.terraform_action = 'destroy'

if: needs.deploy_aws_infrastructure.outputs.terraform_action != 'destroy' runs-on: ubuntu-latest
steps:
name: Restart ECS service
env:
ECS_CLUSTER_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_cluster_name }} ECS_SERVICE_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_service_name}} TASK_DEFINITION_NAME: ${{ needs.deploy_aws_infrastructure.outputs.task_definition_name}} TASK_DEFINITION_REVISION: ${{ needs.create_task_definition_revision.outputs.new_task_definition_revision }}
run: |
aws ecs update-service cluster "${ECS_CLUSTER_NAME}" --service "${ECS_SERVICE_NAME}" \ --task-definition "$(TASK_DEFINITION_NAME}:${TASK_DEFINITION_REVISION)" --force-new-deployment
aws ecs wait services-stable cluster "${ECS_CLUSTER_NAME}" --services "${ECS_SERVICE_NAME}"

#
# JOB 5: Test Application Health
#--
test_application:
name: Test application health needs:
- deploy_aws_infrastructure
- restart_ecs_service

if: needs.deploy_aws_infrastructure.outputs.terraform_action != 'destroy' runs on: ubuntu-latest
steps:
name: Wait for service to stabilize
run: sleep 30
- name: Check application health
env:
DOMAIN NAME: ${{ needs.deploy_aws_infrastructure.outputs.domain_name}} run: |
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://www.${DOMAIN_NAME} echo "HTTP Status: $RESPONSE"
if [ "$RESPONSE" -eq 200 ]; then
echo "Application is healthy"
else
fi
echo "Application health check failed"
exit 1

#
# JOB 6: Monitor ECS Deployment
#
monitor_deployment:
name: Monitor ECS deployment
needs:
- deploy_aws_infrastructure
- restart_ecs_service
if: needs.deploy_aws_infrastructure.outputs.terraform_action != 'destroy'


if: needs.deploy_aws_infrastructure.outputs.terraform_action != 'destroy' runs-on: ubuntu-latest
steps:
- name: Check ECS running tasks
env:
ECS_CLUSTER_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_cluster_name }} ECS_SERVICE_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_service_name }}
run: [
RUNNING COUNT=$(aws ecs describe-services \
--cluster "${ECS_CLUSTER_NAME}" \
--services "${ECS_SERVICE_NAME}" \
--query "service[0].runningCount" \ --output text)
DESIRED COUNT=$(aws ecs describe-services \
--cluster "${ECS_CLUSTER_NAME}" \
--services "${ECS_SERVICE_NAME}" \
--query "service[0].desiredCount" \
--output text)
echo "Running tasks: $RUNNING COUNT / Desired tasks: $DESIRED_COUNT"
if [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ]; then
echo "All tasks are running successfully"
else
echo "Task count mismatch - deployment may have issues" exit 1
fi

#
# JOB 7: Rollback on Failure
# 
rollback:
name: Rollback to previous version
needs:
deploy_aws_infrastructure
create_task_definition_revision
- restart_ecs_service
-
test_application
- monitor_deployment
if: failure() && needs.deploy_aws_infrastructure.outputs.terraform_action = 'destroy' runs-on: ubuntu-latest
steps:
- name: Rollback ECS service to previous task definition
env:
ECS_CLUSTER_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_cluster_name }} ECS_SERVICE_NAME: ${{ needs.deploy_aws_infrastructure.outputs.ecs_service_name }}
TASK_DEFINITION_NAME: ${{ needs.deploy_aws_infrastructure.outputs.task_definition_name}} PREVIOUS_REVISION: ${{ needs.create_task_definition_revision.outputs.current_task_definition_revision }}
run: |
echo "Rolling back to task definition revision: $PREVIOUS_REVISION"
aws ecs update-service --cluster "${ECS_CLUSTER_NAME}" --service "${ECS_SERVICE_NAME}" \ --task-definition "${TASK_DEFINITION_NAME}:${PREVIOUS_REVISION}" -force-new-deployment
aws ecs wait services-stable --cluster "${ECS_CLUSTER_NAME}" --services "${ECS_SERVICE_NAME}" echo "Rollback complete"

# 
#JOB 8: Send Notification
# 
notify:
name: Send notification
needs:
deploy_aws_infrastructure
- build_and_push_image
-
-
-
create_task_definition_revision
restart_ecs_service
test_application
- monitor_deployment
if: always() &&
runs-on: <RUNNER_OS>
steps:
- name: Send Slack notification
uses: <SLACK_ACTION>
with:
webhook: $ secrets. <SLACK_WEBHOOK_SECRET_NAME> }}
webhook-type: <WEBHOOK_TYPE>
payload: |
{
"text": "${{ needs.test_application.result == 'success' && needs.monitor_deployment.result == 'success' && "blocks": [
{
"type": "header",
"text": {
"type": "plain_text",
"text": "${{ needs.test_application.result == 'success' && needs.monitor_deployment.result == 'success


"text": {
"type": "plain_text",
Aa ab 20 of 20
"text": "${{ needs.test_application.result == 'success' && needs.monitor_deployment.result == 'success' &&
Deplo
"type": "section",
"fields":[
{ "type": "mrkdwn", "text": "*Project:*\n${{ env.PROJECT_NAME}}" },
{ "type": "mrkdwn", "text": "*Environment:"\n${{ env.ENVIRONMENT }}" },
{ "type": "mrkdwn", "text": "*Image:*\n${{ env.IMAGE_NAME}}:${{ env.IMAGE_TAG}}" },
{ "type": "mrkdwn", "text": "*Triggered by:*\n${{ github.actor }}" }
"type": "section",
"text": {
"type": "arkdwn",
"text": "*Security Scan:* \n${{ needs.build_and_push_image.outputs.scan_summary || 'Scan not available' }}"
"type": "section",
"text": {
"type": "mrkdwn",
"text": "*Pipeline:* <${{ github.server_url}}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Run"
