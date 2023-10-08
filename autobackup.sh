#!/bin/bash
#!/bin/bash
gitea dump --config=/opt/bitnami/gitea/custom/conf/app.ini --file /tmp/gitea-dump.zip
NOW=$(date -I)

(
cat << EOF 
From: "SAUVEGARDE @Gitea" <$BACKUP_FROM>
To: "Backup@Gitea" <$BACKUP_TO>
MIME-Version: 1.0
Subject: Sauvegarde Gitea $FQDN du $NOW 
Content-Type: multipart/mixed; boundary="-"

This is a MIME encoded message.  Decode it with "munpack"
or any other MIME reading software.  Mpack/munpack is available
via anonymous FTP in ftp.andrew.cmu.edu:pub/mpack/
---
Content-Type: text/plain

Voici la sauvegarde du $NOW
accès https://$FQDN/
Gitea+ team

---
Content-Type: application/octet-stream; name="backup-$NOW.zip"
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename="backup-$NOW.zip"

EOF
)    | (cat - && /usr/bin/openssl base64 < /tmp/gitea-dump.zip && echo "" && echo "---")\
     | /usr/sbin/sendmail -f $BACKUP_FROM -S $SMTPD_SERVICE_HOST -t --
rm -rf /tmp/gitea-dump.zip