# AWS CloudFront + Lambda@Edge + S3 정적 웹사이트

이 프로젝트는 AWS의 CloudFront, Lambda@Edge, S3를 사용하여 정적 웹사이트를 배포하는 테라폼 인프라 코드입니다.

## 🏗️ 아키텍처

```
사용자 요청 → CloudFront → Lambda@Edge → S3 (정적 파일)
     ↑              ↓
   응답 ←      캐싱된 콘텐츠
```

### 구성 요소

- **CloudFront**: 전 세계 CDN, 사용자에게 빠른 콘텐츠 전달
- **Lambda@Edge**: 요청/응답 실시간 처리 (헤더 추가, 리다이렉트 등)
- **S3**: 정적 파일 저장소 (HTML, CSS, JS, 이미지 등)

## 📁 프로젝트 구조

```
aws-cf-test/
├── edge/                 # Lambda@Edge 함수 코드
│   └── index.js         # Edge 함수 소스 코드
├── src/                  # 정적 웹사이트 파일들
│   └── index.html       # 메인 HTML 파일
├── tf/                   # 테라폼 인프라 코드
│   ├── main.tf          # 메인 리소스 정의
│   ├── variables.tf     # 변수 정의
│   └── output.tf        # 출력값 정의
├── scripts/              # 배포 스크립트
│   ├── package.sh       # Lambda 함수 패키징
│   └── terraform.sh     # 테라폼 배포 스크립트
├── edge.zip             # 압축된 Lambda 함수 (자동 생성)
└── README.md            # 프로젝트 문서
```

## 🚀 빠른 시작

### 사전 요구사항

1. **Terraform 설치**

   ```bash
   brew install terraform
   ```

2. **AWS CLI 설치 및 설정**

   ```bash
   # AWS CLI 설치 (이미 설치되어 있음)
   aws --version

   # AWS 자격 증명 설정
   aws configure
   # 또는 AWS_PROFILE 환경변수 사용
   ```

3. **IAM 역할 생성**
   ```bash
   # Lambda@Edge 실행용 IAM 역할이 필요합니다
   # 역할명: lambda-exec
   # 정책: AWSLambdaBasicExecutionRole
   ```

### 배포하기

1. **스크립트 실행**

   ```bash
   # ACCOUNT_ID: AWS 계정 ID (12자리 숫자)
   # AWS_PROFILE: AWS 프로파일명
   ./scripts/terraform.sh <ACCOUNT_ID> <AWS_PROFILE>

   # 예시
   ./scripts/terraform.sh 123456789012 default
   ```

2. **수동 배포 (스크립트 없이)**

   ```bash
   # Lambda 함수 패키징
   ./scripts/package.sh

   # 테라폼 초기화
   cd tf
   terraform init

   # 배포 계획 확인
   terraform plan -var="lambda_exec_role_arn=arn:aws:iam::<ACCOUNT_ID>:role/lambda-exec"

   # 실제 배포
   terraform apply -auto-approve -var="lambda_exec_role_arn=arn:aws:iam::<ACCOUNT_ID>:role/lambda-exec"
   ```

## 📋 생성되는 리소스

### AWS 리소스 목록

- **S3 버킷**: `cf-test-site` (정적 파일 저장)
- **CloudFront 배포**: 전 세계 CDN
- **Lambda@Edge 함수**: `cf-test-edge` (us-east-1)
- **Origin Access Control**: S3 보안 접근 제어
- **S3 버킷 정책**: CloudFront만 접근 허용

### 출력값

```bash
terraform output
# account_id: AWS 계정 ID
# bucket: S3 버킷명
# cloudfront_domain: CloudFront 도메인
# lambda_edge_version_arn: Lambda@Edge 버전 ARN
```

## 🔧 설정 변경

### 프로젝트명 변경

`tf/variables.tf`에서 `project` 변수 수정:

```hcl
variable "project" {
  default = "my-project"  # 원하는 프로젝트명으로 변경
}
```

### 리전 변경

`tf/variables.tf`에서 `region` 변수 수정:

```hcl
variable "region" {
  default = "us-east-1"  # 원하는 리전으로 변경
}
```

### 정적 파일 추가

`src/` 폴더에 파일을 추가하면 자동으로 S3에 업로드됩니다:

```bash
# HTML, CSS, JS, 이미지 등 모든 파일 지원
src/
├── index.html
├── css/
│   └── style.css
├── js/
│   └── app.js
└── images/
    └── logo.png
```

## 🗑️ 리소스 삭제

### 전체 삭제

```bash
cd tf
terraform destroy -auto-approve -var="lambda_exec_role_arn=arn:aws:iam::<ACCOUNT_ID>:role/lambda-exec"
```

### 주의사항

- **IAM 역할**: 테라폼으로 삭제되지 않음 (보안상 자동 삭제 안됨)
- **S3 버킷**: `force_destroy = true` 설정으로 내용도 함께 삭제
- **CloudFront**: 배포 삭제에 시간이 걸릴 수 있음

## 🔍 모니터링 및 로그

### CloudFront 로그

- CloudWatch에서 Lambda@Edge 함수 로그 확인
- 리전: us-east-1 (Lambda@Edge는 us-east-1에 배포됨)

### S3 접근 로그

- S3 버킷에서 직접 접근 로그 확인 가능

## 🛠️ 개발 및 테스트

### Lambda@Edge 함수 수정

1. `edge/index.js` 수정
2. `./scripts/package.sh` 실행 (edge.zip 재생성)
3. `terraform apply` 실행 (함수 업데이트)

### 정적 파일 수정

1. `src/` 폴더의 파일 수정
2. `terraform apply` 실행 (자동으로 S3에 업로드)

## 📚 참고 자료

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Lambda@Edge Documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-edge.html)
- [S3 Documentation](https://docs.aws.amazon.com/s3/)

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## ⚠️ 주의사항

- **비용**: CloudFront, Lambda@Edge, S3 사용량에 따른 요금 발생
- **보안**: IAM 역할과 정책을 적절히 설정하여 최소 권한 원칙 준수
- **백업**: 중요한 데이터는 별도로 백업 권장
