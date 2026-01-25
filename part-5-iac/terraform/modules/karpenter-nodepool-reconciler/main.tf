resource "kubectl_manifest" "nodepool_reconciler" {
  count = var.enable_nodepool_reconciler ? 1 : 0

  yaml_body = <<-YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: nodepool-reconciler-config
  namespace: kube-system
data:
  nodepool-name: "${var.nodepool_name}"
  reconcile-interval: "${var.reconcile_interval}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodepool-reconciler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nodepool-reconciler
  template:
    metadata:
      labels:
        app: nodepool-reconciler
    spec:
      serviceAccountName: nodepool-reconciler
      containers:
      - name: reconciler
        image: bitnami/kubectl:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            PATCH_CONFIG='{"spec":{"disruption":{"consolidateAfter":"10m","consolidationPolicy":"WhenEmpty","budgets":[{"nodes":"10%"}]},"template":{"spec":{"requirements":[{"key":"karpenter.sh/capacity-type","operator":"In","values":["on-demand","spot"]},{"key":"eks.amazonaws.com/instance-category","operator":"In","values":["c","m","r","t"]},{"key":"eks.amazonaws.com/instance-generation","operator":"Gt","values":["3"]},{"key":"kubernetes.io/arch","operator":"In","values":["amd64"]},{"key":"kubernetes.io/os","operator":"In","values":["linux"]}]}}}}'
            kubectl patch nodepool $${NODEPOOL_NAME} --type='merge' --patch="$${PATCH_CONFIG}" || true
            sleep $${RECONCILE_INTERVAL}
          done
        env:
        - name: NODEPOOL_NAME
          valueFrom:
            configMapKeyRef:
              name: nodepool-reconciler-config
              key: nodepool-name
        - name: RECONCILE_INTERVAL
          valueFrom:
            configMapKeyRef:
              name: nodepool-reconciler-config
              key: reconcile-interval
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nodepool-reconciler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nodepool-reconciler
rules:
- apiGroups: ["karpenter.sh"]
  resources: ["nodepools"]
  verbs: ["get", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: nodepool-reconciler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nodepool-reconciler
subjects:
- kind: ServiceAccount
  name: nodepool-reconciler
  namespace: kube-system
  YAML
}

