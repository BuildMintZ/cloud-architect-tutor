# Cloud Architect Tutor — Basic Edition

**Free. Open Source. Educational.**

Generate a production-pattern Terraform configuration for AWS EC2 by answering a few simple questions. No more blank files. No more guessing.

[![Demo Video](https://img.youtube.com/vi/5dLl5u2vPII/0.jpg)](https://www.youtube.com/watch?v=5dLl5u2vPII)

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

Want the full product?
👉 Cloud Architect Tutor v7.0
https://www.usefreelanceflow.com/cloud-architect-tutor.html

Full Version Capabilities
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

🎓 Built‑in lessons at every decision point

Watch the Demo
https://www.youtube.com/watch?v=5dLl5u2vPII

Click the image to see the script in action — from running the script to terraform plan (intentionally fails to prove the code is real).

License
MIT — Free to use, modify, and share.

Built by BuildMintZ — Infrastructure that ships revenue.
https://www.usefreelanceflow.com/

text

---

This README is clean, professional, and makes the video the centerpiece of the demo. It clearly separates the free Basic edition from the paid Pro version while giving users a clear path to upgrade.
