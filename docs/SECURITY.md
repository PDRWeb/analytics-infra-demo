# Security Checklist

- [ ] All secrets in `.env`, never committed.
- [ ] Cloudflare Tunnel for HTTPS to API.
- [ ] API Receiver requires `x-api-key`.
- [ ] Postgres only accessible on Tailscale subnet.
- [ ] Metabase only LAN / VPN accessible.
- [ ] Daily `pg_dump` backups, restore tests weekly.