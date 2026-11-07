# omadb
The ProtonDB of Omarchy hardware: tiers per machine, per-feature status, fixes, and predictions for machines nobody has reported yet. Live: https://omadb.technoir.cloud (domain not yet confirmed)

## Commands
- Check (before every commit and deploy): `scripts/check.sh`
- Dev: `bin/dev` (needs Ruby 4; this Mac has none, so `scripts/on-hoid "<cmd>"` runs it in the omadb-dev container)
- Deploy: `./scripts/deploy.sh` (not written yet)

## Non-negotiables
1. Never blur the status layers (verified ● / predicted ◐ / unverified ○ / disputed). Users decide what to buy on them.
2. Predictions are per component ID, never "similar model ⇒ works": vendors swap wifi/audio modules inside one SKU.
3. A prediction is capped at Gold. Only a human report on that exact SKU earns Platinum.
4. Tiers are derived from feature statuses, never picked by a user.
5. Reports never carry serials, MACs or hostnames; machine-id is hashed client-side.
6. No third-party dataset is imported before Javier approves its license. Never scrape omahcl.com.
7. Ask Javier before choosing the domain or license, or publishing anything (repo, deploy, posts).
8. Default theme is Omarchy's own default (Tokyo Night, per `install/user/theme.sh` upstream); re-check on theme work.
