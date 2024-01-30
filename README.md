# gitea-bitnami-custom

our custom installation of gitea packed by Bitnami.  

## Disclaimer

This is a work built for our own needs. It is not intended to be used by anyone else. But, if you want to use it, you can, it is free. Just be aware that we do not provide any support for it. Look at the source code, it is not that complex. You can easily adapt it to your own needs.

## What differs from the original Bitnami installation?

- we embed a smtp server (postfix) to send emails
- we embed cloudflared to create a tunnel to our gitea instance
- we embed a cronjob to renew the letsencrypt certificate and update a cloudflare dns record
- we allow more than 1 replica of the gitea instance (for high availability and load balancing) (obviously, you need to use a volume with ReadWriteMany access mode)
- we add a small tool getlaserfile to download specific files from a git repository (useful to download binary files from a private repository)
  - it use some url like <https://distrib.gitea-sandbox.local/urltofile?hash=commit_hash> (see _values_gitea.yaml and <https://github.com/eltorio/getlaserfile> for more details)

## How High Availability works?

We are based on the Bitnami helm chart for gitea. It does not support high availability. So, we have to do it ourselves. Bitnami uses a Deployment to deploy gitea. We use a locking mechanism to ensure that only one pod is starting and setting the system at a time. The lock is located on the shared volume /bitnami/gitea and it is named .app.ini.lock . The pod will try to acquire the lock. If it succeeds, it will start gitea. If it fails, it will wait for the lock to be released. For computing the length of the wait, we use the following formula:

```bash
# Generate pseudo random number based on the hash of the hostname
# This is to avoid multiple containers to do the same thing at the same time
# The random number is used to wait a random amount of time before starting the setup
# Basing the pseudo random number on the hostname hash allows to have a different number for each container
# Because the hostname as a different hash in each container
function get_pseudorandom_based_on_hash() {
    MIN=${1:-43}
    MAX=${2:-127}
    HOSTNAME=${3:-$(hostname)}
    HASH=$(echo -n "$HOSTNAME" | shasum | cut -f1 -d' ')
    HASH_FIRST_16="${HASH:0:16}"
    ABSHASH=$(abs $((0x$HASH_FIRST_16))) # convert hex to positive decimal
    RANDOM_NUMBER=$((($ABSHASH % ($MAX - $MIN)) + $MIN + 1))
    echo $RANDOM_NUMBER
}
```

We are aware that this is not a perfect solution. But, it works for us. If you have a better solution, please let us know.

## How to use it?

`helm install --upgrade --create-namespace --namespace gitea gitea ./helm/gitea -f _values_gitea.yaml`  
`helm install --upgrade --create-namespace --namespace gitea gitea ./helm/gitea -f _values_gitea.yaml --set gitea.replicaCount=2`  
The `_values_gitea.yaml` file is our sample dev configuration. It is a good starting point to create your own configuration.

## How to debug it?

We use Tilt.dev to debug our helm chart. Our Tiltfile is located in the root folder.  
To start tilt, you need to install it first from <https://github.com/tilt-dev/tilt>.  
Edit the Tiltfile to set the correct name of your Kubernetes cluster.
Then, you can start tilt with
`tilt up`
