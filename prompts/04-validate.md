# Deprecated — validation is the Site Reliability Guardian's job now

See `dtctl/guardians/checkout-release-guardian.yaml` and `scripts/run-guardian.sh`. The release workflow polls the guardian; a `fail` verdict triggers `scripts/rollback.sh` automatically.
