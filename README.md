# Fake Business AWS Infrastructure

This repository houses the Terraform infrastructure code for all of the operating environments for fakebusiness services. All of the included resources are [listed below](#resources).

<p align="center">
<img width="800" height="1600" src="docs/Fake_Business.svg"><br>
</p>


Under the hood in AWS, fakebusiness leverages the following:
* AWS Elastic Container Service for Web and Worker container hosting.
* AWS Application Load Balancer for managing web connections.
* AWS Relational Database Service for the PostGres db.
* AWS S3 bucket for storing attachments.
* S3 Bucket and Cloudfront for the React application.
* MSK Serverless for Managed Kafka
* Event-driven lambdas for s3 bucket events
* Twingate VPN

## NextJS Application 
Uses Terraform for management of non-ecs resources, like the RDS PostGres database, as well as all of the networking and cluster configuration. Everything else ECS-centric is managed using [ECS Deployer](https://ecsdeployer.com/). ECS Deployer allows us to host multiple environments and multiple ECS services, as well as some other niceties, in a single config set. ECS Deployer configuration files can be found in the `.ecsdeployer/` directory in the fakebusiness Web App repo. 

We can also leverage the companion [Remote Shell Client](https://github.com/webdestroya/remote-shell-client), which allows you to create a session in any Operating Environment without disturbing the existing services. This method is great for spelunking and investigating issues in non-local AWS environments, as you have the exact same configs and settings as the actual running application.

## Marketing 
The Fake Business Client is hosted inside of a S3+Cloudfront+WAF Holy Trinity. The S3 bucket houses the live build in a directory called `current`. The site files inside of `current` directory represent what is served to the client when they hit a naked domain like app.fakebusiness.com. Outside of that, there will be additional directories in the bucket meant to represent past builds, used for comparison in QA efforts. Previous versions and `sha`s are available in a given environment at `<sha>.site.dev.fakebusiness.com` or `<version>.site.staging.fakebusiness.com`. In addition to serving the S3 bucket content on the global distribution network, the Cloudfront also houses a lambda function that provides the dynamic routing described above. The source code for this lambda lives in this repo under the `/functions` directory.

If addition to the standard S3 Cloudfront combo, I implemented a global Web Access Firewall on the Cloudfront distro. This WAF is meant to block international traffic, and provide a strict IP Whitelisting experiencing for pre-production environments. Updates to the WAF should be made with great caution. The Whitelist IP addresses are housed in the `variables.tf` file, and currently only include the public IP address of the AWS VPN.

## ECS Application
The fakebusiness-API uses Terraform for management of non-ecs resources, like the RDS PostGres database, as well as all of the networking and cluster configuration. Everything else ECS-centric is managed using [ECS Deployer](https://ecsdeployer.com/). ECS Deployer allows us to host multiple environments and multiple ECS services, as well as some other niceties, in a single config set. ECS Deployer configuration files can be found in the `.ecsdeployer/` directory in the fakebusiness API repo. 

We can also leverage the companion [Remote Shell Client](https://github.com/webdestroya/remote-shell-client), which allows you to create a session in any Operating Environment without disturbing the existing services. This method is great for spelunking and investigating issues in non-local AWS environments, as you have the exact same configs and settings as the actual running application.

## Cognito
Currently, fakebusiness uses AWS Cognito as a User Service. While this service is configured inside of this Terraform file, there are limitations imposed by AWS that limit the effectiveness of Terraform to manage user pools. Please, use caution when editing the configuration for the Cognito, as most changes will require a destorying of some element to recreate.

## Operating Environments
These operating environments are managed in the Terraform Workspaces.

|Name|App|API|
|---|---|---|
| dev | [app.dev.fakebusiness.com](https://app.dev.fakebusiness.com) | [api.dev.fakebusiness.com](https://app.dev.fakebusiness.com) |
| staging | [app.staging.fakebusiness.com](https://app.staging.fakebusiness.com) | [api.staging.fakebusiness.com](https://app.staging.fakebusiness.com) |
| prod | [app.fakebusiness.com](https://app.fakebusiness.com) | [api.fakebusiness.com](https://app.fakebusiness.com) |

## Connecting to AWS Console UI
Easy, peesy. Log in at [https://fakebusiness.awsapps.com/start](https://fakebusiness.awsapps.com/start) and select the account you want to access. 

## Connecting to AWS via AWSCLI or other command-line tools
This one requires a little setup. Follow this : 
1. install the `awscli` with `brew install awscli`. 
2. Setup your ~/.aws/config with profiles that look like this
  note: you _may_ not have `AdministratorAccess`, in which case, make more important friends.
```bash
; Fake Business
[profile fakebusiness-production]
sso_start_url = https://fakebusiness.awsapps.com/start 
sso_region = us-east-1
sso_account_id = 767398123958
sso_role_name = AdministratorAccess
region = us-east-1
output = json

[profile fakebusiness-staging]
sso_start_url = https://fakebusiness.awsapps.com/start 
sso_region = us-east-1
sso_account_id = 730335234660
sso_role_name = AdministratorAccess
region = us-east-1
output = json

[profile fakebusiness-dev]
sso_start_url = https://fakebusiness.awsapps.com/start 
sso_region = us-east-1
sso_account_id = 891377140782
sso_role_name = AdministratorAccess
region = us-east-1
output = json
```
3. next, going to add a snippet to our `~/.zshrc` file that will make it buttery smooth to login with SSO.
```
function aws-login {
  profile="$1";
  if [ -z "$profile" ]; then
    echo "Profile is required as first argument.";
    return
  fi   

  echo "Using SSO account"
  aws sso login --profile "$profile";
  eval "$(aws configure export-credentials --profile "$profile" --format env)";
  export AWS_PROFILE=$profile;
  echo "AWS_PROFILE set to $profile"
}
```

## Using MSK Kafka Locally
1. Install `kafka` with `brew` `brew install kafka wget`
2. Download the IAM MSK Auth magic
```
cd /opt/homebrew/opt/kafka/libexec/libs
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar
```
3. add the `client.properties` file to wherever you are going to run your commands from. I keep it right here.
4. Connect to the VPN
5. Auth to AWS using `aws-login`
6. run kafka commands referencing the config. Here is an example. Notice the bootstrap server is per env : 
```
kafka-topics --bootstrap-server boot-s1wuzf1s.c2.kafka-serverless.us-east-1.amazonaws.com:9098 --command-config client.properties --create --topic  files --partitions 2
```





Now, when you want to log in to an AWS account, use `aws-login <profile-name>` aka `aws-login fakebusiness-dev`. Website will ask you to verify and sign-in. 

## CI/CD Flow
1. New branch from `main`, ideally named from Github Issue like `#20/Do-the-thing` or with ownership like `Username/#20`
2. Make changes, creating a *draft* Pull Request for easy collaboration without triggering any Github Deployment Actions.
3. When you are ready to party, undraft. Automated workflows including testing, linting and validations will run and complete (hopefully).
4. Github Actions will deploy a temporary environment for your Pull Request. Subsequent updates to the Pull Request will be deployed to this infrastructure. That Github Action lives [here](.github/workflows/pull_request.yml).
5. After reviewing the code changes and the preview URL as needed, approve the code, and merge the Pull Request to `main`. 
6. With the merge to `main` branch, the [**dev**](https://app.dev.fakebusiness.com) environment is updated. That Github Workflow lives [here](.github/workflows/main_merge.yml).
7. Whatever the reason, you create a new **Release** in Github with proper [semantic versioning](https://semver.org/),  and mark it as a `prerelease`. This deploys the [**staging**](https://staging.chainlink.deepseas.dev) environment.
8. QA efforts prove uneventful. Perfect. Sounds like Production o'clock. In Github, edit the release and uncheck the `prerelease` box and *Save*.
9. Apply sunscreen, unfold beach chair, and bask in orange glow of a new feature making it all the way to [**production**](https://chainlink.deepseas.dev)

## Secrets and Configurations
This application leverages a few ways to manage configurations and secrets.

- **Github Project Secrets** - There are three secret values that are only used in the CI pipelines in github. They include AWS Credentials and a Slack Webhook URL. Use Github Secrets for all sensitive values. They are easy to inject into the CI pipelines using the `${{ secrets.WHATEVER_THE_SECRET_KEY_IS }}`
- **SSM** - The ECS Task Definitions use SSM to pass the Database URL and S3 application bucket from the Terraform CI process.

### Changing Configs to AWS/Terraform
All of the default configurations for Terraform live in `variables.tf` in this repository. Changing these values may impact every environment on `apply`. In addition to the defaults, you can override specific env vars in the CI process in the various Github workflows. They are prefixed with `TF_VAR` so they are easy to distinguish. 

```
  - name: Terraform Apply
    id: apply
    env: 
      TF_WORKSPACE: staging
      TF_VAR_db_postgres_version: "15.3"
      TF_VAR_db_parameter_group: "default.postgres15"
      TF_VAR_db_instance_class: "db.t3.micro"
      TF_VAR_slack_webhook_url: ""
    run: terraform apply -no-color --auto-approve
    continue-on-error: false
``` 
### Adding Secrets to fakebusiness-Client
Secrets for the client are managed in the CI process, because they are needed at build time in each environment. Here is an example of environment variables at the Job level in Github Actions.
```
build:
  name: Build and Deploy Review Environment
  needs: test
  if: ${{ ! github.event.pull_request.draft }}
  runs-on: ubuntu-latest
  concurrency:
    group: ${{ github.ref }}-build
    cancel-in-progress: true
  permissions:
    contents: read
    pull-requests: write
    id-token: write
  env:
    REACT_APP_ALIX_GRAPHQL_API: "https://dev.api.fakebusiness.com/graphql" 
    REACT_APP_AWS_REGION: us-east-1
    REACT_APP_COGNITO_USERPOOL_ID: us-east-1_ngIaKZuB2
    REACT_APP_COGNITO_CLIENT_ID: 3h6ron68mkv94hd8bok2fno93j
    CI: false
    TSC_COMPILE_ON_ERROR: true
    ESLINT_NO_DEV_ERRORS: true
```

### Adding Secrets to fakebusiness-API
Secrets and environment variables are handled in the [ECS Deployer configurations](https://ecsdeployer.com/config/envvars/). They leverage both plain-text and SSM values.
```
environment:
  SOMEVARNAME: foobar
  APP_BUCKET:
    ssm: /fakebusiness/staging/APP_BUCKET
  DATABASE_URL:
    ssm: /fakebusiness/staging/DATABASE_URL
```


## Working with this Repo
Assuming you started with this template, here is what is recommended to do next: 

1. Install `pre-commit` with `pre-commit install`.
2. Update the information in the `provider.tf`. You will need to add the information about state, as well as default tags. To attain Terraform State bucket configurations, ask a DevOps Engineer, or create your own bucket.
3. Initiate the Terraform state with `terraform init`.
4. Start adding resources to `main.tf`, variables to `variables.tf`, Add relevant outputs to `outputs.tf` and so forth.
5. Plan your changes with `terraform plan`.
6. Commit your changes. The `pre-commit` process will lint your code for you as part of the commit process.


<!-- BEGIN_TF_DOCS -->
<p align="center">
<h1 align="center">Terraform Infrastructure Documentation</h1>
</p>

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones in the region | `map(string)` | <pre>{<br>  "us-east-1": "us-east-1a,us-east-1b,us-east-1c"<br>}</pre> | no |
| <a name="input_aws_accounts"></a> [aws\_accounts](#input\_aws\_accounts) | list of aws accounts | `list(string)` | <pre>[<br>  "767398123958",<br>  "730335234660",<br>  "891377140782"<br>]</pre> | no |
| <a name="input_conduktor_admin_password"></a> [conduktor\_admin\_password](#input\_conduktor\_admin\_password) | Admin password for Conduktor service | `string` | n/a | yes |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | Datadog API Key | `string` | n/a | yes |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | Size and Class for the RDS Postgres instance | `string` | `"db.t3.micro"` | no |
| <a name="input_db_password"></a> [db\_password](#input\_db\_password) | database password | `string` | n/a | yes |
| <a name="input_db_postgres_version"></a> [db\_postgres\_version](#input\_db\_postgres\_version) | Postgres database version | `string` | `"16.2"` | no |
| <a name="input_db_storage"></a> [db\_storage](#input\_db\_storage) | Postgres allocated storage | `number` | `20` | no |
| <a name="input_google_client_id"></a> [google\_client\_id](#input\_google\_client\_id) | Google Client ID for SSO Cognito App | `string` | n/a | yes |
| <a name="input_google_client_secret"></a> [google\_client\_secret](#input\_google\_client\_secret) | Google Client Secret for SSO Cognito App | `string` | n/a | yes |
| <a name="input_kafka_instance_class"></a> [kafka\_instance\_class](#input\_kafka\_instance\_class) | MSK Kafka instance class | `string` | `"kafka.t3.small"` | no |
| <a name="input_project"></a> [project](#input\_project) | Identifier for the project | `string` | `"fakebusiness"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region to deploy resources in | `string` | `"us-east-1"` | no |
| <a name="input_rudderstack_data_plane_url"></a> [rudderstack\_data\_plane\_url](#input\_rudderstack\_data\_plane\_url) | Rudderstack Data Plane URL | `string` | n/a | yes |
| <a name="input_rudderstack_write_key"></a> [rudderstack\_write\_key](#input\_rudderstack\_write\_key) | Rudderstack Write Key | `string` | n/a | yes |
| <a name="input_sentry_auth_token"></a> [sentry\_auth\_token](#input\_sentry\_auth\_token) | Sentry Auth Token | `string` | n/a | yes |
| <a name="input_slack_webhook"></a> [slack\_webhook](#input\_slack\_webhook) | Slack Webhook URL for Cloudwatch Alerts | `string` | `"https://hooks.slack.com/services/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"` | no |
| <a name="input_twingate_token"></a> [twingate\_token](#input\_twingate\_token) | Twingate Network Access Token | `string` | n/a | yes |
## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.ssl_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_budgets_budget.total](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_cloudfront_cache_policy.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_cache_policy.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_distribution.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.build_viewer_request](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_access_control.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_origin_access_control.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_origin_access_control.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_response_headers_policy.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_cloudfront_response_headers_policy.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_cloudwatch_log_group.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.ecs_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.kafka_data_logs_disk_used](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.msk_cpu_credit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.nat_gateway_usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_read_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_storage_space](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_write_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cognito_identity_provider.google](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_provider) | resource |
| [aws_cognito_user_pool.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [aws_db_instance.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ecr_repository.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.api_ecr_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [aws_ecr_repository_policy.app_ecr_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [aws_ecs_cluster.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_flow_log.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.slack_iam_for_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.api_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.app_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.conduktor_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ecs_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.readonly_role_policy_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.readonly_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_lambda_function.slack_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.with_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lb.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_msk_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster) | resource |
| [aws_msk_configuration.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_configuration) | resource |
| [aws_msk_configuration.main37](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_configuration) | resource |
| [aws_msk_configuration.production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_configuration) | resource |
| [aws_nat_gateway.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.primary_internet_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.primary_nat_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.amazonses_verification_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.conduktor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ses_domain_mail_from_mx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ses_domain_mail_from_txt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ssl_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.www](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table.primary_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.primary_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.assets_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.document_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.site_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_acl.assets_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_acl.document_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_acl.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_acl.site_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_cors_configuration.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_cors_configuration.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_cors_configuration.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.document_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.assets_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.document_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.site_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.assets_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.document_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.site_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.alb_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_public_443_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_public_80_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_sg_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_sg_http2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_sg_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_sg_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.lb_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.lb_ingress_cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.msk_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.msk_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.msk_local](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.msk_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.msk_vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_postgres_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_postgres_vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ses_domain_identity.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity) | resource |
| [aws_ses_domain_identity_verification.main_verification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity_verification) | resource |
| [aws_ses_domain_mail_from.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_mail_from) | resource |
| [aws_ses_identity_notification_topic.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_identity_notification_topic) | resource |
| [aws_ses_identity_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_identity_policy) | resource |
| [aws_ses_receipt_rule.store](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule) | resource |
| [aws_ses_receipt_rule_set.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule_set) | resource |
| [aws_sns_topic.cloudwatch_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.topic_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_ssm_parameter.cognito_client_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.cognito_user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.global](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.kafka_bootstrap_servers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.rudderstack_data_plane_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.rudderstack_write_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.sentry_auth_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.zookeeper_connect_string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_wafv2_ip_set.ip_whitelist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_web_acl.firewall](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [twingate_resource.api](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
| [twingate_resource.app](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
| [twingate_resource.conduktor](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
| [twingate_resource.kafka_broker](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
| [twingate_resource.site](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
| [twingate_resource.vpc](https://registry.terraform.io/providers/Twingate/twingate/latest/docs/resources/resource) | resource |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_cert_arn"></a> [acm\_cert\_arn](#output\_acm\_cert\_arn) | some description |
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | API URL |
| <a name="output_app_url"></a> [app\_url](#output\_app\_url) | Web App URL |
| <a name="output_assets_bucket_name"></a> [assets\_bucket\_name](#output\_assets\_bucket\_name) | Name of the assets bucket |
| <a name="output_assets_url"></a> [assets\_url](#output\_assets\_url) | Assets URL |
| <a name="output_bootstrap_brokers_iam"></a> [bootstrap\_brokers\_iam](#output\_bootstrap\_brokers\_iam) | TLS connection host:port pairs |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | ID of the Cognito Client |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito User Pool |
| <a name="output_conduktor_url"></a> [conduktor\_url](#output\_conduktor\_url) | Conduktor URL |
| <a name="output_database_url"></a> [database\_url](#output\_database\_url) | URL to the RDS postgres database |
| <a name="output_document_bucket_arn"></a> [document\_bucket\_arn](#output\_document\_bucket\_arn) | ARN of the document bucket |
| <a name="output_document_bucket_name"></a> [document\_bucket\_name](#output\_document\_bucket\_name) | Name of the document bucket |
| <a name="output_domain"></a> [domain](#output\_domain) | Domain for the project environment |
| <a name="output_email_bucket"></a> [email\_bucket](#output\_email\_bucket) | SES Email storage bucket ARN |
| <a name="output_email_bucket_name"></a> [email\_bucket\_name](#output\_email\_bucket\_name) | Name of the email bucket |
| <a name="output_github_oidc_role_arn"></a> [github\_oidc\_role\_arn](#output\_github\_oidc\_role\_arn) | Github OIDC Role ARN |
| <a name="output_kafka_arn"></a> [kafka\_arn](#output\_kafka\_arn) | ARN of the Serverless Managed Kafka |
| <a name="output_kafka_bootstrap_servers"></a> [kafka\_bootstrap\_servers](#output\_kafka\_bootstrap\_servers) | Bootstrap Servers of the Serverless Managed Kafka |
| <a name="output_nat_gateway_ip"></a> [nat\_gateway\_ip](#output\_nat\_gateway\_ip) | NAT Gateway IP address |
| <a name="output_route53_nameservers"></a> [route53\_nameservers](#output\_route53\_nameservers) | some description |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | some description |
| <a name="output_ses_arn"></a> [ses\_arn](#output\_ses\_arn) | ARN for the SES domain |
| <a name="output_site_bucket_name"></a> [site\_bucket\_name](#output\_site\_bucket\_name) | Name of the marketing site bucket |
| <a name="output_site_url"></a> [site\_url](#output\_site\_url) | Website URL |
| <a name="output_zookeeper_connect_string"></a> [zookeeper\_connect\_string](#output\_zookeeper\_connect\_string) | Kafka Zookeeper connection string |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.4.2 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.53.0 |
| <a name="provider_twingate"></a> [twingate](#provider\_twingate) | 3.0.4 |
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_twingate"></a> [twingate](#module\_twingate) | ./modules/twingate-connector | n/a |
<!-- END_TF_DOCS -->
## DEVELOPMENT
| Name | Description | Value | Sensitive |
|------|-------------|-------|:---------:|
| <a name="output_acm_cert_arn"></a> [acm\_cert\_arn](#output\_acm\_cert\_arn) | some description | `"arn:aws:acm:us-east-1:891377140782:certificate/c78aa62c-b775-4672-8c88-c39c84563b12"` | no |
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | API URL | `"https://api.dev.fakebusiness.com"` | no |
| <a name="output_app_bucket_name"></a> [app\_bucket\_name](#output\_app\_bucket\_name) | Name of the web app bucket | `"fakebusiness-app-dev"` | no |
| <a name="output_app_url"></a> [app\_url](#output\_app\_url) | API URL | `"https://app.dev.fakebusiness.com"` | no |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | ID of the Cognito Client | `"37bev9vimuakocf45d4mrdscus"` | no |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito User Pool | `"us-east-1_Lj117fjcj"` | no |
| <a name="output_database_url"></a> [database\_url](#output\_database\_url) | URL to the RDS postgres database | `"postgres://fakebusiness:PASSWORD@fakebusiness-dev.cfcess626hnv.us-east-1.rds.amazonaws.com:5432/fakebusiness"` | no |
| <a name="output_document_bucket_arn"></a> [document\_bucket\_arn](#output\_document\_bucket\_arn) | ARN of the document bucket | `"arn:aws:s3:::fakebusiness-documents-dev"` | no |
| <a name="output_document_bucket_name"></a> [document\_bucket\_name](#output\_document\_bucket\_name) | Name of the document bucket | `"fakebusiness-documents-dev"` | no |
| <a name="output_domain"></a> [domain](#output\_domain) | Domain for the project environment | `"dev.fakebusiness.com"` | no |
| <a name="output_github_oidc_role_arn"></a> [github\_oidc\_role\_arn](#output\_github\_oidc\_role\_arn) | Github OIDC Role ARN | `"arn:aws:iam::891377140782:role/fakebusiness-github-actions"` | no |
| <a name="output_kafka_arn"></a> [kafka\_arn](#output\_kafka\_arn) | ARN of the Serverless Managed Kafka | `"arn:aws:kafka:us-east-1:891377140782:cluster/fakebusiness-main-cluster/74e12fed-5943-4e44-8077-9518f13623a4-s2"` | no |
| <a name="output_kafka_bootstrap_servers"></a> [kafka\_bootstrap\_servers](#output\_kafka\_bootstrap\_servers) | Bootstrap Servers of the Serverless Managed Kafka | `"boot-8a2ogjqa.c2.kafka-serverless.us-east-1.amazonaws.com:9098"` | no |
| <a name="output_nat_gateway_ip"></a> [nat\_gateway\_ip](#output\_nat\_gateway\_ip) | NAT Gateway IP address | `"3.211.218.198"` | no |
| <a name="output_route53_nameservers"></a> [route53\_nameservers](#output\_route53\_nameservers) | some description | <pre>[<br>  "ns-1148.awsdns-15.org",<br>  "ns-1976.awsdns-55.co.uk",<br>  "ns-505.awsdns-63.com",<br>  "ns-876.awsdns-45.net"<br>]</pre> | no |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | some description | `"Z090713836UUDSL1B9HD2"` | no |
| <a name="output_secrets_arn"></a> [secrets\_arn](#output\_secrets\_arn) | Environment secrets ARN | `"arn:aws:secretsmanager:us-east-1:891377140782:secret:environment-6r5ylb"` | no |
| <a name="output_site_bucket_name"></a> [site\_bucket\_name](#output\_site\_bucket\_name) | Name of the marketing site bucket | `"fakebusiness-website-dev"` | no |
| <a name="output_site_url"></a> [site\_url](#output\_site\_url) | API URL | `"https://site.dev.fakebusiness.com"` | no |


## STAGING

| Name | Description | Value | Sensitive |
|------|-------------|-------|:---------:|
| <a name="output_acm_cert_arn"></a> [acm\_cert\_arn](#output\_acm\_cert\_arn) | some description | `"arn:aws:acm:us-east-1:730335234660:certificate/483de23f-a3f9-4970-9175-564366cea321"` | no |
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | API URL | `"https://api.staging.fakebusiness.com"` | no |
| <a name="output_app_bucket_name"></a> [app\_bucket\_name](#output\_app\_bucket\_name) | Name of the web app bucket | `"fakebusiness-app-staging"` | no |
| <a name="output_app_url"></a> [app\_url](#output\_app\_url) | API URL | `"https://app.staging.fakebusiness.com"` | no |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | ID of the Cognito Client | `"7j4ti4pd87o5sbushpo1f3re9h"` | no |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito User Pool | `"us-east-1_h9aygNjAA"` | no |
| <a name="output_database_url"></a> [database\_url](#output\_database\_url) | URL to the RDS postgres database | `"postgres://fakebusiness:PASSWORD@fakebusiness-staging.c90as0mekgcf.us-east-1.rds.amazonaws.com:5432/fakebusiness"` | no |
| <a name="output_document_bucket_arn"></a> [document\_bucket\_arn](#output\_document\_bucket\_arn) | ARN of the document bucket | `"arn:aws:s3:::fakebusiness-documents-staging"` | no |
| <a name="output_document_bucket_name"></a> [document\_bucket\_name](#output\_document\_bucket\_name) | Name of the document bucket | `"fakebusiness-documents-staging"` | no |
| <a name="output_domain"></a> [domain](#output\_domain) | Domain for the project environment | `"staging.fakebusiness.com"` | no |
| <a name="output_github_oidc_role_arn"></a> [github\_oidc\_role\_arn](#output\_github\_oidc\_role\_arn) | Github OIDC Role ARN | `"arn:aws:iam::730335234660:role/fakebusiness-github-actions"` | no |
| <a name="output_kafka_arn"></a> [kafka\_arn](#output\_kafka\_arn) | ARN of the Serverless Managed Kafka | `"arn:aws:kafka:us-east-1:730335234660:cluster/fakebusiness-main-cluster/af976502-e746-46ea-b95c-237dacf29841-s1"` | no |
| <a name="output_kafka_bootstrap_servers"></a> [kafka\_bootstrap\_servers](#output\_kafka\_bootstrap\_servers) | Bootstrap Servers of the Serverless Managed Kafka | `"boot-kxkgk87y.c1.kafka-serverless.us-east-1.amazonaws.com:9098"` | no |
| <a name="output_nat_gateway_ip"></a> [nat\_gateway\_ip](#output\_nat\_gateway\_ip) | NAT Gateway IP address | `"54.82.22.34"` | no |
| <a name="output_route53_nameservers"></a> [route53\_nameservers](#output\_route53\_nameservers) | some description | <pre>[<br>  "ns-1275.awsdns-31.org",<br>  "ns-1714.awsdns-22.co.uk",<br>  "ns-315.awsdns-39.com",<br>  "ns-679.awsdns-20.net"<br>]</pre> | no |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | some description | `"Z024952234IC03XF20G4E"` | no |
| <a name="output_secrets_arn"></a> [secrets\_arn](#output\_secrets\_arn) | Environment secrets ARN | `"arn:aws:secretsmanager:us-east-1:730335234660:secret:environment-O22usk"` | no |
| <a name="output_site_bucket_name"></a> [site\_bucket\_name](#output\_site\_bucket\_name) | Name of the marketing site bucket | `"fakebusiness-website-staging"` | no |
| <a name="output_site_url"></a> [site\_url](#output\_site\_url) | API URL | `"https://site.staging.fakebusiness.com"` | no |

## PRODUCTION

| Name | Description | Value | Sensitive |
|------|-------------|-------|:---------:|
| <a name="output_acm_cert_arn"></a> [acm\_cert\_arn](#output\_acm\_cert\_arn) | some description | `"arn:aws:acm:us-east-1:767398123958:certificate/35ebd919-d1d6-4e5a-b1ac-a5271e8f7893"` | no |
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | API URL | `"https://api.fakebusiness.com"` | no |
| <a name="output_app_bucket_name"></a> [app\_bucket\_name](#output\_app\_bucket\_name) | Name of the web app bucket | `"fakebusiness-app-production"` | no |
| <a name="output_app_url"></a> [app\_url](#output\_app\_url) | API URL | `"https://app.fakebusiness.com"` | no |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | ID of the Cognito Client | `"2eadc1pgk4vp5ajamjv81j1jqh"` | no |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito User Pool | `"us-east-1_tOrfZUGZP"` | no |
| <a name="output_database_url"></a> [database\_url](#output\_database\_url) | URL to the RDS postgres database | `"postgres://fakebusiness:PASSWORD@fakebusiness-production.cpe8q4q6esi0.us-east-1.rds.amazonaws.com:5432/fakebusiness"` | no |
| <a name="output_document_bucket_arn"></a> [document\_bucket\_arn](#output\_document\_bucket\_arn) | ARN of the document bucket | `"arn:aws:s3:::fakebusiness-documents-production"` | no |
| <a name="output_document_bucket_name"></a> [document\_bucket\_name](#output\_document\_bucket\_name) | Name of the document bucket | `"fakebusiness-documents-production"` | no |
| <a name="output_domain"></a> [domain](#output\_domain) | Domain for the project environment | `"fakebusiness.com"` | no |
| <a name="output_github_oidc_role_arn"></a> [github\_oidc\_role\_arn](#output\_github\_oidc\_role\_arn) | Github OIDC Role ARN | `"arn:aws:iam::767398123958:role/fakebusiness-github-actions"` | no |
| <a name="output_kafka_arn"></a> [kafka\_arn](#output\_kafka\_arn) | ARN of the Serverless Managed Kafka | `"arn:aws:kafka:us-east-1:767398123958:cluster/fakebusiness-main-cluster/81e9a238-d229-4d44-b609-5933d287c0df-s3"` | no |
| <a name="output_kafka_bootstrap_servers"></a> [kafka\_bootstrap\_servers](#output\_kafka\_bootstrap\_servers) | Bootstrap Servers of the Serverless Managed Kafka | `"boot-2zpjjxeb.c3.kafka-serverless.us-east-1.amazonaws.com:9098"` | no |
| <a name="output_nat_gateway_ip"></a> [nat\_gateway\_ip](#output\_nat\_gateway\_ip) | NAT Gateway IP address | `"44.209.160.13"` | no |
| <a name="output_route53_nameservers"></a> [route53\_nameservers](#output\_route53\_nameservers) | some description | <pre>[<br>  "ns-1312.awsdns-36.org",<br>  "ns-1537.awsdns-00.co.uk",<br>  "ns-492.awsdns-61.com",<br>  "ns-796.awsdns-35.net"<br>]</pre> | no |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | some description | `"Z06393165SX7J27I8MT8"` | no |
| <a name="output_secrets_arn"></a> [secrets\_arn](#output\_secrets\_arn) | Environment secrets ARN | `"arn:aws:secretsmanager:us-east-1:767398123958:secret:environment-c60Wuz"` | no |
| <a name="output_site_bucket_name"></a> [site\_bucket\_name](#output\_site\_bucket\_name) | Name of the marketing site bucket | `"fakebusiness-website-production"` | no |
| <a name="output_site_url"></a> [site\_url](#output\_site\_url) | API URL | `"https://site.fakebusiness.com"` | no |
