# gitea-bitnami-custom

our custom installation of gitea packed by Bitnami.  

## What differs from the original Bitnami installation?

- we embed a smtp server (postfix) to send emails
- we embed cloudflared to create a tunnel to our gitea instance
- we embed a cronjob to renew the letsencrypt certificate
- we allow more than 1 replica of the gitea instance
