#!/bin/bash
# ============================================================
# K8s Deploy — kubectl apply + Helm upgrade + rollout watch
# Usage: bash deploy-k8s.sh <namespace> <app> [--helm|--kubectl] [--tag=v1.2.3]
# ============================================================
set -e

NAMESPACE="${1:?Usage: deploy-k8s.sh <namespace> <app> [--helm|--kubectl] [--tag=version]}"
APP="${2:?App name required}"
MODE="kubectl"   # default
TAG=""
DRY_RUN=false
ROLLOUT_TIMEOUT=300

# Parse flags
shift 2
for arg in "$@"; do
    case $arg in
        --helm)       MODE="helm" ;;
        --kubectl)    MODE="kubectl" ;;
        --tag=*)      TAG="${arg#*=}" ;;
        --dry-run)    DRY_RUN=true ;;
        --timeout=*)  ROLLOUT_TIMEOUT="${arg#*=}" ;;
    esac
done

echo "☸️  K8s Deploy — $APP → $NAMESPACE ($MODE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Pre-flight checks ─────────────────────────────────────
echo "🔍 Pre-flight..."
kubectl cluster-info --request-timeout=5s >/dev/null 2>&1 || { echo "❌ Cannot reach cluster"; exit 1; }
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || { echo "❌ Namespace $NAMESPACE not found"; exit 1; }

# ── Deploy ─────────────────────────────────────────────────
if [[ "$MODE" == "helm" ]]; then
    RELEASE="${APP}"
    CHART="${CHART_DIR:-./helm/$APP}"

    echo "📦 Helm upgrade $RELEASE from $CHART..."
    if [[ -n "$TAG" ]]; then
        HELM_ARGS="--set image.tag=$TAG"
    fi

    if $DRY_RUN; then
        helm upgrade --install "$RELEASE" "$CHART" \
            --namespace "$NAMESPACE" \
            $HELM_ARGS \
            --dry-run --debug
        echo "✅ Dry run complete (not deployed)"
        exit 0
    fi

    helm upgrade --install "$RELEASE" "$CHART" \
        --namespace "$NAMESPACE" \
        $HELM_ARGS \
        --wait --timeout "${ROLLOUT_TIMEOUT}s"

    echo "✅ Helm release upgraded: $RELEASE"
    helm history "$RELEASE" --namespace "$NAMESPACE" --max 3

else
    # kubectl mode
    MANIFEST="${MANIFEST_DIR:-./k8s}/${APP}.yaml"

    if [[ ! -f "$MANIFEST" ]]; then
        # Try per-namespace directory
        MANIFEST="${MANIFEST_DIR:-./k8s}/${NAMESPACE}/${APP}.yaml"
    fi

    if [[ ! -f "$MANIFEST" ]]; then
        echo "❌ Manifest not found: $MANIFEST"
        echo "   Set MANIFEST_DIR env or place at ./k8s/<app>.yaml"
        exit 1
    fi

    if $DRY_RUN; then
        kubectl apply -f "$MANIFEST" --namespace "$NAMESPACE" --dry-run=client
        echo "✅ Dry run complete (not deployed)"
        exit 0
    fi

    echo "📄 kubectl apply -f $MANIFEST..."
    kubectl apply -f "$MANIFEST" --namespace "$NAMESPACE"

    # Watch rollout if it's a Deployment
    DEPLOY=$(kubectl get deploy -n "$NAMESPACE" -l "app=$APP" -o name 2>/dev/null | head -1)
    if [[ -n "$DEPLOY" ]]; then
        echo "👀 Watching rollout: $DEPLOY..."
        kubectl rollout status "$DEPLOY" -n "$NAMESPACE" --timeout="${ROLLOUT_TIMEOUT}s"
    fi
fi

# ── Verify ─────────────────────────────────────────────────
echo ""
echo "📊 Deployment status:"
kubectl get pods -n "$NAMESPACE" -l "app=$APP" -o wide 2>/dev/null || \
kubectl get pods -n "$NAMESPACE" | grep "$APP"

echo ""
echo "✅ Deploy complete — $APP @ $NAMESPACE"
