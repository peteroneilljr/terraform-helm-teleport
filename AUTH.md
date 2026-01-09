

## Authenticate Providers

### Log into Teleport Cluster

```sh
tsh logout; tsh login --proxy=peter.teleport.sh:443 --auth=okta
```

```sh
cd /Users/darkmatter/GitHub/terraform-peter-teleportdemo-com/teleport-cluster
```

```sh
FOLDER="/Users/darkmatter/GitHub/terraform-peter-teleport-sh/auth"
tctl create -f $FOLDER/tbot_resource.yaml
tctl create \
  -f $FOLDER/tbot_token.yaml && \
tbot start \
  --config=$FOLDER/tbot_config.yaml \
  --certificate-ttl=10h
```
