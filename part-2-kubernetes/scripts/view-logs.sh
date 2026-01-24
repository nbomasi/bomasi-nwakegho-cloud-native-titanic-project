#!/bin/bash

set -euo pipefail

COMPONENT="${1:-api}"
FOLLOW="${2:-false}"
NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Viewing logs for: ${COMPONENT}"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

case "${COMPONENT}" in
    api|app)
        if [ "${FOLLOW}" = "true" ] || [ "${FOLLOW}" = "-f" ]; then
            kubectl logs -f deployment/titanic-api -n ${NAMESPACE} --tail=100
        else
            kubectl logs deployment/titanic-api -n ${NAMESPACE} --tail=100
        fi
        ;;
    db|database)
        if [ "${FOLLOW}" = "true" ] || [ "${FOLLOW}" = "-f" ]; then
            kubectl logs -f deployment/titanic-db -n ${NAMESPACE} --tail=100
        else
            kubectl logs deployment/titanic-db -n ${NAMESPACE} --tail=100
        fi
        ;;
    all)
        echo "--- Application Logs ---"
        kubectl logs deployment/titanic-api -n ${NAMESPACE} --tail=50
        echo ""
        echo "--- Database Logs ---"
        kubectl logs deployment/titanic-db -n ${NAMESPACE} --tail=50
        ;;
    *)
        echo "Usage: $0 [api|db|all] [-f]"
        echo ""
        echo "Examples:"
        echo "  $0 api          # View application logs"
        echo "  $0 db           # View database logs"
        echo "  $0 api -f       # Follow application logs"
        echo "  $0 all          # View all logs"
        exit 1
        ;;
esac
