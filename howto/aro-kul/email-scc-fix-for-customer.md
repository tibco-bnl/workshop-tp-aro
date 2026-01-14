Subject: ACTION REQUIRED: Security Context Constraint (SCC) Permission Fix for TIBCO Control Plane Deployment

Hi Team,

I hope this email finds you well.

During our TIBCO Control Plane (tibco-cp-base) deployment on the Azure Red Hat OpenShift (ARO) cluster, we encountered an issue where pods are failing to start with the following error:

```
pods "tp-cp-orchestrator-669d64876b-" is forbidden: unable to validate against any security context constraint: 
[provider "tp-scc": Forbidden: not usable by user or serviceaccount...]
```

**Root Cause:**
While we created the `tp-scc` Security Context Constraint earlier, we need to explicitly grant it to the service accounts in the Control Plane namespace. This is a required step in OpenShift/ARO environments.

**Resolution - Please Execute These Commands:**

1. **Set your Control Plane instance ID** (replace "cp1" if using a different ID):
   ```bash
   export CP_INSTANCE_ID="cp1"
   ```

2. **Grant SCC permissions to service accounts:**
   ```bash
   oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
   oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
   ```
   
   Expected output for each command:
   ```
   clusterrole.rbac.authorization.k8s.io/system:openshift:scc:tp-scc added: "cp1-sa"
   clusterrole.rbac.authorization.k8s.io/system:openshift:scc:tp-scc added: "default"
   ```

3. **Delete the failing pods** (they will be automatically recreated with correct permissions):
   ```bash
   oc delete pods --all -n ${CP_INSTANCE_ID}-ns
   ```

4. **Monitor pod creation:**
   ```bash
   oc get pods -n ${CP_INSTANCE_ID}-ns -w
   ```
   
   Press `Ctrl+C` to exit the watch mode once all pods are in `Running` state.

**Verification:**

Once pods are running, verify they're using the correct SCC:
```bash
# Check a running pod
POD_NAME=$(oc get pods -n ${CP_INSTANCE_ID}-ns -o jsonpath='{.items[0].metadata.name}')
oc describe pod $POD_NAME -n ${CP_INSTANCE_ID}-ns | grep "openshift.io/scc"
```

Expected output should show: `openshift.io/scc: tp-scc`

**Why This Happened:**
In OpenShift, creating a Security Context Constraint is not sufficient - it must be explicitly granted to service accounts using the `oc adm policy add-scc-to-user` command. This step ensures that pods can use the appropriate security context to run.

**Next Steps After Resolution:**
Once all pods are running successfully (you should see them in `Running` or `Completed` status), the Control Plane should be fully operational. You can then proceed to:

1. Monitor the deployment completion: `helm list -n ${CP_INSTANCE_ID}-ns`
2. Retrieve the initial admin password within 1 hour of deployment:
   ```bash
   kubectl logs -n ${CP_INSTANCE_ID}-ns $(kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user | awk '{print $1}')
   ```
3. Access the Control Plane UI at: `https://admin.${CP_MY_DNS_DOMAIN}`

**Additional Documentation:**
I've attached a detailed troubleshooting guide (`troubleshooting-scc-permissions.md`) that includes:
- Complete explanation of the issue
- Pre-installation checklist for future deployments
- Common issues and solutions
- Quick fix script

Please let me know once you've executed these commands and confirmed that the pods are running successfully. I'm available to assist if you encounter any issues during the resolution.

If you have any questions or need further assistance, please don't hesitate to reach out.

Best regards,
Kulbhushan Bhalerao

---

**Quick Reference - Commands at a Glance:**
```bash
export CP_INSTANCE_ID="cp1"
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
oc delete pods --all -n ${CP_INSTANCE_ID}-ns
oc get pods -n ${CP_INSTANCE_ID}-ns -w
```

**Attachments:**
- troubleshooting-scc-permissions.md (detailed troubleshooting guide)
