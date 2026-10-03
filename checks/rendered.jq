# The rules for what a community chart creates. Input: the objects Helm
# renders, as one JSON array. Output: one line per finding, none when the chart
# passes.
#
#   $images     image repositories the package lists in template.yaml
#   $namespace  namespace of the release

def allowed_kinds: [
  "ConfigMap", "CronJob", "Deployment", "HorizontalPodAutoscaler", "Job",
  "NetworkPolicy", "PersistentVolumeClaim", "PodDisruptionBudget", "Secret",
  "Service", "ServiceAccount", "StatefulSet"
];

# Capabilities the Kubernetes baseline Pod Security Standard allows a container to add.
def baseline_capabilities: [
  "AUDIT_WRITE", "CHOWN", "DAC_OVERRIDE", "FOWNER", "FSETID", "KILL", "MKNOD",
  "NET_BIND_SERVICE", "SETFCAP", "SETGID", "SETPCAP", "SETUID", "SYS_CHROOT"
];

def described: "\(.kind) \(.metadata.name // "without a name")";

def pod_spec:
  if .kind == "CronJob" then .spec.jobTemplate.spec.template.spec
  elif .kind == "Deployment" or .kind == "StatefulSet" or .kind == "Job" then .spec.template.spec
  else null end;

def containers: (.containers // []) + (.initContainers // []);

# "registry/name:tag@sha256:..." without the tag and the digest.
def repository:
  split("@")[0] as $reference
  | ($reference | split("/") | last) as $name
  | if ($name | contains(":")) then $reference[0:($reference | rindex(":"))] else $reference end;

def tag:
  (split("@")[0] | split("/") | last) as $name
  | if ($name | contains(":")) then ($name | split(":") | last) else "" end;

def findings:
  described as $label
  | (
      if (.kind as $kind | allowed_kinds | index($kind)) then empty
      else "\($label): a community chart does not create a \(.kind)" end
    ),
    (
      if .metadata.namespace != null and .metadata.namespace != $namespace
      then "\($label): placed in the namespace \(.metadata.namespace), outside the namespace of the release"
      else empty end
    ),
    (
      if .kind == "Service" and (.spec.type // "ClusterIP") != "ClusterIP"
      then "\($label): of type \(.spec.type). Use ClusterIP"
      else empty end
    ),
    (
      pod_spec // empty
      | (
          (if .hostNetwork == true then "\($label): uses hostNetwork" else empty end),
          (if .hostPID == true then "\($label): uses hostPID" else empty end),
          (if .hostIPC == true then "\($label): uses hostIPC" else empty end),
          ((.volumes // [])[] | select(.hostPath != null) | "\($label): mounts the hostPath volume \(.name)"),
          (
            containers[]
            | . as $container
            | (
                (if .securityContext.privileged == true
                 then "\($label): the container \(.name) is privileged" else empty end),
                (
                  (.securityContext.capabilities.add // [])[]
                  | . as $capability
                  | select(baseline_capabilities | index($capability) | not)
                  | "\($label): the container \($container.name) adds the \($capability) capability"
                ),
                ((.ports // [])[] | select((.hostPort // 0) != 0)
                  | "\($label): the container \($container.name) uses a hostPort"),
                (
                  (.image // "") as $image
                  | if $image == "" then "\($label): the container \(.name) names no image"
                    elif (($image | repository) as $repository | $images | index($repository) | not)
                    then "\($label): runs \($image | repository), which is not in the images list of template.yaml"
                    elif ($image | tag) == "" or ($image | tag) == "latest"
                    then "\($label): \($image) has no fixed tag"
                    elif ($image | test("@sha256:[0-9a-f]{64}$") | not)
                    then "\($label): \($image) has no digest. Pin it as tag@sha256:<digest>"
                    else empty end
                )
              )
          )
        )
    );

[.[] | select(. != null) | findings] | unique | .[]
