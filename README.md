# Cloud Architect Tutor — Basic Edition

**Free. Open Source. Educational.**

Generate a production-pattern Terraform configuration for AWS EC2 by answering a few simple questions. No more blank files. No more guessing.

[![Demo Video](https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg)](https://youtube.com/watch?v=YOUR_VIDEO_ID)

---

## What This Does

- Asks what you're building and your expected scale
- Teaches architectural tradeoffs before generating any code
- Generates **modular, deployable Terraform** for an EC2 instance
- Includes security groups, IAM roles, CloudWatch logging, and optional Prometheus + Grafana monitoring
- Logs your learning journey so you can track progress

---

## What You Need

- **Terraform** 1.6 or later
- **AWS account** with credentials configured (`aws configure`)
- An existing **EC2 key pair**
- A **VPC and subnet** in your AWS account

---

## Quick Start

```bash
git clone https://github.com/BuildMintZ/cloud-architect-tutor.git
cd cloud-architect-tutor
chmod +x cloud-architect-tutor.sh
bash cloud-architect-tutor.sh
Answer the prompts. Your Terraform configuration will be generated in infrastructure/terraform/.

What Gets Generated
text
infrastructure/terraform/your-project-webapp_micro/
├── main.tf                  # EC2 instance, IAM, security groups
├── variables.tf             # Typed input variables
├── user_data.sh             # Bootstrap script (Docker, optional monitoring)
└── modules/
    ├── ec2-instance/        # Reusable EC2 module
    └── security-groups/     # Reusable security group module
This Is the Basic (Free) Edition
This version focuses on EC2 generation — the foundation of cloud infrastructure. It showcases the educational logic and code quality of the full product.

Want the Full Product?
Cloud Architect Tutor v7.0 generates 14 production scenarios across all scales:

Scale	Architecture
1k users	Single EC2
10k users	Auto-Scaling Group + RDS
100k users	EKS + WAF + Multi-AZ
1M+ users	Multi-Region EKS + Global DB
What the full version adds:

🏗️ VPC, subnets, NAT gateways, flow logs

⚙️ ECS Fargate & EKS with managed node groups

🗄️ RDS PostgreSQL, Aurora, ElastiCache

🔒 KMS encryption, WAFv2, IAM least privilege

📊 CloudWatch dashboards, alarms, SNS

🚀 CI/CD pipeline (GitHub Actions)

📚 ADR documentation, deployment guides, cheatsheets

🎓 Built-in lessons at every decision point

👉 Get the Full Version →

License
MIT — Free to use, modify, and share.

Watch the Demo
https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg

Built by BuildMintZ — Infrastructure that ships revenue.