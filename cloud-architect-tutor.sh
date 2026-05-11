#!/usr/bin/env bash
# ============================================================
# CLOUD ARCHITECT TUTOR v6.0.1 – MASTERY EDITION FROM BUILDMINTZ
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

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

readonly SCRIPT_VERSION="6.0.1"
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

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { echo -e "${GRAY}[DEBUG]${NC} $*"; }
log_lesson() { echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
               echo -e "${MAGENTA}📚 LESSON:${NC} $*"
               echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

print_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${CYAN}║           BUILDMINTZ CLOUD ARCHITECT TUTOR v${SCRIPT_VERSION}        ║"
    echo -e "${CYAN}║                                                                      ║"
    echo -e "${CYAN}║  Master Terraform, AWS architecture & K8s decisions in 5-10 runs.    ║"
    echo -e "${CYAN}║  ✓ Interactive scenario selection                                    ║"
    echo -e "${CYAN}║  ✓ Teaches tradeoffs at every decision point                        ║"
    echo -e "${CYAN}║  ✓ Generates modular, production‑grade Terraform                    ║"
    echo -e "${CYAN}║  ✓ Tracks your learning journey                                     ║"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
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

# -------------------- Scenario Selection --------------------
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

pause_for_effect() {
    if [[ "$SKIP_PROMPTS" != "true" ]]; then
        read -r -p "$(echo -e "${GRAY}Press Enter to continue...${NC}")" _
    fi
}

show_recommendations() {
    local scenario_name="${SCENARIO_NAMES[$SCENARIO_ID]}"
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${CYAN}║  SCENARIO: ${scenario_name}"
    echo -e "${CYAN}║  Tier: $TIER | Users: $USERS | K8s: $USE_KUBERNETES"
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

gather_common_inputs() {
    echo -e "\n${YELLOW}📋 AWS REGION${NC}"
    echo "  1. us-east-1 (N. Virginia)   2. us-west-2 (Oregon)"
    echo "  3. eu-west-1 (Ireland)       4. ap-southeast-1 (Singapore)"
    local region_choice=$(read_input "Select region (1-4)" "1")
    case $region_choice in
        1) region="us-east-1" ;;
        2) region="us-west-2" ;;
        3) region="eu-west-1" ;;
        4) region="ap-southeast-1" ;;
        *) region="us-east-1" ;;
    esac

    while true; do
        key_name=$(read_input "EC2 Key Pair name (must exist in AWS)" "")
        [[ -n "$key_name" ]] && break
        log_error "Key name cannot be empty"
    done

    while true; do
        vpc_id=$(read_input "VPC ID (vpc-xxxxxxxx, or 'new' to create one)" "new")
        [[ "$vpc_id" == "new" || "$vpc_id" =~ ^vpc-[a-f0-9]+$ ]] && break
        log_error "Invalid VPC ID format"
    done

    if [[ "$vpc_id" == "new" ]]; then
        if [[ "$SCENARIO_ID" =~ webapp_micro|webapp_small ]]; then
            log_error "Single-instance scenarios require an existing VPC and subnet. Please provide a VPC ID."
            exit 1
        else
            vpc_id="module.vpc.vpc_id"
            subnet_id="module.vpc.public_subnets[0]"
        fi
    else
        while true; do
            subnet_id=$(read_input "Subnet ID (subnet-xxxxxxxx)" "")
            [[ "$subnet_id" =~ ^subnet-[a-f0-9]+$ ]] && break
            log_error "Invalid Subnet ID format"
        done
    fi

    my_ip=$(get_public_ip)
    if confirm "Restrict SSH to your IP only?" "y"; then
        ssh_cidr="${my_ip}/32"
    else
        ssh_cidr="0.0.0.0/0"
        log_warn "SSH open to all IPs - not recommended"
    fi

    proj_name=$(read_input "Project name" "myapp")
    proj_name=$(echo "$proj_name" | sed 's/[^a-zA-Z0-9_-]/-/g')

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

# -------------------- Terraform Generators --------------------
generate_modules() {
    local base="$1"
    local force="${2:-false}"
    
    # EC2 module - FIXED: removed semicolons from HCL
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
variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type      = string
  sensitive = true
}

variable "iam_instance_profile_name" {
  type    = string
  default = ""
}

variable "associate_public_ip" {
  type    = bool
  default = true
}

variable "associate_eip" {
  type    = bool
  default = false
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "cpu_credits" {
  type    = string
  default = "standard"
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "user_data" {
  type    = string
  default = ""
}

variable "instance_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

    cat > "$ec2_dir/outputs.tf" << 'EOF'
output "instance_id" {
  value = aws_instance.this.id
}

output "instance_public_ip" {
  value = try(aws_eip.this[0].public_ip, aws_instance.this.public_ip)
}

output "instance_private_ip" {
  value = aws_instance.this.private_ip
}
EOF

    # Security Group module - FIXED: removed semicolons
    local sg_dir="$base/modules/security-groups"
    create_directory "$sg_dir"
    cat > "$sg_dir/main.tf" << 'EOF'
resource "aws_security_group" "this" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = var.vpc_id
  lifecycle {
    create_before_destroy = true
  }
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
variable "sg_name" {
  type = string
}

variable "sg_description" {
  type = string
}

variable "vpc_id" {
  type = string
}

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

variable "allow_all_egress" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
EOF

    cat > "$sg_dir/outputs.tf" << 'EOF'
output "security_group_id" {
  value = aws_security_group.this.id
}

output "security_group_name" {
  value = aws_security_group.this.name
}
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
# Terraform limitation taught:
#   Local state is fine for learning. For production, use S3 backend.
#   This is a "Day 1" architecture; scaling requires ASG/ALB.

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
    }
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

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
  tags = {
    Name = "\${var.instance_name}-sg"
  }
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
  tags = {
    Environment = var.environment
  }
}

# Optional IAM role for SSM & CloudWatch
resource "aws_iam_role" "ec2_role" {
  count = var.create_iam_role ? 1 : 0
  name  = "\${var.instance_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
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

output "public_ip" {
  value = module.ec2_instance.instance_public_ip
}

output "ssh_command" {
  value     = "ssh -i \${var.key_name}.pem ec2-user@\${module.ec2_instance.instance_public_ip}"
  sensitive = true
}
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" {
  type    = string
  default = "$region"
}

variable "environment" {
  type    = string
  default = "learning"
}

variable "instance_type" {
  type    = string
  default = "$instance_type"
}

variable "instance_name" {
  type    = string
  default = "$proj_name"
}

variable "root_volume_size" {
  type    = number
  default = $volume_size
}

variable "vpc_id" {
  type    = string
  default = "$vpc_id"
}

variable "subnet_id" {
  type    = string
  default = "$subnet_id"
}

variable "key_name" {
  type      = string
  default   = "$key_name"
  sensitive = true
}

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

variable "install_monitoring" {
  type    = bool
  default = $monitoring
}

variable "create_iam_role" {
  type    = bool
  default = true
}
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
  # Install Node Exporter
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

  # Docker compose monitoring stack
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

    # Generate reusable modules
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
# Terraform limitation taught:
#   - Large state file: consider S3 backend + state locking
#   - Launch template updates force instance rotation (use lifecycle rules)

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

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
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name   = "\${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["$ssh_cidr"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "\${var.project_name}-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
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
  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "\${var.project_name}-lt"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "$instance_type"
  user_data     = base64encode(templatefile("\${path.module}/user_data.sh", { project_name = var.project_name }))
  vpc_security_group_ids = [aws_security_group.app.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "\${var.project_name}-app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "\${var.project_name}-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  min_size            = $asg_min
  max_size            = $asg_max
  desired_capacity    = $asg_min
  launch_template {
    id      = aws_launch_template.app.id
    version = "\$Latest"
  }
  target_group_arns = [aws_lb_target_group.app.arn]
  tag {
    key                 = "Name"
    value               = "\${var.project_name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "\${var.project_name}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
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

resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_db_subnet_group" "app" {
  name       = "\${var.project_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.app.endpoint
}
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" {
  type    = string
  default = "$region"
}

variable "project_name" {
  type    = string
  default = "$proj_name"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "admin"
}
VARS

    cat > "$path/user_data.sh" << 'USERDATA'
#!/bin/bash
set -euo pipefail
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
# Add your app startup command here, e.g., docker run -d -p 8080:8080 your-image
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
# Terraform + Kubernetes hybrid workflow:
#   Terraform manages: EKS cluster, node groups, IAM, VPC
#   K8s resources (deployments, services) managed by Helm/ArgoCD
#   Boundary: infra in .tf, apps in Helm charts

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

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

resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_db_subnet_group" "app" {
  name       = "\${var.project_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name \${var.project_name}-eks --region \${var.aws_region}"
}

output "db_endpoint" {
  value = aws_db_instance.app.endpoint
}
MAINEOF

    cat > "$path/variables.tf" << VARS
variable "aws_region" {
  type    = string
  default = "$region"
}

variable "project_name" {
  type    = string
  default = "$proj_name"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "admin"
}
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
# Terraform creates the EKS cluster. Helm manages what runs on it.
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
# EKS node user data — minimal; most config via launch template
USERDATA
    chmod +x "$path/user_data.sh"
}

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

# -------------------- Main --------------------
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
    local completed_count=$(check_journal | tail -1)
    select_scenario
    show_recommendations
    teach_kubernetes_decision
    teach_terraform_limitations

    if ! confirm "Generate Terraform configuration for this scenario?" "y"; then
        log_info "Exiting. Run again with different choices!"
        exit 0
    fi

    gather_common_inputs

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

    teach_operational_reality
    log_session
    deploy_and_teach "$PROJ_DIR"

    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "${GREEN}║  ✅ TERRAFORM CONFIGURATION GENERATED & READY                        ║"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "📁 ${BOLD}Project:${NC} ${PROJ_DIR}"
    echo -e "🎯 ${BOLD}Scenario:${NC} ${SCENARIO_NAMES[$SCENARIO_ID]}"
    echo -e "🧠 ${BOLD}Key decisions:${NC} K8s=$USE_KUBERNETES | Hybrid=$USE_HYBRID"
    echo ""
    echo -e "${CYAN}📚 What you learned this session:${NC}"
    echo "  1. Architecture for ${SYS_TYPE} at ${USERS} users"
    echo "  2. Kubernetes justification (or why not)"
    echo "  3. Terraform limitations at this scale"
    echo "  4. Operational reality — what breaks and how to prepare"
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
        echo -e "${GREEN}   If yes — you've mastered cloud architecture decision-making.${NC}"
    fi

    echo -e "\n${CYAN}See you next session! Run \`bash $SCRIPT_NAME\` again.${NC}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi