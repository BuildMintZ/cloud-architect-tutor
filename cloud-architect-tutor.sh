#!/usr/bin/env bash
# ============================================================
# CLOUD ARCHITECT TUTOR v7.0.0 — MASTERY EDITION Basic
#   Master Terraform, AWS architecture & K8s decisions in 5-10 runs.
#   Generates production‑grade, modular Terraform configurations
#   for 14 scenarios, from a single EC2 to global multi‑region EKS.
#
# Usage: bash cloud-architect-tutor.sh [--force] [--skip-prompts] [--auto-deploy]
# ============================================================
set -euo pipefail

# Fix for Git Bash on Windows - enable ANSI color processing
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    export TERM=xterm-256color
fi

# ────────────────────────────────────────────────────────────
# COLOR DEFINITIONS
# ────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly GRAY='\033[0;90m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

readonly SCRIPT_VERSION="7.0.0"
readonly SCRIPT_NAME="cloud-architect-tutor.sh"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
readonly JOURNAL_FILE="$HOME/.cloud-architect-tutor-journal"

SKIP_PROMPTS=false
FORCE_OVERWRITE=false
AUTO_DEPLOY=false
USERS=""
SYS_TYPE=""
TIER=""
SCENARIO_ID=""
USE_KUBERNETES="false"
USE_HYBRID="false"

# ────────────────────────────────────────────────────────────
# COST ESTIMATES DICTIONARY
# ────────────────────────────────────────────────────────────
declare -A ESTIMATED_COSTS=(
    ["webapp_micro"]="\$0–\$50/mo (free tier eligible)"
    ["webapp_small"]="\$50–\$150/mo"
    ["webapp_medium"]="\$500–\$1,000/mo"
    ["webapp_large"]="\$1,500–\$5,000/mo"
    ["webapp_xlarge"]="\$5,000–\$20,000/mo"
    ["webapp_enterprise"]="\$20,000–\$150,000+/mo"
    ["webapp_hyperscale"]="\$150,000+/mo"
    ["microservices_medium"]="\$1,500–\$5,000/mo"
    ["microservices_large"]="\$5,000–\$20,000/mo"
    ["microservices_xlarge"]="\$20,000–\$100,000/mo"
    ["pipeline_medium"]="\$1,000–\$3,000/mo"
    ["pipeline_large"]="\$5,000–\$20,000/mo"
    ["iot_xlarge"]="\$5,000–\$20,000/mo"
    ["iot_enterprise"]="\$20,000–\$100,000+/mo"
)

# ────────────────────────────────────────────────────────────
# AWS-SPECIFIC SESSION VARIABLES
# ────────────────────────────────────────────────────────────
declare AWS_PROFILE="${AWS_PROFILE:-default}"
declare AWS_ACCOUNT_ID=""
declare AWS_USER_ID=""
declare AWS_REGION_CONFIGURED=""
declare HAS_AWS_CLI=false
declare HAS_TERRAFORM=false
declare HAS_KUBECTL=false
declare HAS_HELM=false

# ────────────────────────────────────────────────────────────
# SCENARIO DEFINITIONS
# ────────────────────────────────────────────────────────────
declare -A SCENARIO_NAMES=(
    ["webapp_micro"]="Web App — Single EC2 (1-1k users)"
    ["webapp_small"]="Web App — Monitored Single Instance (1k-5k)"
    ["webapp_medium"]="Web App — Auto-Scaling Group + RDS (5k-10k)"
    ["webapp_large"]="Web App — ECS Fargate + Aurora (10k-50k)"
    ["webapp_xlarge"]="Web App — EKS + Multi-AZ (50k-100k)"
    ["webapp_enterprise"]="Web App — Multi-Region EKS + Global DB (100k-1M)"
    ["webapp_hyperscale"]="Web App — Cell-Based Architecture (1M+)"
    ["microservices_medium"]="Microservices — ECS Service Mesh (5k-10k)"
    ["microservices_large"]="Microservices — EKS + Istio (10k-50k)"
    ["microservices_xlarge"]="Microservices — Multi-Cluster EKS (50k-100k)"
    ["pipeline_medium"]="Data Pipeline — EC2 + SQS + RDS (5k-10k events/sec)"
    ["pipeline_large"]="Data Pipeline — Kinesis + EMR + S3 (10k-50k events/sec)"
    ["iot_xlarge"]="IoT Backend — Kinesis + Lambda + DynamoDB (50k-100k devices)"
    ["iot_enterprise"]="IoT Backend — Multi-Region Ingestion (100k-1M devices)"
)

declare -A SCALING_TIERS=(
    ["micro"]="1-1000"
    ["small"]="1000-5000"
    ["medium"]="5000-10000"
    ["large"]="10000-50000"
    ["xlarge"]="50000-100000"
    ["enterprise"]="100000-1000000"
    ["hyperscale"]="1000000+"
)

# ────────────────────────────────────────────────────────────
# LOGGING FUNCTIONS
# ────────────────────────────────────────────────────────────
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { echo -e "${GRAY}[DEBUG]${NC} $*"; }
log_lesson() { 
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}📚 LESSON:${NC} $*"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_section() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

# ────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${CYAN}║              CLOUD ARCHITECT TUTOR v${SCRIPT_VERSION}                        ║"
    echo -e "${CYAN}║                                                                      ║"
    echo -e "${CYAN}║  Master Terraform, AWS architecture & K8s decisions in 5-10 runs.   ║"
    echo -e "${CYAN}║  ✓ Interactive scenario selection                                    ║"
    echo -e "${CYAN}║  ✓ Teaches tradeoffs at every decision point                        ║"
    echo -e "${CYAN}║  ✓ Generates modular, production‑grade Terraform                    ║"
    echo -e "${CYAN}║  ✓ Tracks your learning journey                                     ║"
    echo -e "${CYAN}║  ✓ Pre-flight checks & cost estimates                               ║"
    echo -e "${CYAN}║  ✓ AWS Well-Architected assessments                                 ║"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_pre_run_requirements() {
    echo -e "${YELLOW}📋 BEFORE YOU CONTINUE — Have these ready:${NC}"
    echo -e "  ${BOLD}1. AWS Account${NC} with programmatic access (Access Key + Secret Key)"
    echo -e "     → Run ${GREEN}aws configure${NC} if you haven't already."
    echo -e "  ${BOLD}2. An existing VPC and public subnet${NC}"
    echo -e "     → The script can create a new VPC for ASG/EKS scenarios,"
    echo -e "       but ${BOLD}single‑instance scenarios REQUIRE a pre‑existing VPC & subnet.${NC}"
    echo -e "     → Know your VPC ID (vpc‑xxxxxx) and subnet ID (subnet‑xxxxxx)."
    echo -e "  ${BOLD}3. An EC2 Key Pair${NC} in the target region."
    echo -e "     → The script will list available ones, but you can create one now:"
    echo -e "       ${GREEN}aws ec2 create-key-pair --key-name MyKey --region <region>${NC}"
    echo -e "  ${BOLD}4. Desired AWS Region${NC} (defaults available, but know your resources' region)."
    echo -e "  ${BOLD}5. Basic Terraform knowledge${NC} — you'll learn by doing.\n"
    pause_for_effect
}

show_pro_tip() {
    local tips=(
        "Always tag resources with Environment and CostCenter – it saves you when the AWS bill comes."
        "terraform plan -out=tfplan ensures you apply exactly what you reviewed."
        "Use terraform fmt & terraform validate in your CI pipeline."
        "Avoid hardcoding secrets – use AWS Secrets Manager or SSM Parameter Store."
        "For stateful apps, always use Multi‑AZ and automated snapshots."
        "Keep Terraform versions consistent across your team with .terraform-version files."
    )
    local idx=$(( RANDOM % ${#tips[@]} ))
    echo -e "${GREEN}💡 Pro Tip: ${tips[$idx]}${NC}"
}

create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

write_file() {
    local filepath="$1"
    local content="$2"
    local force="${3:-false}"
    create_directory "$(dirname "$filepath")"
    if [[ -f "$filepath" ]] && [[ "$force" != "true" ]]; then
        log_warn "File already exists: $filepath (use --force to overwrite)"
        return 0
    fi
    echo "$content" > "$filepath"
    log_debug "Written: $filepath"
}

read_input() {
    local prompt="$1"
    local default="$2"
    local input
    if [[ "$SKIP_PROMPTS" == "true" ]]; then
        echo "$default"
        return 0
    fi
    read -r -p "$(echo -e "${CYAN}👉 ${prompt}${NC} [default: ${default}]: ")" input
    echo "${input:-$default}"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local response
    if [[ "$SKIP_PROMPTS" == "true" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    local hint="[Y/n]"
    [[ "$default" == "n" ]] && hint="[y/N]"
    read -r -p "$(echo -e "${CYAN}👉 ${prompt} ${hint}${NC}: ")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy] ]] && return 0 || return 1
}

get_public_ip() {
    local ip=""
    for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com" "https://checkip.amazonaws.com"; do
        if command -v curl &>/dev/null; then
            ip=$(curl -s --max-time 5 "$service" 2>/dev/null) && break
        elif command -v wget &>/dev/null; then
            ip=$(wget -qO- --timeout=5 "$service" 2>/dev/null) && break
        fi
    done
    if [[ -z "$ip" ]]; then
        log_warn "Could not detect public IP automatically"
        echo "YOUR_IP_HERE"
    else
        log_info "Detected public IP: $ip"
        echo "$ip"
    fi
}

determine_tier() {
    local users=$1
    if   [[ "$users" -lt 1000 ]];  then echo "micro"
    elif [[ "$users" -lt 5000 ]];  then echo "small"
    elif [[ "$users" -lt 10000 ]]; then echo "medium"
    elif [[ "$users" -lt 50000 ]]; then echo "large"
    elif [[ "$users" -lt 100000 ]]; then echo "xlarge"
    elif [[ "$users" -lt 1000000 ]]; then echo "enterprise"
    else echo "hyperscale"
    fi
}

pause_for_effect() {
    if [[ "$SKIP_PROMPTS" != "true" ]]; then
        read -r -p "$(echo -e "${GRAY}Press Enter to continue...${NC}")" _
    fi
}

# ────────────────────────────────────────────────────────────
# JOURNAL & TRACKING FUNCTIONS
# ────────────────────────────────────────────────────────────
check_journal() {
    if [[ -f "$JOURNAL_FILE" ]]; then
        local completed_count
        completed_count=$(grep -c "COMPLETED:" "$JOURNAL_FILE" 2>/dev/null || echo "0")
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}📚 Welcome back! You've completed ${BOLD}${completed_count}${NC}${CYAN} session(s).${NC}"
        if [[ "$completed_count" -gt 0 ]]; then
            echo -e "${GRAY}   Previous scenarios:${NC}"
            tail -5 "$JOURNAL_FILE" | while IFS= read -r line; do
                echo -e "${GRAY}   • $line${NC}"
            done
        fi
        if [[ "$completed_count" -ge 2 ]]; then
            echo -e "${YELLOW}   🧠 Try a different system type or scale to unlock new patterns.${NC}"
        fi
        if [[ "$completed_count" -ge 5 ]]; then
            echo -e "${GREEN}   🏆 You're building deep architectural intuition. Keep going!${NC}"
        fi
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        echo "$completed_count"
    else
        echo "0"
    fi
}

log_session() {
    local scenario_name="${SCENARIO_NAMES[$SCENARIO_ID]:-$SCENARIO_ID}"
    echo "$TIMESTAMP | COMPLETED: $scenario_name | Kubernetes=$USE_KUBERNETES | Hybrid=$USE_HYBRID | Tier=$TIER | Users=$USERS | Region=$region | Project=$proj_name" >> "$JOURNAL_FILE"
    log_info "Session logged to $JOURNAL_FILE"
}

suggest_next_run() {
    local completed="$1"
    echo -e "\n${CYAN}💡 NEXT STEPS:${NC}"
    case "$completed" in
        0|1) echo -e "   Try a different ${BOLD}system type${NC} (e.g., Microservices or Data Pipeline)"
              echo -e "   or increase ${BOLD}user scale${NC} to see how architecture evolves." ;;
        2|3) echo -e "   Try choosing ${BOLD}Kubernetes${NC} when prompted to learn hybrid workflows."
              echo -e "   Or explore the ${BOLD}IoT Backend${NC} path for event-driven patterns." ;;
        4)   echo -e "   One more session to mastery! Try ${BOLD}Enterprise/Hyperscale${NC} for multi-region." ;;
        *)   echo -e "   ${GREEN}🏅 Mastery achieved!${NC} Try teaching a colleague with this tool."
              echo -e "   Revisit any scenario to deepen understanding, or explore ${BOLD}custom architectures${NC}." ;;
    esac
}

# ────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECK FUNCTIONS
# ────────────────────────────────────────────────────────────
check_prerequisites() {
    log_section "PRE-FLIGHT CHECKS"
    local errors=0
    
    # Check AWS CLI
    if command -v aws &>/dev/null; then
        HAS_AWS_CLI=true
        log_info "AWS CLI found: $(aws --version 2>&1 | head -1)"
    else
        HAS_AWS_CLI=false
        log_error "AWS CLI not found"
        log_error "Install: https://aws.amazon.com/cli/"
        ((errors++))
    fi
    
    # Check Terraform
    if command -v terraform &>/dev/null; then
        HAS_TERRAFORM=true
        local tf_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        log_info "Terraform found: v${tf_version}"
    else
        HAS_TERRAFORM=false
        log_error "Terraform not found"
        log_error "Install: https://www.terraform.io/downloads"
        ((errors++))
    fi
    
    # Check AWS credentials
    if [[ "$HAS_AWS_CLI" == "true" ]]; then
        if AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
            AWS_USER_ID=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
            AWS_REGION_CONFIGURED=$(aws configure get region 2>/dev/null || echo "not-set")
            log_info "AWS authenticated: Account ${AWS_ACCOUNT_ID}"
            log_info "AWS region configured: ${AWS_REGION_CONFIGURED}"
        else
            log_error "AWS credentials not configured"
            log_error "Run: aws configure"
            ((errors++))
        fi
    fi
    
    # Check kubectl (optional)
    if command -v kubectl &>/dev/null; then
        HAS_KUBECTL=true
        log_info "kubectl found (for EKS management)"
    else
        HAS_KUBECTL=false
        log_warn "kubectl not found (optional, for EKS management)"
    fi
    
    # Check helm (optional)
    if command -v helm &>/dev/null; then
        HAS_HELM=true
        log_info "helm found (for EKS application deployment)"
    else
        HAS_HELM=false
        log_warn "helm not found (optional, for hybrid workflow)"
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo ""
        log_error "✗ ${errors} prerequisite(s) missing. Fix them before proceeding."
        echo -e "${YELLOW}Tip: Use --skip-prompts flag to bypass interactive mode for testing.${NC}"
        return 1
    fi
    
    log_info "All prerequisites satisfied! ✓\n"
    return 0
}

check_iam_permissions() {
    log_info "Verifying AWS permissions..."
    local perm_errors=0
    
    # Test EC2
    if aws ec2 describe-regions --region-names us-east-1 &>/dev/null; then
        log_info "✓ EC2 permissions"
    else
        log_warn "✗ EC2 permissions may be restricted"
        ((perm_errors++))
    fi
    
    # Test IAM (needed for roles)
    if aws iam list-roles --max-items 1 &>/dev/null; then
        log_info "✓ IAM permissions"
    else
        log_warn "✗ IAM permissions may be restricted (needed for instance roles)"
        ((perm_errors++))
    fi
    
    # Test EKS if K8s selected
    if [[ "$USE_KUBERNETES" == "true" ]]; then
        if aws eks list-clusters --max-items 1 &>/dev/null 2>&1; then
            log_info "✓ EKS permissions"
        else
            log_warn "✗ EKS permissions may be restricted (needed for cluster creation)"
            ((perm_errors++))
        fi
    fi
    
    if [[ $perm_errors -gt 0 ]]; then
        log_warn "Some permissions missing. You may need to attach additional IAM policies."
        echo -e "${YELLOW}Recommended policies: AdministratorAccess (for learning)${NC}"
    fi
}

# ────────────────────────────────────────────────────────────
# EDUCATIONAL LESSON FUNCTIONS
# ────────────────────────────────────────────────────────────
evaluate_well_architected() {
    log_lesson "AWS WELL-ARCHITECTED FRAMEWORK — Quick Assessment"
    
    echo -e "${BOLD}Rate your architecture against 6 pillars:${NC}\n"
    
    echo -e "${CYAN}Operational Excellence:${NC}"
    echo "  ✓ Automate deployments (Terraform does this)"
    echo "  ✓ Monitor everything (CloudWatch + monitoring)"
    echo "  ✓ Document decisions (ADR generated)"
    echo -e "  - CI/CD pipeline (generated for GitHub Actions)\n"
    
    echo -e "${CYAN}Security:${NC}"
    echo "  ✓ Least privilege (IAM roles, no access keys)"
    echo "  ✓ Encryption everywhere (EBS, RDS encrypted)"
    echo "  ✓ Network security (SGs restricted)"
    echo -e "  - Missing: WAF, Shield, CloudTrail, GuardDuty\n"
    
    echo -e "${CYAN}Reliability:${NC}"
    if [[ "$SCENARIO_ID" =~ micro|small ]]; then
        echo "  - Single instance = single point of failure"
        echo "  - No load balancer = no health checks"
        echo "  - Recovery: Manual from backup"
    elif [[ "$SCENARIO_ID" =~ medium ]]; then
        echo "  ✓ ASG auto-heals failed instances"
        echo "  ✓ RDS Multi-AZ fails over automatically"
        echo "  ✓ ALB distributes across AZs"
    else
        echo "  ✓ Multi-AZ throughout the stack"
        echo "  ✓ Auto-scaling for all layers"
        echo "  ✓ Kubernetes provides self-healing"
    fi
    echo ""
    
    echo -e "${CYAN}Performance Efficiency:${NC}"
    echo "  ✓ Auto-scaling adjusts capacity"
    echo "  ✓ Right-sized instance types (configurable)"
    echo -e "  - Need load testing to confirm\n"
    
    echo -e "${CYAN}Cost Optimization:${NC}"
    echo "  - No Reserved Instances (pay-as-you-go)"
    echo "  - No Spot instances (unless you configure)"
    echo "  - No Savings Plans"
    echo -e "  ✓ Resources tagged (Environment, Project, ManagedBy)\n"
    
    echo -e "${CYAN}Sustainability:${NC}"
    echo "  - Consider Graviton (ARM) instances for 20% less energy"
    echo "  - Right-size resources (don't over-provision)"
    echo -e "  - Use serverless when possible\n"
    
    echo -e "${YELLOW}💡 Your architecture scores ${BOLD}$( [[ "$SCENARIO_ID" =~ medium|large ]] && echo "4/6" || echo "3/6" )${NC} pillars.${NC}"
    echo "   Review the AWS Well-Architected whitepaper for production readiness."
    pause_for_effect
}

display_architecture_and_cost() {
    log_section "ARCHITECTURE DIAGRAM & COST DASHBOARD"
    case "$SCENARIO_ID" in
        webapp_micro)
            echo -e "${GRAY}  Internet → EC2 (t3.micro)${NC}"
            echo -e "${YELLOW}  Cost: ~\$15/mo (free tier eligible)${NC}" ;;
        webapp_medium)
            echo -e "${GRAY}  Internet → ALB → ASG (2-6 t3.large) → RDS Multi‑AZ${NC}"
            echo -e "${YELLOW}  Cost: EC2 ~\$150, RDS ~\$300, ALB ~\$20 → Total ~\$470/mo${NC}" ;;
        webapp_large)
            echo -e "${GRAY}  Internet → ALB → ECS Fargate → Aurora Serverless${NC}"
            echo -e "${YELLOW}  Cost: ECS ~\$200, Aurora ~\$400 → Total ~\$600/mo${NC}" ;;
        webapp_xlarge|*_eks)
            echo -e "${GRAY}  Internet → ALB → EKS (managed nodes) → RDS Multi‑AZ${NC}"
            echo -e "${YELLOW}  Cost: EKS cluster ~\$73, nodes ~\$500, RDS ~\$600 → ~\$1173/mo${NC}" ;;
        *)
            echo -e "${GRAY}  Custom architecture (see Terraform files)${NC}" ;;
    esac
    echo -e "\n${CYAN}💡 Pro Tip: Use AWS Pricing Calculator for precise numbers.${NC}"
    pause_for_effect
}

teach_architecture_decision() {
    log_section "ARCHITECTURE DECISION — Why This Pattern?"

    case "$SYS_TYPE" in
        webapp)
            case "$TIER" in
                micro) 
                    log_lesson "Single EC2 is right for you because:"
                    echo "  • No need for load balancer – one instance handles all traffic."
                    echo "  • Simplicity > complexity: easy to SSH, debug, and monitor."
                    echo "  • If you grow past 1000 concurrent users, you'll need an ASG." ;;
                small)
                    log_lesson "Monitored Single Instance – still simple but with visibility."
                    echo "  • CloudWatch alarms and Prometheus give you early warning."
                    echo "  • Good for internal tools or low‑risk applications." ;;
                medium)
                    log_lesson "ASG + ALB + RDS Multi‑AZ – high availability achieved."
                    echo "  • ASG auto‑heals failed instances; ALB balances traffic."
                    echo "  • RDS Multi‑AZ ensures database survives an AZ outage."
                    echo "  • At 5k‑10k users, this is the sweet spot before Kubernetes." ;;
                large|xlarge|enterprise|hyperscale)
                    log_lesson "Distributed architecture needed – containers or orchestration."
                    echo "  • Single‑instance or even ASG becomes a bottleneck."
                    echo "  • ECS Fargate or EKS gives service discovery, scaling, and resilience." ;;
            esac
            ;;
        microservices)
            log_lesson "Microservices demand independent scaling and deployment."
            echo "  • At $TIER scale, you need a service mesh or at least service discovery."
            [[ "$TIER" == "medium" ]] && echo "  • ECS Fargate is a great fit – no clusters to manage, pay per task."
            [[ "$TIER" == "large" ]] && echo "  • EKS becomes justified when you have 15+ services."
            echo "  • Terraform manages the cluster; Helm/ArgoCD manages apps." ;;
        pipeline)
            log_lesson "Data pipelines require decoupling and buffering."
            echo "  • SQS for task queues, Kinesis for streaming, EMR for batch."
            echo "  • At $TIER scale, serverless (Lambda) may be cheaper." ;;
        iot)
            log_lesson "IoT scales with device count, not concurrent users."
            echo "  • Kinesis + Lambda + DynamoDB = serverless, scales to millions of devices."
            echo "  • Use IoT Core for device management if needed." ;;
    esac
    pause_for_effect
}

teach_aws_limits() {
    log_section "AWS SERVICE LIMITS YOU SHOULD KNOW"
    
    echo -e "${BOLD}Common AWS limits that WILL bite you:${NC}\n"
    
    echo -e "${CYAN}VPC Limits:${NC}"
    echo "  • 5 VPCs per region (soft limit, can increase)"
    echo "  • 200 subnets per VPC"
    echo "  • 5 Elastic IPs per region"
    echo "  • NAT Gateway: ~\$32/month EACH (even if unused!)\n"
    
    echo -e "${CYAN}EC2 Limits:${NC}"
    echo "  • 20 running On-Demand instances per region (default)"
    echo "  • 5 VPC security groups per network interface"
    echo "  • t2.micro instances have CPU credits - exhaust them = throttled\n"
    
    echo -e "${CYAN}EKS Limits:${NC}"
    if [[ "$USE_KUBERNETES" == "true" ]]; then
        echo "  • 100 nodes per cluster (default)"
        echo "  • 10 clusters per region"
        echo "  • Cluster provisioning: 10-15 minutes (PLAN ACCORDINGLY)"
    else
        echo "  • Not applicable (not using Kubernetes)\n"
    fi
    
    echo -e "${CYAN}RDS Limits:${NC}"
    echo "  • 40 DB instances per region"
    echo "  • Storage auto-scaling: enabled by default on new instances"
    echo "  • Backup retention: max 35 days\n"
    
    echo -e "${YELLOW}💡 Pro Tip: Check your limits BEFORE deploying:${NC}"
    echo "   aws service-quotas list-service-quotas --service-code ec2\n"
    pause_for_effect
}

teach_networking_basics() {
    log_lesson "AWS NETWORKING — What You Must Know"
    
    echo -e "${BOLD}Every AWS engineer should understand:${NC}\n"
    
    echo -e "${CYAN}1. CIDR Blocks (IP Addressing)${NC}"
    echo "  • Your VPC: 10.0.0.0/16 (65,536 IPs)"
    echo "  • Public subnet: 10.0.1.0/24 (251 usable IPs after AWS reserves 5)"
    echo "  • Can't overlap with other VPCs if you plan to peer them"
    echo "  • RFC1918 ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"
    echo "  • /16 gives you room to grow, /24 is too small for production\n"
    
    echo -e "${CYAN}2. Internet Connectivity${NC}"
    echo "  • Public subnet = has route to Internet Gateway (IGW)"
    echo "  • IGW costs \$0 (FREE) - just need to add it to VPC"
    echo "  • Private subnet = uses NAT Gateway for outbound internet"
    echo "  • NAT Gateway: Managed, \$32/month + \$0.045/GB data processed"
    echo "  • NAT Instance: DIY, cheaper but you manage it (failover, patching)"
    echo "  • Bastion Host: EC2 instance in public subnet to SSH into private instances\n"
    
    echo -e "${CYAN}3. Security Layers (Defense in Depth)${NC}"
    echo "  • NACLs: Stateless, subnet-level firewall (first line of defense)"
    echo "  • Security Groups: Stateful, instance-level (allow return traffic automatically)"
    echo "  • SGs can reference other SGs (e.g., ALB SG → App SG)"
    echo "  • Network ACLs are evaluated in order (lowest number first)"
    echo "  • Security Groups are 'allow-all' pattern (can't block specific IPs)\n"
    
    echo -e "${CYAN}4. VPC Endpoints (Save NAT Gateway Costs!)${NC}"
    echo "  • Gateway endpoints: S3, DynamoDB (FREE)"
    echo "  • Interface endpoints: Everything else (\$7.20/month per AZ)"
    echo "  • Use endpoints to keep traffic within AWS backbone\n"
    
    echo -e "${CYAN}5. VPC Peering vs Transit Gateway${NC}"
    echo "  • VPC Peering: Direct connection between 2 VPCs (non-transitive)"
    echo "  • Transit Gateway: Hub-and-spoke for many VPCs (costs \$36/month + \$0.02/GB)"
    echo "  • Use Transit Gateway for 3+ VPCs or multi-region\n"
    
    echo -e "${YELLOW}💡 Common mistake: Confusing public vs private subnets.${NC}\n"
    pause_for_effect
}

teach_instance_types() {
    log_lesson "EC2 INSTANCE TYPES — When to Use What"
    
    echo -e "${BOLD}Quick Decision Guide:${NC}\n"
    
    echo -e "${CYAN}General Purpose (T-family - Burstable):${NC}"
    echo "  • t3.micro: 2 vCPU, 1GB RAM - FREE TIER (1 year, 750 hrs/month)"
    echo "  • t3.small: 2 vCPU, 2GB RAM - Dev environments"
    echo "  • t3.medium: 2 vCPU, 4GB RAM - Most common for web apps"
    echo "  • t4g.small: 2 vCPU ARM, 2GB RAM - 20% cheaper, better perf"
    echo "  • t4g.medium: 2 vCPU ARM, 4GB RAM - Best price/performance\n"
    
    echo -e "${CYAN}Compute Optimized (C-family):${NC}"
    echo "  • c5.large: 2 vCPU, 4GB RAM - For CPU-bound apps (encoding, ML)"
    echo "  • c6i.xlarge: 4 vCPU, 8GB RAM - Latest Intel generation"
    echo "  • c6g.large: 2 vCPU ARM, 4GB RAM - Graviton2, 20% cheaper\n"
    
    echo -e "${CYAN}Memory Optimized (R/X-family):${NC}"
    echo "  • r5.large: 2 vCPU, 16GB RAM - For databases, in-memory caches"
    echo "  • r6i.xlarge: 4 vCPU, 32GB RAM - Latest Intel generation\n"
    
    echo -e "${CYAN}Graviton (ARM - CHEAPER!):${NC}"
    echo "  • t4g, c6g, m6g, r6g: ARM-based processors"
    echo "  • Most Linux apps work without changes\n"
    
    echo -e "${BOLD}For YOUR scenario (${SCENARIO_ID}):${NC}"
    case "$SCENARIO_ID" in
        webapp_micro) echo "  → Recommended: t4g.micro (ARM) - cheaper than t3.micro" ;;
        webapp_small) echo "  → Recommended: t4g.small or t4g.medium" ;;
        webapp_medium) echo "  → Recommended: t4g.medium or t3.medium" ;;
        webapp_large) echo "  → Recommended: c6g.xlarge (ARM compute) for ECS tasks" ;;
        *) echo "  → See variables.tf for configured instance type" ;;
    esac
    
    echo -e "\n${GREEN}💡 Use 'AWS Compute Optimizer' for automated recommendations${NC}"
    pause_for_effect
}

teach_cost_optimization() {
    log_lesson "COST OPTIMIZATION — Save 30-70% on AWS"
    
    echo -e "${BOLD}Cost saving strategies for your tier:${NC}\n"
    
    case "$SCENARIO_ID" in
        webapp_micro|webapp_small)
            echo "  • Use t4g.small (ARM) instead of t3 - 20% cheaper + 40% better perf"
            echo "  • Single instance can use Reserved Instance: 1-year = 40% savings"
            echo "  • Stop instance during non-work hours (dev environments)"
            echo "  • Use gp3 volumes instead of gp2: 20% cheaper" ;;
        webapp_medium)
            echo "  • RDS Reserved Instance: 1-year = 40% savings"
            echo "  • ALB costs \$22/month + data processing"
            echo "  • NAT Gateway: \$32/month - consider VPC endpoints for S3 instead"
            echo "  • Use Spot instances for ASG (up to 90% savings) if fault-tolerant" ;;
        webapp_large|webapp_xlarge|webapp_enterprise)
            echo "  • EKS cluster: \$73/month just for control plane"
            echo "  • AWS Savings Plans: 1-year = 30% savings, 3-year = 50%+"
            echo "  • S3 Lifecycle policies: transition to IA after 30 days" ;;
        microservices_*)
            echo "  • ECS/EKS: Right-size tasks based on actual usage"
            echo "  • Use Fargate Spot for non-critical workloads" ;;
        pipeline_*)
            echo "  • EMR: Use managed scaling and spot instances"
            echo "  • Kinesis: Monitor shard usage, downsizing idle shards" ;;
        iot_*)
            echo "  • IoT Core: Use basic ingest (cheaper than rules engine)"
            echo "  • DynamoDB: On-demand vs provisioned capacity" ;;
    esac
    
    echo -e "\n${GREEN}💡 Use AWS Cost Explorer daily. Set budget alerts at 50%, 80%, 100%.${NC}"
    pause_for_effect
}

teach_disaster_recovery() {
    log_lesson "DISASTER RECOVERY — What's Your RTO/RPO?"
    
    echo -e "${BOLD}Define your recovery objectives:${NC}"
    echo "  • RTO (Recovery Time Objective): How long can you be down?"
    echo "  • RPO (Recovery Point Objective): How much data can you lose?\n"
    
    echo -e "${CYAN}Backup Strategy by Your Tier:${NC}"
    case "$SCENARIO_ID" in
        webapp_micro|webapp_small)
            echo "  → EBS Snapshots (manual, \$0.05/GB/month)"
            echo "  → RTO: 15 mins (launch new instance from snapshot)"
            echo "  → RPO: 24 hours" ;;
        webapp_medium)
            echo "  → RDS Automated Backups (7 days, included in cost)"
            echo "  → Cross-region snapshots for DR (\$0.02/GB for transfer)"
            echo "  → RTO: 1 hour (RDS restore + ASG launch)"
            echo "  → RPO: 5 minutes (RDS point-in-time recovery)" ;;
        webapp_large|webapp_xlarge|webapp_enterprise)
            echo "  → RDS Automated Backups + Cross-Region Read Replica"
            echo "  → Aurora Backtrack (rewind database, up to 72 hours)"
            echo "  → RTO: < 1 minute (Aurora failover is automatic)"
            echo "  → RPO: < 1 second (Aurora synchronous replication)" ;;
    esac
    
    echo -e "\n${BOLD}DR Testing Strategy:${NC}"
    echo "  • Restore RDS snapshot to separate environment monthly"
    echo "  • Chaos engineering: Kill random EC2 instances in staging"
    echo "  • Run tabletop exercises with your team quarterly\n"
    
    echo -e "${RED}⚠️  Test your restore process monthly. Untested backups = no backups.${NC}"
    pause_for_effect
}

teach_security_best_practices() {
    log_lesson "SECURITY — What 90% of Teams Miss"
    
    echo -e "${BOLD}Your generated code includes these security features:${NC}"
    echo "  ✓ EBS encryption by default"
    echo "  ✓ Security groups with least privilege (SSH restricted to your IP)"
    echo "  ✓ IAM roles instead of access keys"
    echo "  ✓ Multi-AZ for database\n"
    
    echo -e "${BOLD}What you MUST add for production:${NC}"
    echo "  ${RED}1. AWS WAF on ALB/CloudFront (blocks SQL injection, XSS)${NC}"
    echo "  ${RED}2. AWS Shield for DDoS protection${NC}"
    echo "  ${RED}3. AWS Config rules for compliance${NC}"
    echo "  ${RED}4. CloudTrail enabled in ALL regions${NC}"
    echo "  ${RED}5. Secrets Manager for passwords, not tfvars${NC}\n"
    
    echo -e "${BOLD}Today's security checklist:${NC}"
    echo "  □ SSH restricted to your IP only"
    echo "  □ Database password not visible in code"
    echo "  □ IAM roles with least privilege"
    echo "  □ Encryption at rest enabled (EBS + RDS)"
    echo "  □ No hardcoded credentials in user_data\n"
    
    echo -e "${YELLOW}⚠️  NEVER commit terraform.tfstate to Git - it contains plaintext secrets${NC}"
    pause_for_effect
}

teach_observability() {
    log_lesson "OBSERVABILITY — The Three Pillars"
    
    echo -e "${BOLD}Every production system needs:${NC}\n"
    
    echo -e "${CYAN}1. Logs (What happened?)${NC}"
    echo "  • CloudWatch Logs: \$0.50/GB ingested + \$0.03/GB stored"
    echo "  • Centralize logs: All apps → CloudWatch → optionally to Splunk/ELK"
    echo "  • Structured logging (JSON) makes searching easier\n"
    
    echo -e "${CYAN}2. Metrics (How is it performing?)${NC}"
    echo "  • CloudWatch Metrics: Free tier includes 10 metrics per instance"
    echo "  • Prometheus: Free, but you manage it"
    echo "  • Key metrics: CPU, memory, disk, network, 4xx/5xx errors, latency p99\n"
    
    echo -e "${CYAN}3. Traces (Where is the bottleneck?)${NC}"
    echo "  • AWS X-Ray: \$5 per 1M traces - great for microservices"
    echo "  • Jaeger/Zipkin: Open-source alternatives\n"
    
    echo -e "${BOLD}Alerting (When should you wake up?)${NC}"
    echo "  • Set CloudWatch Alarms for:"
    echo "    - CPU > 80% for 5 minutes (scale issue)"
    echo "    - 5xx errors > 10 in 5 minutes (application issue)"
    echo "    - RDS connections > 80% of max (connection leak)\n"
    
    echo -e "${BOLD}Dashboard (What do you monitor?)${NC}"
    echo "  • CloudWatch Dashboard: Free, 3 dashboards per region"
    echo "  • Grafana: More flexible, can combine data sources"
    pause_for_effect
}

teach_kubernetes_decision() {
    if [[ "$TIER" == "micro" || "$TIER" == "small" ]]; then
        log_lesson "At this scale, Kubernetes would be overkill. Stay simple."
        log_info "Single-instance or ASG is more cost-effective and easier to operate."
        USE_KUBERNETES="false"
        return
    fi

    log_lesson "KUBERNETES DECISION POINT — Does Your Scale Justify It?"

    echo -e "${BOLD}The most expensive decision in cloud is premature complexity.${NC}"
    echo ""
    echo -e "${BOLD}Kubernetes IS justified when:${NC}"
    echo "  ✓ 15+ independent services needing orchestration"
    echo "  ✓ Team has operational K8s experience (or budget to learn)"
    echo "  ✓ Need advanced deployments: canary, blue/green, A/B testing"
    echo "  ✓ Auto-scaling based on custom metrics (HPA with Prometheus)"
    echo "  ✓ Multi-cloud portability matters"
    echo "  ✓ Willing to pay ~\$73/month per EKS cluster"
    echo ""
    echo -e "${BOLD}Kubernetes is UNNECESSARY when:${NC}"
    echo "  ✗ Fewer than 10 services — ECS Fargate is simpler & cheaper"
    echo "  ✗ Team has no K8s experience — operational complexity is real"
    echo "  ✗ Tight budget — ECS + ASG handles this tier fine"
    echo "  ✗ Predictable, steady traffic — don't need K8s auto-pilot"
    echo ""
    echo -e "${BOLD}Terraform + K8s reality:${NC}"
    echo "  Most teams use Terraform for infrastructure (EKS, VPC, IAM)"
    echo "  and Helm/Kustomize + ArgoCD for application workloads on top."
    echo -e "  This is the ${BOLD}\"hybrid Terraform + Kubernetes workflow\"${NC} you'll learn today."

    echo ""
    if confirm "Do you want to use Kubernetes (EKS) for this architecture?" "n"; then
        USE_KUBERNETES="true"
        echo -e "${YELLOW}⚡ Kubernetes selected. We'll generate EKS with Terraform + discuss hybrid workflows.${NC}"
        if confirm "Also generate the hybrid pattern (Terraform for infra + Helm chart example)?" "y"; then
            USE_HYBRID="true"
        fi
    else
        USE_KUBERNETES="false"
        echo -e "${GREEN}Smart choice. ECS or bare ASG is simpler and still effective.${NC}"
    fi
    echo ""
}

teach_terraform_limitations() {
    log_lesson "TERRAFORM LIMITATIONS — What They Don't Tell You"
    echo -e "${BOLD}1. State Management Is the #1 Pain Point${NC}"
    echo "  • Local state files corrupt easily → ${GREEN}always use remote backend${NC}"
    echo "  • State file contains secrets in plaintext → encrypt & restrict access"
    echo "  • Moving resources between state files requires \`terraform state mv\`"
    echo ""
    echo -e "${BOLD}2. Terraform Is NOT Configuration Management${NC}"
    echo "  • It provisions infrastructure, not what runs on it"
    echo "  • Use user_data (simple), Ansible (complex), or immutable images (best)"
    echo -e "  • ${GREEN}Pattern:${NC} Terraform → AMI baked with Packer → ASG launch template"
    echo ""
    echo -e "${BOLD}3. Large Monolithic State Files${NC}"
    echo "  • Plan time grows linearly with resource count"
    echo -e "  • ${GREEN}Solution:${NC} Split by environment/team using Terraform workspaces or separate state files"
    echo "  • At hyperscale: consider Terragrunt for DRY code + isolated states"
    echo ""
    echo -e "${BOLD}4. Drift Happens${NC}"
    echo "  • Someone changes a security group in the console → Terraform doesn't know"
    echo "  • Run \`terraform plan\` regularly (or use drift detection tools)"
    echo -e "  • ${GREEN}Pro tip:${NC} Enable AWS Config rules alongside Terraform"
    echo ""
    echo -e "${BOLD}5. The Kubernetes Terraform Boundary${NC}"
    echo "  • Most teams draw the line at: Terraform manages the EKS cluster"
    echo "  • App deployments, services, ingress → Helm/ArgoCD/Kustomize"
    echo -e "  • This ${BOLD}hybrid workflow${NC} prevents Terraform from becoming a bottleneck"
    echo ""; pause_for_effect
}

teach_operational_reality() {
    log_lesson "OPERATIONAL REALITY — What Breaks at 3 AM?"
    echo -e "${BOLD}Every architecture has failure modes. Terraform helps... and hinders.${NC}"
    echo ""
    echo -e "${BOLD}Common failures at your scale:${NC}"
    echo -e "  • ${RED}Instance termination${NC} — ASG replaces it, but stateful data is lost"
    echo -e "  • ${RED}DB connection exhaustion${NC} — need connection pooling (RDS Proxy)"
    echo -e "  • ${RED}AZ outage${NC} — Multi-AZ helps, but cross-AZ latency costs add up"
    echo -e "  • ${RED}Terraform state corruption${NC} — use S3 backend + DynamoDB lock ${BOLD}(critical!)${NC}"
    echo -e "  • ${RED}Drift detection${NC} — manual console changes break Terraform's state"
    echo ""
    echo -e "${BOLD}How Terraform helps:${NC}"
    echo "  ✓ Infrastructure as Code = reproducible, reviewable, version-controlled"
    echo "  ✓ Drift detection via \`terraform plan\` catches manual changes"
    echo "  ✓ State locking prevents concurrent modifications"
    echo "  ✓ Modules enforce consistency across environments"
    echo ""
    echo -e "${BOLD}How Terraform hinders:${NC}"
    echo "  ✗ Large state files slow down plan/apply (split into workspaces)"
    echo "  ✗ State file is a single point of truth — protect it!"
    echo "  ✗ Doesn't manage what's inside the instance (use Ansible/Packer/user_data)"
    echo "  ✗ Rollbacks are manual — Terraform doesn't \"undo\" easily; plan before apply"
    echo ""; pause_for_effect
}

# ────────────────────────────────────────────────────────────
# DOCUMENTATION GENERATION FUNCTIONS
# ────────────────────────────────────────────────────────────
generate_prerequisites_md() {
    local path="$1"
    local scenario_name="${SCENARIO_NAMES[$SCENARIO_ID]}"
    local cost_estimate="${ESTIMATED_COSTS[$SCENARIO_ID]:-\$500–\$5,000/mo}"
    
    cat > "$path/PREREQUISITES.md" << EOF
# Prerequisites for: $scenario_name

## 📋 Before You Deploy

### 1. Required Tools
\`\`\`bash
aws --version        # AWS CLI (required)
terraform --version  # Terraform >= 1.6.0 (required)
kubectl version      # kubectl (for EKS scenarios)
helm version         # Helm (for hybrid workflow)
\`\`\`

### 2. AWS Configuration
\`\`\`bash
aws configure
# You'll need:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: $region
\`\`\`

### 3. Estimated Cost
\`\`\`
Monthly estimate: $cost_estimate
\`\`\`
**⚠️ Always run \`terraform destroy\` when done learning!**

### 4. Deployment Commands
\`\`\`bash
cd $(basename "$path")
terraform init
terraform plan
terraform apply
terraform destroy
\`\`\`
EOF
    log_info "Generated PREREQUISITES.md"
}

generate_cheatsheet() {
    local path="$1"
    cat > "$path/CHEATSHEET.md" << 'CHEAT'
# Quick Commands for This Project
- Init: `terraform init`
- Plan: `terraform plan -out=tfplan`
- Apply: `terraform apply tfplan`
- Destroy: `terraform destroy -auto-approve`
- SSH: `ssh -i <key>.pem ec2-user@<public_ip>`
- Monitoring: Grafana at `http://<public_ip>:3000` (admin/admin)
CHEAT
    log_info "Generated CHEATSHEET.md"
}

generate_adr() {
    local path="$1"
    cat > "$path/ADR-001-architecture-decision.md" << EOF
# ADR-001: Architecture Decision for ${SCENARIO_NAMES[$SCENARIO_ID]}

## Status
Accepted

## Context
- System Type: $SYS_TYPE
- Expected Scale: $USERS users/devices/events
- Kubernetes: $USE_KUBERNETES

## Decision
We chose the **${SCENARIO_NAMES[$SCENARIO_ID]}** pattern.

## Alternatives Considered
$(case "$SYS_TYPE" in
    webapp) echo "- Lambda + API Gateway: Rejected - cold starts unacceptable" ;;
esac)

## Consequences
- **Positive**: Production-grade, scalable
- **Negative**: $(case "$SCENARIO_ID" in
    webapp_micro) echo "Single point of failure" ;;
    *) echo "Operational complexity increased" ;;
esac)

---
Generated: $TIMESTAMP
EOF
    log_info "Generated Architecture Decision Record"
}

generate_ci_cd_pipeline() {
    local path="$1"
    create_directory "$path/.github/workflows"
    
    cat > "$path/.github/workflows/terraform.yml" << 'EOF'
name: "Terraform CI/CD"

on:
  pull_request:
    branches: [main]
    paths: ["**.tf"]
  push:
    branches: [main]
    paths: ["**.tf"]

jobs:
  terraform:
    name: "Terraform Plan & Apply"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform Init
        run: terraform init
      - name: Terraform Plan
        run: terraform plan -no-color
      - name: Terraform Apply
        if: github.event_name == 'push'
        run: terraform apply -auto-approve
EOF
    log_info "Generated CI/CD pipeline"
}

# ────────────────────────────────────────────────────────────
# SCENARIO SELECTION
# ────────────────────────────────────────────────────────────
select_scenario() {
    echo -e "\n${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  STEP 1: WHAT ARE YOU BUILDING?${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}\n"
    echo -e "Choose your system type:"
    echo -e "  ${BOLD}1)${NC} Web Application (monolith → microservices → global)"
    echo -e "  ${BOLD}2)${NC} Microservices Platform (distributed from day one)"
    echo -e "  ${BOLD}3)${NC} Data Pipeline (ETL, streaming, batch processing)"
    echo -e "  ${BOLD}4)${NC} IoT Backend (device ingestion, telemetry)"

    local sys_choice=$(read_input "Select system type (1-4)" "1")
    case $sys_choice in
        1) SYS_TYPE="webapp" ;;
        2) SYS_TYPE="microservices" ;;
        3) SYS_TYPE="pipeline" ;;
        4) SYS_TYPE="iot" ;;
        *) SYS_TYPE="webapp" ;;
    esac
    echo -e "\n${GREEN}Selected: $SYS_TYPE${NC}"

    echo -e "\n${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  STEP 2: WHAT'S YOUR EXPECTED SCALE?${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}\n"
    echo -e "Concurrent users (or events/sec for pipelines, devices for IoT):"
    echo -e "  ${BOLD}1)${NC} 1k       — Prototype, MVP, learning project"
    echo -e "  ${BOLD}2)${NC} 10k      — Growing startup, small business"
    echo -e "  ${BOLD}3)${NC} 100k     — Established product, high traffic"
    echo -e "  ${BOLD}4)${NC} 1M+      — Enterprise, global platform"

    local scale_choice=$(read_input "Select scale (1-4)" "1")
    case $scale_choice in
        1) USERS=1000 ;;
        2) USERS=10000 ;;
        3) USERS=100000 ;;
        4) USERS=1000000 ;;
        *) USERS=1000 ;;
    esac

    TIER=$(determine_tier "$USERS")
    SCENARIO_ID="${SYS_TYPE}_${TIER}"

    # Fallback mapping
    if [[ -z "${SCENARIO_NAMES[$SCENARIO_ID]:-}" ]]; then
        if [[ "$SYS_TYPE" == "pipeline" ]]; then
            if [[ "$TIER" == "micro" || "$TIER" == "small" ]]; then
                SCENARIO_ID="webapp_${TIER}"
                log_warn "Data Pipeline at this scale maps to single-instance pattern. Using Web App template as base."
            elif [[ "$TIER" == "medium" ]]; then
                SCENARIO_ID="pipeline_medium"
            else
                SCENARIO_ID="pipeline_large"
            fi
        elif [[ "$SYS_TYPE" == "iot" ]]; then
            if [[ "$TIER" == "micro" || "$TIER" == "small" || "$TIER" == "medium" ]]; then
                SCENARIO_ID="webapp_${TIER}"
                log_warn "IoT at this scale maps to standard web pattern. Using Web App template."
            elif [[ "$TIER" == "large" || "$TIER" == "xlarge" ]]; then
                SCENARIO_ID="iot_xlarge"
            else
                SCENARIO_ID="iot_enterprise"
            fi
        elif [[ "$SYS_TYPE" == "microservices" ]]; then
            if [[ "$TIER" == "micro" || "$TIER" == "small" ]]; then
                SCENARIO_ID="webapp_${TIER}"
                log_warn "Microservices at small scale is overkill. Using simpler architecture."
            elif [[ "$TIER" == "medium" ]]; then
                SCENARIO_ID="microservices_medium"
            elif [[ "$TIER" == "large" ]]; then
                SCENARIO_ID="microservices_large"
            else
                SCENARIO_ID="microservices_xlarge"
            fi
        else
            SCENARIO_ID="webapp_${TIER}"
        fi
    fi

    echo -e "\n${GREEN}✅ Scenario: ${SCENARIO_NAMES[$SCENARIO_ID]}${NC}"
    echo -e "${GRAY}   Tier: $TIER | Users: $USERS | Type: $SYS_TYPE${NC}\n"
}

show_recommendations() {
    local scenario_name="${SCENARIO_NAMES[$SCENARIO_ID]}"
    local cost_estimate="${ESTIMATED_COSTS[$SCENARIO_ID]:-\$500–\$5,000/mo}"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${CYAN}║  SCENARIO: ${scenario_name}"
    echo -e "${CYAN}║  Tier: $TIER | Users: $USERS | K8s: $USE_KUBERNETES"
    echo -e "${CYAN}║  Estimated Cost: $cost_estimate"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case "$SCENARIO_ID" in
        webapp_micro|webapp_small)
            echo -e "📊 ${BOLD}Single Instance Pattern${NC}"
            echo "Resources: 1x EC2, Security Group, optional Monitoring"
            echo "Cost: \$0–\$50/mo (free tier applicable)"
            echo "Best for: Learning, MVPs, internal tools" ;;
        webapp_medium|pipeline_medium)
            echo -e "📊 ${BOLD}Auto-Scaling + Managed DB Pattern${NC}"
            echo "Resources: ASG (2-6 instances), ALB, RDS Multi-AZ, ElastiCache"
            echo "Cost: ~\$500–\$1,000/mo"
            echo "Best for: Production, high availability required" ;;
        webapp_large|microservices_medium|microservices_large|pipeline_large)
            echo -e "📊 ${BOLD}Container Orchestration Pattern${NC}"
            echo "Resources: ECS/EKS, ALB, Aurora, ElastiCache, CloudFront"
            echo "Cost: ~\$1,500–\$5,000/mo"
            echo "Best for: Microservices, rapid deployment cycles" ;;
        webapp_xlarge|microservices_xlarge|iot_xlarge)
            echo -e "📊 ${BOLD}Distributed Platform Pattern${NC}"
            echo "Resources: EKS (multi-node group), Aurora Global, ElastiCache, WAF"
            echo "Cost: ~\$5,000–\$20,000/mo"
            echo "Best for: High-traffic platforms, global user base" ;;
        webapp_enterprise|iot_enterprise|webapp_hyperscale)
            echo -e "📊 ${BOLD}Global / Enterprise Pattern${NC}"
            echo "Resources: Multi-region EKS, Aurora Global Database, CloudFront, Route53"
            echo "Cost: \$20,000–\$150,000+/mo"
            echo "Best for: Enterprise, global scale, compliance requirements" ;;
    esac
    echo ""
}

# ────────────────────────────────────────────────────────────
# ENHANCED INPUT GATHERING WITH VALIDATION
# ────────────────────────────────────────────────────────────
gather_common_inputs() {
    log_section "AWS CONFIGURATION"
    
    # AWS Profile support
    if [[ -z "$AWS_PROFILE" ]]; then
        if confirm "Use a specific AWS profile (other than default)?" "n"; then
            read -r -p "Enter profile name: " AWS_PROFILE
            export AWS_PROFILE
            log_info "Using AWS profile: $AWS_PROFILE"
        fi
    else
        log_info "Using existing AWS_PROFILE=$AWS_PROFILE"
    fi
    
    # Region selection
    echo -e "${BOLD}Select AWS Region:${NC}"
    echo "  1) us-east-1      (N. Virginia)"
    echo "  2) us-west-2      (Oregon)"
    echo "  3) eu-west-1      (Ireland)"
    echo "  4) eu-central-1   (Frankfurt)"
    echo "  5) ap-southeast-1 (Singapore)"
    echo "  6) ap-northeast-1 (Tokyo)"
    echo "  7) sa-east-1      (São Paulo)"
    echo "  8) Custom"
    local region_choice=$(read_input "Select region (1-8)" "1")
    case $region_choice in
        1) region="us-east-1" ;;
        2) region="us-west-2" ;;
        3) region="eu-west-1" ;;
        4) region="eu-central-1" ;;
        5) region="ap-southeast-1" ;;
        6) region="ap-northeast-1" ;;
        7) region="sa-east-1" ;;
        8) region=$(read_input "Enter any region code (e.g., ap-south-1)" "us-east-1") ;;
        *) region="us-east-1" ;;
    esac
    log_info "Region: $region"
    
    # Key pair
    echo ""
    echo -e "${BOLD}EC2 Key Pair:${NC}"
    echo -e "${GRAY}List of your existing key pairs:${NC}"
    if [[ "$HAS_AWS_CLI" == "true" ]]; then
        aws ec2 describe-key-pairs --region "$region" --query 'KeyPairs[*].KeyName' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/  • /' || echo "  (none found)"
    fi
    echo ""
    
    echo -e "${YELLOW}💡 Tip:${NC} You can use SSM Session Manager to avoid SSH keys altogether (requires IAM role).\n"
    
    while true; do
        key_name=$(read_input "EC2 Key Pair name (must exist in $region)" "")
        if [[ -n "$key_name" ]]; then
            if [[ "$HAS_AWS_CLI" == "true" ]]; then
                if aws ec2 describe-key-pairs --region "$region" --key-names "$key_name" &>/dev/null; then
                    log_info "Key pair '$key_name' found in $region"
                    break
                else
                    log_warn "Key pair '$key_name' not found in $region"
                    if confirm "Create new key pair '$key_name'?" "n"; then
                        aws ec2 create-key-pair --region "$region" --key-name "$key_name" --query 'KeyMaterial' --output text > "${key_name}.pem"
                        chmod 400 "${key_name}.pem"
                        log_info "Created key pair: ${key_name}.pem (keep this file safe!)"
                        break
                    fi
                fi
            else
                break
            fi
        else
            log_error "Key name cannot be empty"
        fi
    done
    
    # VPC
    echo ""
    echo -e "${BOLD}VPC Configuration:${NC}"
    echo -e "${GRAY}Your existing VPCs in $region:${NC}"
    if [[ "$HAS_AWS_CLI" == "true" ]]; then
        aws ec2 describe-vpcs --region "$region" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null | head -5 | sed 's/^/  • /' || echo "  (none found)"
    fi
    echo ""
    
    echo -e "${YELLOW}💡 Explanation:${NC} VPC is your isolated network. It must have an Internet Gateway if you want the instance to be publicly accessible.\n"
    
    while true; do
        vpc_id=$(read_input "VPC ID (vpc-xxxxxxxx, or 'new' to create one)" "new")
        if [[ "$vpc_id" == "new" ]]; then
            if [[ "$SCENARIO_ID" =~ webapp_micro|webapp_small ]]; then
                log_error "Single-instance scenarios require an existing VPC."
                log_info "Create a VPC first: aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $region"
            else
                vpc_id="module.vpc.vpc_id"
                subnet_id="module.vpc.public_subnets[0]"
                log_info "VPC will be created automatically"
                break
            fi
        elif [[ "$vpc_id" =~ ^vpc-[a-f0-9]+$ ]]; then
            if [[ "$HAS_AWS_CLI" == "true" ]]; then
                if aws ec2 describe-vpcs --region "$region" --vpc-ids "$vpc_id" &>/dev/null; then
                    log_info "VPC $vpc_id verified"
                    break
                else
                    log_error "VPC $vpc_id not found in $region"
                fi
            else
                break
            fi
        else
            log_error "Invalid VPC ID format (must be vpc-xxxxxxxx)"
        fi
    done
    
    # Subnet (only if using existing VPC)
    if [[ "$vpc_id" != "module.vpc.vpc_id" ]]; then
        echo ""
        echo -e "${GRAY}Subnets in VPC $vpc_id:${NC}"
        if [[ "$HAS_AWS_CLI" == "true" ]]; then
            aws ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output text 2>/dev/null | sed 's/^/  • /' || echo "  (none found)"
        fi
        echo ""
        
        echo -e "${YELLOW}💡 Explanation:${NC} The subnet determines the AZ and whether the instance gets a public IP (public subnet = auto‑assign public IP enabled).\n"
        
        while true; do
            subnet_id=$(read_input "Subnet ID (subnet-xxxxxxxx)" "")
            if [[ "$subnet_id" =~ ^subnet-[a-f0-9]+$ ]]; then
                if [[ "$HAS_AWS_CLI" == "true" ]]; then
                    if aws ec2 describe-subnets --region "$region" --subnet-ids "$subnet_id" &>/dev/null; then
                        log_info "Subnet $subnet_id verified"
                        break
                    else
                        log_error "Subnet $subnet_id not found in $region"
                    fi
                else
                    break
                fi
            else
                log_error "Invalid Subnet ID format (must be subnet-xxxxxxxx)"
            fi
        done
    fi
    
    # SSH restriction
    echo ""
    my_ip=$(get_public_ip)
    if confirm "Restrict SSH access to your IP ($my_ip)?" "y"; then
        ssh_cidr="${my_ip}/32"
        log_info "SSH restricted to $ssh_cidr"
    else
        ssh_cidr="0.0.0.0/0"
        log_warn "SSH open to all IPs — NOT recommended for production!"
    fi
    
    # Project name
    echo ""
    proj_name=$(read_input "Project name" "myapp")
    proj_name=$(echo "$proj_name" | sed 's/[^a-zA-Z0-9_-]/-/g')
    
    # Monitoring for single-instance
    if [[ "$SCENARIO_ID" == "webapp_micro" || "$SCENARIO_ID" == "webapp_small" ]]; then
        if confirm "Install monitoring stack (Prometheus+Grafana)?" "y"; then
            install_monitoring=true
        else
            install_monitoring=false
        fi
    else
        install_monitoring=false
    fi
}

# ────────────────────────────────────────────────────────────
# TERRAFORM GENERATORS (KEPT FROM ORIGINAL)
# ────────────────────────────────────────────────────────────
generate_modules() {
    local base="$1"
    local force="${2:-false}"
    
    # EC2 module
    local ec2_dir="$base/modules/ec2-instance"
    create_directory "$ec2_dir"
    cat > "$ec2_dir/main.tf" << 'EOF'
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : null
  associate_public_ip_address = var.associate_public_ip
  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    delete_on_termination = true
    encrypted = true
  }
  user_data = var.user_data
  credit_specification {
    cpu_credits = var.cpu_credits
  }
  lifecycle {
    ignore_changes = [ami, user_data]
  }
  tags = merge(var.tags, { Name = var.instance_name })
}

resource "aws_eip" "this" {
  count  = var.associate_eip ? 1 : 0
  domain = "vpc"
}

resource "aws_eip_association" "this" {
  count         = var.associate_eip ? 1 : 0
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this[0].id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ec2/${var.instance_name}"
  retention_in_days = var.log_retention_days
}
EOF

    cat > "$ec2_dir/variables.tf" << 'EOF'
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string; sensitive = true }
variable "iam_instance_profile_name" { type = string; default = "" }
variable "associate_public_ip" { type = bool; default = true }
variable "associate_eip" { type = bool; default = false }
variable "root_volume_type" { type = string; default = "gp3" }
variable "root_volume_size" { type = number; default = 20 }
variable "cpu_credits" { type = string; default = "standard" }
variable "log_retention_days" { type = number; default = 7 }
variable "user_data" { type = string; default = "" }
variable "instance_name" { type = string }
variable "tags" { type = map(string); default = {} }
EOF

    cat > "$ec2_dir/outputs.tf" << 'EOF'
output "instance_id" { value = aws_instance.this.id }
output "instance_public_ip" { value = try(aws_eip.this[0].public_ip, aws_instance.this.public_ip) }
output "instance_private_ip" { value = aws_instance.this.private_ip }
EOF

    # Security Group module
    local sg_dir="$base/modules/security-groups"
    create_directory "$sg_dir"
    cat > "$sg_dir/main.tf" << 'EOF'
resource "aws_security_group" "this" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = var.vpc_id
  lifecycle { create_before_destroy = true }
  tags = merge(var.tags, { Name = var.sg_name })
}

resource "aws_security_group_rule" "ingress" {
  for_each          = { for idx, rule in var.ingress_rules : idx => rule }
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = try(each.value.cidr_blocks, null)
}

resource "aws_security_group_rule" "egress" {
  count             = var.allow_all_egress ? 1 : 0
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
EOF

    cat > "$sg_dir/variables.tf" << 'EOF'
variable "sg_name" { type = string }
variable "sg_description" { type = string }
variable "vpc_id" { type = string }
variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string))
  }))
  default = []
}
variable "allow_all_egress" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }
EOF

    cat > "$sg_dir/outputs.tf" << 'EOF'
output "security_group_id" { value = aws_security_group.this.id }
output "security_group_name" { value = aws_security_group.this.name }
EOF
}

generate_single_instance_terraform() {
    local path="$1"
    local instance_type="$2"
    local volume_size="$3"
    local monitoring="$4"

    log_info "Generating modular single-instance Terraform at $path"
    create_directory "$path"

    # Build ingress rules as proper JSON array
    local ports=(22 80 443 3000 9090)
    local ingress_json="["
    local first=true
    for port in "${ports[@]}"; do
        local cidr="0.0.0.0/0"
        [[ "$port" == "22" ]] && cidr="$ssh_cidr"
        if [[ "$first" != "true" ]]; then
            ingress_json+=","
        fi
        first=false
        ingress_json+="
    {
      description = \"Port $port\"
      from_port   = $port
      to_port     = $port
      protocol    = \"tcp\"
      cidr_blocks = [\"$cidr\"]
    }"
    done
    ingress_json+="
  ]"

    cat > "$path/main.tf" << MAINEOF
# ============================================================
# MODULAR SINGLE-INSTANCE TERRAFORM
# Scenario: ${SCENARIO_NAMES[$SCENARIO_ID]}
# Tier: $TIER | Users: $USERS
# ============================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.instance_name
    }
  }
}

data "aws_vpc" "selected" { id = var.vpc_id }
data "aws_subnet" "selected" { id = var.subnet_id }

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "security_group" {
  source = "./modules/security-groups"
  sg_name        = "\${var.instance_name}-sg"
  sg_description = "SG for \${var.instance_name}"
  vpc_id         = var.vpc_id
  ingress_rules  = var.ingress_rules
  allow_all_egress = true
  tags = { Name = "\${var.instance_name}-sg" }
}

module "ec2_instance" {
  source = "./modules/ec2-instance"
  ami_id               = data.aws_ami.amazon_linux_2.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  security_group_ids   = [module.security_group.security_group_id]
  key_name             = var.key_name
  associate_public_ip  = true
  associate_eip        = false
  root_volume_size     = var.root_volume_size
  root_volume_type     = "gp3"
  cpu_credits          = "standard"
  log_retention_days   = 7
  user_data            = templatefile("\${path.module}/user_data.sh", { install_monitoring = var.install_monitoring, instance_name = var.instance_name })
  instance_name        = var.instance_name
  iam_instance_profile_name = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : ""
  tags = { Environment = var.environment }
}

resource "aws_iam_role" "ec2_role" {
  count = var.create_iam_role ? 1 : 0
  name  = "\${var.instance_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.create_iam_role ? 1 : 0
  name  = "\${var.instance_name}-profile"
  role  = aws_iam_role.ec2_role[0].name
}

output "public_ip" { value = module.ec2_instance.instance_public_ip }
output "ssh_command" { value = "ssh -i \${var.key_name}.pem ec2-user@\${module.ec2_instance.instance_public_ip}" }
output "grafana_url" { value = var.install_monitoring ? "http://\${module.ec2_instance.instance_public_ip}:3000 (admin/admin)" : "Not installed" }
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" { type = string; default = "$region" }
variable "environment" { type = string; default = "learning" }
variable "instance_type" { type = string; default = "$instance_type" }
variable "instance_name" { type = string; default = "$proj_name" }
variable "root_volume_size" { type = number; default = $volume_size }
variable "vpc_id" { type = string; default = "$vpc_id" }
variable "subnet_id" { type = string; default = "$subnet_id" }
variable "key_name" { type = string; default = "$key_name"; sensitive = true }
variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = $ingress_json
}
variable "install_monitoring" { type = bool; default = $monitoring }
variable "create_iam_role" { type = bool; default = true }
VARS

    cat > "$path/user_data.sh" << 'USERDATA'
#!/bin/bash
set -euo pipefail
INSTALL_MONITORING=${install_monitoring}
INSTANCE_NAME=${instance_name}
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Bootstrapping $INSTANCE_NAME"
yum update -y
yum install -y docker git jq htop
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

if [ "$INSTALL_MONITORING" = "true" ]; then
  cd /tmp
  curl -sLO https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-*.linux-amd64.tar.gz
  tar -xf node_exporter-*.linux-amd64.tar.gz
  mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
  cat <<EOF2 > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOF2
  systemctl enable --now node_exporter

  mkdir -p /home/ec2-user/monitoring
  cat <<EOF3 > /home/ec2-user/monitoring/docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports: ["9090:9090"]
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml", "prom-data:/prometheus"]
  grafana:
    image: grafana/grafana:latest
    ports: ["3000:3000"]
    environment: [GF_SECURITY_ADMIN_PASSWORD=admin]
volumes:
  prom-data:
EOF3
  cat <<EOF4 > /home/ec2-user/monitoring/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF4
  cd /home/ec2-user/monitoring
  docker-compose up -d
  chown -R ec2-user:ec2-user /home/ec2-user/monitoring
fi
echo "Bootstrap complete."
USERDATA
    chmod +x "$path/user_data.sh"

    generate_modules "$path" "$FORCE_OVERWRITE"
    log_info "Modular single-instance Terraform generated."
}

generate_asg_terraform() {
    local path="$1"
    local instance_type="$2"
    local asg_min="$3"
    local asg_max="$4"
    local db_class="$5"

    log_info "Generating ASG Terraform at $path"
    create_directory "$path"

    cat > "$path/main.tf" << MAINEOF
# ============================================================
# AUTO-SCALING GROUP + RDS TERRAFORM
# Scenario: ${SCENARIO_NAMES[$SCENARIO_ID]}
# Tier: $TIER | Users: $USERS
# ============================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
    random = { source = "hashicorp/random"; version = "~> 3.5" }
  }
}

provider "aws" { region = var.aws_region }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  name = "\${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["\${var.aws_region}a", "\${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_security_group" "alb" {
  name   = "\${var.project_name}-alb-sg"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "app" {
  name   = "\${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 8080; to_port = 8080; protocol = "tcp"; security_groups = [aws_security_group.alb.id] }
  ingress { from_port = 22; to_port = 22; protocol = "tcp"; cidr_blocks = ["$ssh_cidr"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "db" {
  name   = "\${var.project_name}-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 5432; to_port = 5432; protocol = "tcp"; security_groups = [aws_security_group.app.id] }
}

resource "aws_lb" "app" {
  name               = "\${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "app" {
  name     = "\${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action { type = "forward"; target_group_arn = aws_lb_target_group.app.arn }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name"; values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
}

resource "aws_launch_template" "app" {
  name_prefix   = "\${var.project_name}-lt"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "$instance_type"
  user_data     = base64encode(templatefile("\${path.module}/user_data.sh", { project_name = var.project_name }))
  vpc_security_group_ids = [aws_security_group.app.id]
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "\${var.project_name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "\${var.project_name}-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  min_size            = $asg_min
  max_size            = $asg_max
  desired_capacity    = $asg_min
  launch_template { id = aws_launch_template.app.id; version = "\$Latest" }
  target_group_arns = [aws_lb_target_group.app.arn]
  tag { key = "Name"; value = "\${var.project_name}-app"; propagate_at_launch = true }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "\${var.project_name}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 70.0
  }
}

resource "aws_db_instance" "app" {
  identifier     = "\${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "$db_class"
  allocated_storage = 50
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  multi_az = true
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.app.name
  backup_retention_period = 7
  skip_final_snapshot = false
}

resource "random_password" "db" { length = 16; special = false }

resource "aws_db_subnet_group" "app" {
  name       = "\${var.project_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

output "alb_dns" { value = aws_lb.app.dns_name }
output "db_endpoint" { value = aws_db_instance.app.endpoint }
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" { type = string; default = "$region" }
variable "project_name" { type = string; default = "$proj_name" }
variable "environment" { type = string; default = "production" }
variable "db_name" { type = string; default = "appdb" }
variable "db_username" { type = string; default = "admin" }
VARS

    cat > "$path/user_data.sh" << 'USERDATA'
#!/bin/bash
set -euo pipefail
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
USERDATA
    chmod +x "$path/user_data.sh"
}

generate_eks_terraform() {
    local path="$1"
    local instance_type="$2"
    local asg_min="$3"
    local asg_max="$4"

    log_info "Generating EKS Terraform at $path"
    create_directory "$path"

    cat > "$path/main.tf" << MAINEOF
# ============================================================
# EKS KUBERNETES TERRAFORM
# Scenario: ${SCENARIO_NAMES[$SCENARIO_ID]}
# Tier: $TIER | Users: $USERS | Hybrid: $USE_HYBRID
# ============================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes"; version = "~> 2.0" }
    helm = { source = "hashicorp/helm"; version = "~> 2.0" }
    random = { source = "hashicorp/random"; version = "~> 3.5" }
  }
}

provider "aws" { region = var.aws_region }

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  name = "\${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
  azs = ["\${var.aws_region}a", "\${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.0"
  cluster_name    = "\${var.project_name}-eks"
  cluster_version = "1.27"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  eks_managed_node_groups = {
    main = {
      desired_size = $asg_min
      max_size     = $asg_max
      min_size     = 2
      instance_types = ["$instance_type"]
    }
  }
}

resource "aws_db_instance" "app" {
  identifier     = "\${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.r5.large"
  allocated_storage = 100
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  multi_az = true
  vpc_security_group_ids = [module.eks.node_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.app.name
  backup_retention_period = 7
  skip_final_snapshot = false
}

resource "random_password" "db" { length = 16; special = false }

resource "aws_db_subnet_group" "app" {
  name       = "\${var.project_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "configure_kubectl" { value = "aws eks update-kubeconfig --name \${var.project_name}-eks --region \${var.aws_region}" }
output "db_endpoint" { value = aws_db_instance.app.endpoint }
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" { type = string; default = "$region" }
variable "project_name" { type = string; default = "$proj_name" }
variable "environment" { type = string; default = "production" }
variable "db_name" { type = string; default = "appdb" }
variable "db_username" { type = string; default = "admin" }
VARS

    if [[ "$USE_HYBRID" == "true" ]]; then
        create_directory "$path/helm-charts/example-app/templates"
        cat > "$path/helm-charts/example-app/Chart.yaml" << 'HELM'
apiVersion: v2
name: example-app
version: 0.1.0
description: Example Helm chart for hybrid Terraform+K8s workflow
HELM
        cat > "$path/helm-charts/example-app/values.yaml" << 'HELM'
replicaCount: 3
image: nginx:latest
service:
  type: LoadBalancer
  port: 80
HELM
        cat > "$path/helm-charts/example-app/templates/deployment.yaml" << 'HELM'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: app
          image: {{ .Values.image }}
          ports:
            - containerPort: 80
HELM
        log_info "Hybrid Helm chart example generated."
    fi

    cat > "$path/user_data.sh" << 'USERDATA'
#!/bin/bash
set -euo pipefail
yum update -y
USERDATA
    chmod +x "$path/user_data.sh"
}

# ────────────────────────────────────────────────────────────
# POST-DEPLOYMENT VERIFICATION
# ────────────────────────────────────────────────────────────
verify_deployment() {
    log_section "POST‑DEPLOYMENT VERIFICATION"
    
    # Check EC2 instance
    if grep -q "aws_instance" "terraform.tfstate" 2>/dev/null; then
        local pub_ip=$(terraform output -raw public_ip 2>/dev/null || terraform output -raw instance_public_ip 2>/dev/null)
        if [[ -n "$pub_ip" && "$pub_ip" != "null" ]]; then
            echo "Testing HTTP connectivity to $pub_ip ..."
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$pub_ip" 2>/dev/null || echo "000")
            if [[ "$http_code" =~ ^(200|301|302|303|304)$ ]]; then
                log_info "Web server responded OK (HTTP $http_code)"
            else
                log_warn "Web server not responding (HTTP $http_code) - may need time to bootstrap"
            fi
        fi
    fi
    
    # Check ALB
    if grep -q "aws_lb" "terraform.tfstate" 2>/dev/null; then
        local alb_dns=$(terraform output -raw alb_dns 2>/dev/null)
        if [[ -n "$alb_dns" ]]; then
            log_info "ALB endpoint: http://$alb_dns"
        fi
    fi
    
    echo ""
    echo -e "${RED}⚠️  REMEMBER TO CLEAN UP!${NC}"
    echo -e "  Run: ${GREEN}terraform destroy -auto-approve${NC} when done testing.\n"
}

# ────────────────────────────────────────────────────────────
# DEPLOY AND TEACH
# ────────────────────────────────────────────────────────────
deploy_and_teach() {
    local dir="$1"
    cd "$dir"

    log_lesson "DEPLOYMENT — Idempotent & Safe to Re-Run"

    if ! command -v terraform &>/dev/null; then
        log_warn "Terraform not found. Files generated at: $dir"
        echo -e "${YELLOW}Run: cd $dir && terraform init && terraform plan && terraform apply${NC}"
        return
    fi

    if [[ -f "terraform.tfstate" ]] && [[ -s "terraform.tfstate" ]]; then
        log_warn "Existing state found. Running plan to check for changes..."
        terraform plan || true
        if confirm "State exists. Apply any changes?" "n"; then
            terraform apply -auto-approve
            log_info "Changes applied."
        else
            log_info "Skipping apply."
        fi
    else
        log_info "Initializing Terraform..."
        terraform init
        echo -e "\n${CYAN}📋 TERRAFORM PLAN${NC}\n"
        terraform plan
        if [[ "$AUTO_DEPLOY" == "true" ]] || confirm "Apply this infrastructure now?" "y"; then
            echo -e "\n${GREEN}🚀 Applying Terraform...${NC}"
            terraform apply -auto-approve
            log_info "Infrastructure deployed successfully!"
            terraform output
        else
            log_info "Skipping apply. Deploy when ready."
        fi
    fi
}

# ────────────────────────────────────────────────────────────
# MAIN
# ────────────────────────────────────────────────────────────
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) FORCE_OVERWRITE=true ;;
            --skip-prompts) SKIP_PROMPTS=true ;;
            --auto-deploy) AUTO_DEPLOY=true ;;
            --help|-h)
                echo "Usage: $SCRIPT_NAME [--force] [--skip-prompts] [--auto-deploy]"
                exit 0 ;;
            *) log_error "Unknown option $1"; exit 1 ;;
        esac
        shift
    done

    print_banner
    print_pre_run_requirements
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    teach_aws_limits
    teach_networking_basics
    teach_instance_types
    
    local completed_count=$(check_journal | tail -1)
    
    select_scenario
    evaluate_well_architected
    check_iam_permissions
    
    teach_architecture_decision
    display_architecture_and_cost
    show_recommendations
    
    teach_kubernetes_decision
    teach_terraform_limitations

    if ! confirm "Generate Terraform configuration for this scenario?" "y"; then
        log_info "Exiting. Run again with different choices!"
        exit 0
    fi

    teach_cost_optimization
    teach_disaster_recovery

    gather_common_inputs
    teach_security_best_practices

    # Create project directory
    local PROJ_DIR="infrastructure/terraform/${proj_name}-${SCENARIO_ID}"
    create_directory "$PROJ_DIR"

    # Dispatch to generator
    case "$SCENARIO_ID" in
        webapp_micro)
            generate_single_instance_terraform "$PROJ_DIR" "t3.micro" 30 true ;;
        webapp_small)
            generate_single_instance_terraform "$PROJ_DIR" "t3.medium" 50 true ;;
        webapp_medium|pipeline_medium)
            generate_asg_terraform "$PROJ_DIR" "t3.large" 2 6 "db.t3.medium" ;;
        webapp_large|microservices_medium|pipeline_large)
            if [[ "$USE_KUBERNETES" == "true" ]]; then
                generate_eks_terraform "$PROJ_DIR" "c5.xlarge" 3 15
            else
                generate_asg_terraform "$PROJ_DIR" "c5.xlarge" 3 15 "db.r5.large"
            fi ;;
        webapp_xlarge|microservices_large|microservices_xlarge|iot_xlarge)
            generate_eks_terraform "$PROJ_DIR" "m5.xlarge" 4 30
            USE_KUBERNETES="true" ;;
        webapp_enterprise|iot_enterprise|webapp_hyperscale)
            generate_eks_terraform "$PROJ_DIR" "m5.2xlarge" 6 50
            USE_KUBERNETES="true"
            cat >> "$PROJ_DIR/README.md" << 'README'

# Enterprise / Hyperscale Architecture
For this scale, we recommend:
- Multi-region active-active (duplicate this stack in another region)
- Aurora Global Database for cross-region reads
- Route53 latency-based routing
- CloudFront + WAF at edge
- Terragrunt for managing multiple Terraform states
README
            ;;
        *)
            generate_single_instance_terraform "$PROJ_DIR" "t3.micro" 30 true ;;
    esac

    # Generate documentation
    generate_prerequisites_md "$PROJ_DIR"
    generate_cheatsheet "$PROJ_DIR"
    generate_adr "$PROJ_DIR"
    generate_ci_cd_pipeline "$PROJ_DIR"
    
    teach_observability
    teach_operational_reality
    
    log_session
    
    # Output summary
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${GREEN}║  ✅ TERRAFORM CONFIGURATION READY!                                    ║"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "📁 ${BOLD}Location:${NC} ${PROJ_DIR}"
    echo -e "🎯 ${BOLD}Scenario:${NC} ${SCENARIO_NAMES[$SCENARIO_ID]}"
    echo -e "💰 ${BOLD}Estimated Cost:${NC} ${ESTIMATED_COSTS[$SCENARIO_ID]:-\$500–\$5,000/mo}"
    echo -e "🧠 ${BOLD}Key decisions:${NC} K8s=$USE_KUBERNETES | Hybrid=$USE_HYBRID"
    echo ""
    echo -e "${CYAN}📚 What you learned this session:${NC}"
    echo "  1. Architecture for ${SYS_TYPE} at ${USERS} users"
    echo "  2. AWS Well-Architected Framework assessment"
    echo "  3. Kubernetes justification (or why not)"
    echo "  4. Terraform limitations at this scale"
    echo "  5. Cost optimization strategies"
    echo "  6. Security best practices"
    echo "  7. Operational reality — what breaks and how to prepare"
    echo ""
    echo -e "${YELLOW}🧹 Cleanup when done:${NC}"
    echo "   cd ${PROJ_DIR} && terraform destroy -auto-approve"
    echo ""

    suggest_next_run "$completed_count"
    local new_count=$((completed_count + 1))
    if [[ "$new_count" -ge 5 ]]; then
        echo -e "${GREEN}🏅 MASTERY CHECK: You've now completed ${new_count} sessions.${NC}"
        echo -e "${GREEN}   Can you explain to a colleague:${NC}"
        echo "   • When to use single instance vs ASG vs EKS?"
        echo "   • What Terraform limitations matter at each scale?"
        echo "   • Why the Kubernetes decision isn't automatic?"
        echo "   • How to optimize AWS costs at each tier?"
        echo -e "${GREEN}   If yes — you've mastered cloud architecture decision-making.${NC}"
    fi
    
    show_pro_tip
    echo -e "\n${CYAN}See you next session! Run \`bash $SCRIPT_NAME\` again.${NC}"
    
    if [[ "$AUTO_DEPLOY" == "true" ]] || confirm "Deploy infrastructure now?" "n"; then
        deploy_and_teach "$PROJ_DIR"
        cd "$PROJ_DIR" && verify_deployment
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
