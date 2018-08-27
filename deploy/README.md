# Deploy scripts

## elasticsearch-indexer
Newer ubuntu uses systemd rather than upstart. For our recent deployment to Ubuntu 16.04 we will use `elasticsearch-indexer.service` with systemd.
To install the service (which makes sure the server stays running, even after a reboot) put `elasticsearch-indexer.service`
in `/etc/systemd/system/elasticsearch-indexer.service`  

```bash
systemctl start elasticsearch-indexer
systemctl stop elasticsearch-indexer
systemctl status elasticsearch-indexer
```

If you want to start it on boot:

```bash
systemctl enable elasticsearch-indexer
```

Checking the logs
grep `/var/log/syslog` for `elasticsearch-indexer`
e.g.
```bash
tail -n 1000 '/var/log/syslog' | grep 'elasticsearch-indexer'
```


## cron jobs

The crontab file has rules for running the indexing pipeline on a regular basis, once per hour.

To setup, run `crontab -e` as the `ubuntu` user (which is the user that should have this repo checked out in their home directory).  
Copy paste the contents of this crontab file into the editor.