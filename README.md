# Nokia NSP Workflow sync
The `wf-sync` script simplifies workflow development for **[Nokia NSP](https://www.nokia.com/networks/products/network-services-platform/) Workflow Manager application ([WFM](https://network.developer.nokia.com/learn/19_11/network-automation/))** by automatically syncing the remote workflow with the local workflow definition file.

![pic](https://gitlab.com/rdodin/pics/-/wikis/uploads/fb698fae368913a2eb029ab969b153ee/image.png)

A developer constantly updates the workflow throughout the course of its development. To transfer the workflow definition changes from the local dev environment to the its remote counterpart stored in the WFM application a developer needs to:

1. change the workflow state to DRAFT
2. copy-paste the workflow definition
3. perform workflow validation
4. publish the workflow

Although the steps required are outrageously simple, the number of clicks involved in this procedure multiplied by the number of times it is needed to update the workflow results in a considerably large amount of wasted time.

Workflow-sync (`wf-sync`) reduces the time it takes to update the remote workflow by automating the above mentioned steps.

```bash
$ bash wf_sync.sh 192.168.1.10 workflow.yml 928817cc-c4e6-4e69-be2e-63a0857a9d6c
Getting access token...
Setting workflow status to DRAFT...
Validating the workflow...
Updating the workflow definition...
Publishing workflow...
```

## Download
To download the `wf-sync` simply curl/wget it to your working directory, or to the `$PATH`:

```bash
# this will download the script to the current directory and make it executable
curl -L https://raw.githubusercontent.com/hellt/nsp-wf-sync/master/wf-sync.sh > ./wf-sync.sh && \
chmod a+x ./wf-sync.sh
```

## Usage
`wf-sync` script is able to perform two operations:

1. Update (sync) the remote workflow definition with its local version
2. List the remote workflows

### List workflows
It is imperative to know the ID of the workflow that you are about to sync. For that reason the script contains a helper function that lists the workflows and their IDs on a remote WFM app.

The signature of the command is: `wf-sync.sh <nsp_address> list_workflows [<http_proxy_address>]`. Example:

```json
$ bash wf_sync.sh nsp.nokia.com list_workflows
Getting access token...
Getting current workflows...
{
  "id": "928817cc-c4e6-4e69-be2e-63a0857a9d6c",
  "name": "create_discovery_rule_aio",
  "status": "PUBLISHED",
  "last_updated": "2020-01-15 20:20:47"
}
{
  "id": "3f7114a8-e460-4af7-a723-06613e2294e1",
  "name": "create_netconf_communication_profile",
  "status": "PUBLISHED",
  "last_updated": "2020-01-14 13:08:15"
}
```
With this function you can quickly derive the ID of the workflow that you want to update.

### Update/Sync the workflow
Once the workflow ID is known, to perform the update of the remote workflow definition, use the following command:

```bash
bash wf-sync.sh <nsp_address> <path_to_workflow_file> <workflow_id> [<http_proxy_address>]
```

For example, if your working directory contains the following files:

```
$ tree
.
├── my_workflow.yml
└── wf-sync.sh

0 directories, 2 files
```

where the `my_workflow.yml` represents the workflow file that should update the remote workflow with ID `928817cc-c4e6-4e69-be2e-63a0857a9d6c` then the command will look like that:

```bash
./wf-sync.sh my.nsp.lab.com my_workflow.yml 928817cc-c4e6-4e69-be2e-63a0857a9d6c
Getting access token...
Setting workflow status to DRAFT...
Validating the workflow...
Updating the workflow definition...
Publishing workflow...
```

### Support for HTTP proxy
If you need to use a proxy to reach your NSP API you can supply the proxy address as the last argument:

```bash
# list workflows with proxy
$ bash wf_sync.sh nsp.nokia.com list_workflows myproxy.com:8080

# sync workflow
$ my.nsp.lab.com my_workflow.yml 928817cc-c4e6-4e69-be2e-63a0857a9d6c myproxy.com:8080
```

## Limitations

- `wf-sync` relies on [`jq`](https://stedolan.github.io/jq/) tool which is easy to [install](https://stedolan.github.io/jq/download/) if you don't have it in your dev environment.
- it is required to have a remote workflow in order to sync. I.e. you can't **create** a workflow from a local definition file.
