# Introduction

This is a sample dot net application rendering welcome webpage.

## Local Development steps

There are couple of pre-requisites before you can run the application locally.

- Install and run docker daemon (Required version - **19.03.8**, build **afacb8b**)
- Install docker compose (Required version - **1.25.5**, build **8a1c60f6**)

### Steps

- Make sure you are in **myWebApp** directory.
- Run following command to build and run the application once you are done making changes to your application

```bash
> docker-compose up -d --build
```

- To check if the service started succesfully, run following command and check the output for any errors.

```bash
> docker logs devops-test-app
```

- If there are no errors, the application will be accesible on `https://localhost:8088`

## Deployment Strategy

Our deployment strategy is :

- Create the basic infrastructure required for terraform using cloudformation.
  - A dynamoDB table to provide ability to restrict one change at a time.
  - S3 bucket to keep the terraform state file at a shared location and secured through versioning.
  - ECR to push our dotnet docker images.
- Run terarform to build the infrastructure as well as deploy the new image everytime code changes. Terraform creates following resources :
  - A VPC with two public and two private subnets along with NAT and internet gateway.
  - An AWS elastic container service (ECS) cluster
  - An application load balancer
  - A target group pointing to deployed dotnet service in ECS cluster
  - Two security groups - one for load balancer and one for dotnet service.

## Deployment Instructions

Follow below steps :

- Setup github repository to use github actions
  - Go to repositories's settings.
  - Select "Secrets" from left hand pane.
  - Add AWS access key and secret key by adding values to variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- Make a change and validate that github actions are trigerred.
  - Github workflow should be triggered when a commit is pushed to master or when a pull request is created.
