# AGENTS.md

## Build SD card image

Uses Docker - no host dependencies needed.

```bash
# First run (prefetch debootstrap + build kernel/uboot/tfa)
docker compose run build --variant decktrix --prefetch-debootstrap

# Subsequent builds (uses cached debootstrap)
docker compose run build --variant decktrix --use-prefetch-debootstrap
```

Output: `deploy/sdcard.img.gz`

Variants: `stm32`, `stm32-jadard`, `decktrix`

## Project structure

- `Dockerfile` + `docker-compose.yml` - build environment
- `build-image.sh` - main build script
- `board/linux/patches/` - kernel patches (Jadard driver, DTS, pinctrl)
- `board/tfa/patches/` - TF-A patches (pinctrl)
- `board/u-boot/patches/` - U-Boot patches (DSI disable, pinctrl)
- `board/tfa/decktrix-v1.dts` - TF-A device tree (LDO overrides)
- `board/u-boot/decktrix-v1.dts` - U-Boot device tree
- `scripts/gdrive-upload.sh` - upload file to Google Drive
- `scripts/gdrive-auth.sh` - re-authenticate when token expires

## Decktrix v1 board differences from DK2

| Component | Devboard (DK2) | Decktrix PCB |
|---|---|---|
| PMIC I2C4 SCL | PZ4 | PD12 (AF4) |
| PMIC I2C4 SDA | PZ5 | PD13 (AF4) |
| LDO1 | 1.8V (v1v8_audio) | 2.8V (display AVDD) |
| LDO6 | 1.2V (v1v2_hdmi) | 1.8V (display IOVCC) |
| LCD reset | PE4 | PD11 |
| LCD backlight | PA15 | PF6 (TPS61042 ctrl) |
| Touch IRQ | PF2 | PG7 |
| Touch reset | PF4 | PE10 |
| BT UART | USART2 (PA2/PA3) | UART8 (PE0/PE1) |
| BT shutdown | PZ6 | PB10 |
| WiFi reset | PH4 | PE6 |
| WiFi chip | BCM43430 | u-blox MAYA-W166 (NXP IW416) |
| Display power | GPIO vdd/vccio | Always-on PMIC rails |

Display is powered by PMIC regulators (always-on):
- LDO1 (2.8V) -> display AVDD
- LDO6 (1.8V) -> display IOVCC
- No GPIO enable needed

Jadard driver uses `devm_gpiod_get_optional()` for vdd/vccio/dbg GPIOs.

## TODO

- WiFi/BT: u-blox MAYA-W166 (NXP IW416) driver, SDMMC3, UART8

## Google Drive upload

```bash
./scripts/gdrive-upload.sh <path-to-file>
```

Credentials in `.config/opencode/gdrive-token.json` (not in git).

### Initial setup (from scratch)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project `decktrix`
3. Enable **Google Drive API** (APIs & Services -> Library)
4. Go to **APIs & Services -> OAuth consent screen**
5. Set User type to **External**
6. Add your email under **Test users**
7. Go to **APIs & Services -> Credentials**
8. Click **Create Credentials -> OAuth client ID**
9. Application type: **Desktop app**, name: `decktrix`
10. Click **Create**
11. Click **Download JSON** on the popup
12. Save as `~/.config/opencode/gcp-oauth.json`
13. Run `./scripts/gdrive-auth.sh`
14. It prints an OAuth URL - open in browser
15. Sign in with your Google account, approve access
16. Browser redirects to `http://localhost/?code=XXXXX...`
17. Copy the code from the URL (everything between `code=` and `&`)
18. Paste it into the terminal
19. Script creates `.config/opencode/gdrive-token.json`

### When token expires (after 7 days)

The refresh token expires after 7 days. When this happens:
1. `gdrive-upload.sh` will fail with "Failed to refresh access token"
2. Run `./scripts/gdrive-auth.sh`
3. It prints an OAuth URL - open it, approve, paste the code
4. Token file is updated automatically
5. Run `gdrive-upload.sh` again

### Google Cloud project

- Project: decktrix
- OAuth Client ID: `236838812265-94votd2clqtuoc10ang7lidqegrqlbdh.apps.googleusercontent.com`
- Folder: `1GEBlgEZuuIjffJXl2PR23m1ojAJ_IQYR`
