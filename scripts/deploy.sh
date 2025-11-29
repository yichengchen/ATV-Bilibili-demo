#!/bin/bash

###############################################################################
# 快速部署脚本 - deploy.sh
#
# 简化版部署入口，直接调用 deploy_to_appletv.sh
#
# 使用方法:
#   ./scripts/deploy.sh           # 快速部署
#   ./scripts/deploy.sh --clean   # 清理后部署
#
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/deploy_to_appletv.sh" "$@"
