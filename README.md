1. 의존성 설치
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform

2. AWS 자격증명
   aws configure

# or

export AWS*PROFILE=<네*프로필>

3. 람다 패키징
   cd edge-example/edge
   zip -r ../edge.zip .
   cd ..

4.테라폼 실행
terraform init
terraform plan -var="lambda_exec_role_arn=arn:aws:iam::<ACCOUNT_ID>:role/terraform/lambda-exec"
terraform apply -auto-approve -var="lambda_exec_role_arn=arn:aws:iam::<ACCOUNT_ID>:role/terraform/lambda-exec"
