Cloud Architect Tutor — Basic Edition (v6.0.1)
Free. Open Source. Educational.

Stop staring at blank Terraform files. Answer a few questions about what you're building and your expected scale — and receive production‑grade, modular Terraform code for 14 AWS architectures, from a single EC2 instance to multi‑region EKS serving 1M+ users.

https://img.youtube.com/vi/5dLl5u2vPII/0.jpg

What This Does
Asks what you're building: Web App, Microservices, Data Pipeline, or IoT Backend

Asks your expected scale: 1k → 1M+ users (or events/sec, devices)

Teaches architectural tradeoffs before generating any code (e.g., when to use Kubernetes, why state management matters)

Generates modular, deployable Terraform for the appropriate architecture:

Single EC2 (1‑1k users)

Monitored EC2 (1k‑5k)

Auto‑Scaling Group + RDS (5k‑10k)

ECS Fargate + Aurora (10k‑50k)

EKS + Multi‑AZ (50k‑100k)

Multi‑region EKS + Global DB (100k‑1M)

Microservices (ECS Service Mesh, EKS + Istio)

Data Pipelines (EC2+SQS+RDS / Kinesis+EMR+S3)

IoT Backend (Kinesis+Lambda+DynamoDB / Multi‑region ingestion)

Includes security groups, IAM roles, CloudWatch logging, optional Prometheus+Grafana

Logs your learning journey across sessions

What You Need
Terraform 1.6 or later

AWS account with credentials configured (aws configure)

An existing EC2 key pair

A VPC and subnet in your AWS account (for single‑instance scenarios; ASG/EKS can create a VPC for you)

Quick Start
bash
git clone https://github.com/BuildMintZ/cloud-architect-tutor.git
cd cloud-architect-tutor
chmod +x cloud-architect-tutor.sh
bash cloud-architect-tutor.sh
Answer the prompts. Your Terraform configuration will be generated in infrastructure/terraform/.

What Gets Generated (Example: Web App, 10k users)
text
infrastructure/terraform/myapp-webapp_medium/
├── main.tf                  # VPC, ASG, ALB, RDS, security groups
├── variables.tf             # Typed input variables
├── user_data.sh             # Bootstrap script
└── modules/
    ├── ec2-instance/        # Reusable EC2 module
    └── security-groups/     # Reusable security group module
For EKS scenarios, you'll also get hybrid Helm chart examples.

Basic Edition                       (Free) vs               Pro Version (v7.0)
Feature	Basic (v6.0.1)	                                    Pro (v7.0)
14 production scenarios	                ✅	                        ✅
Generates Terraform code	            ✅	                        ✅
Teaches architecture decisions	        ✅	                        ✅
Tracks learning journal	                ✅	                        ✅
Pre‑flight AWS checks	                ❌	                        ✅
KMS encryption (per‑service)	        ❌	                        ✅
RDS Proxy, WAFv2, VPC Flow Logs	        ❌	                        ✅
CI/CD pipeline (GitHub Actions)	        ❌	                        ✅
ADR, cheatsheet, deploy docs	        ❌	                        ✅
Production‑grade modules            	❌	                        ✅
Private Slack community	                ❌	                        ✅

The Basic Edition is a complete, functional learning tool — you can build real infrastructure from 1 user to 1M+.
The Pro version adds enterprise‑grade hardening, automation, and documentation.

👉 Get the Pro Version (v7.0)
https://www.usefreelanceflow.com/cloud-architect-tutor.html

Watch the Demo
https://www.youtube.com/watch?v=5dLl5u2vPII
See the script in action — from running it to terraform plan (intentionally fails because a fake VPC ID is used, proving the code is real and valid).

License
MIT — Free to use, modify, and share.

Built by BuildMintZ — Infrastructure that ships revenue.
https://www.usefreelanceflow.com/