# minecraft-vm-gpu

Ubuntu VM на `pve-rog` для игры ИИ-агентов в Minecraft (Horizon — Minecraft Java 26.3 на Rust):
сервер `coop`, клиенты ботов, Claude Code-куратор, который ими управляет, и проброшенная
GTX 770M, на которой клиенты рисуют. Окна ботов выводятся сеткой прямо на панель ноутбука.

VM сидит в изолированном SDN-сегменте: в LAN и тайлнет из неё не попасть. Внутрь —
SSH через ноду или по тайлнету (`tag:mc-bots`, только входящий доступ), наружу — интернет
через SNAT ноды плюс домены app-connector'а (Claude API).

## Содержание

- [Архитектура](#архитектура)
- [Что делает Terraform, а что руками](#что-делает-terraform-а-что-руками)
- [Структура](#структура)
- [Требования](#требования)
- [Подготовка хоста pve-rog](#подготовка-хоста-pve-rog)
- [Секреты и Vault](#секреты-и-vault)
- [Развёртывание с нуля](#развёртывание-с-нуля)
- [Проверки](#проверки)
- [Известные ограничения](#известные-ограничения)

## Архитектура

```
pve-rog (G750JX)
└── SDN zone mcvm / vnet mcvmv, 10.64.0.0/24, SNAT наружу
    └── VM minecraft-vm-gpu-sandbox (10.64.0.10)
        ├── hostpci0 = mapping gtx770m  (01:00.0 VGA + 01:00.1 HDMI-audio)
        ├── nouveau + Mesa: NVK (Vulkan), NVE6 (GL 4.3)
        ├── bots-x.service        Xorg + awesome на панели ноутбука (:0)
        ├── horizon-server-coop   user-сервис deploy, мир ~/servers/coop
        ├── ~/claude-player       куратор (Claude Code в tmux) + bot.sh
        └── tailscale             tag:mc-bots
```

| Компонент | Зачем |
|---|---|
| SDN-сегмент + файрвол VM | Агент читает игровой чат — недоверенный ввод; VM не должна видеть LAN, ноды и тайлнет |
| `proxmox_hardware_mapping_pci` | Проброс GPU обычным API-токеном: сырой PCI-адрес в `hostpci` разрешён только `root@pam` |
| GTX 770M + NVK | Horizon рендерит через wgpu/Vulkan; без GPU десяток клиентов на llvmpipe CPU не тянет |
| Xorg + awesome (`fair`) | Клиентам нужен дисплей; X на реальной карте даёт DRI3-презентацию, awesome раскладывает окна сеткой |
| `tag:mc-bots` (repo `tailscale-acl`) | Доступ к SSH и 25565 с моих устройств; сама VM в тайлнет не ходит |

## Что делает Terraform, а что руками

**Terraform** (`env/sandbox`): SDN-сегмент, маппинг GPU, VM, файрвол VM, сниппет vendor-data.

**vendor-data** (первая загрузка): пакеты Mesa/Vulkan/Xorg/awesome/ALSA и утилиты,
конфиг X на 770M, `bots-x.service`, `rc.lua` для awesome, группы `video`/`render`,
linger для `deploy`, установка Tailscale и Claude Code.

**Руками** (секреты, данные и логины — им не место в сниппете на ноде):
вход в тайлнет с тегом, бинарники Horizon, мир сервера, `claude-player`, логин Claude Code.
Порядок — в [Развёртывание с нуля](#развёртывание-с-нуля).

## Структура

```
env/sandbox/
├── backend.tf      S3 (MinIO), бакет minecraft-vm-gpu-tfstate
├── providers.tf    API-токен + SSH к нодам по tailnet-именам (для сниппета)
├── locals.tf       ноды, имя VM, MAC, адресация сегмента
├── network.tf      mod/sdn-simple
├── hardware.tf     proxmox_hardware_mapping_pci "gtx770m"
├── main.tf         mod/pve-vm, hostpci по имени маппинга
├── firewall.tf     IN: только SSH от шлюза; OUT: DROP во все частные диапазоны и 100.64.0.0/10
└── outputs.tf      vm_id, ipv4, ssh (через ноду), ssh_tailnet
mod/
├── sdn-simple/     Simple zone + vnet + subnet (SNAT) + applier/finalizer
└── pve-vm/         VM из cloud-образа, hostpci по маппингам, vendor-data сниппет
```

## Требования

- Terraform >= 1.16, `bpg/proxmox` 0.115.x.
- На storage `local` включены content types `import` и `snippets`.
- Роль API-токена (общая `TerraformProv`, назначена на `/`), сверх VM/Datastore:
  - `SDN.Allocate`, `SDN.Use` — зона, vnet, subnet, подключение NIC;
  - `Mapping.Modify`, `Mapping.Use`, `Mapping.Audit` — маппинг GPU;
  - `VM.Config.HWType` — подключение маппинга как `hostpci`;
  - `Datastore.AllocateTemplate`, `Sys.Audit`, `Sys.Modify` — `proxmox_download_file`;
  - `VM.Config.Network` — правила файрвола VM.
- SSH под root к ноде с ключом в ssh-agent — только для сниппета.
- Файрвол датацентра включён: `pvesh get /cluster/firewall/options` → `enable: 1`.
- В `tailscale-acl` заведён `tag:mc-bots` (входящий `tcp:22`, `tcp:25565` от админов;
  исходящий только `autogroup:internet via tag:app-connector`).

## Подготовка хоста pve-rog

Разово, до первого `apply`. GPU должна быть на `vfio-pci`, а не на nouveau хоста:

```sh
cat /proc/cmdline                       # intel_iommu=on iommu=pt
ls /sys/kernel/iommu_groups/1/devices/  # 00:01.0 (root port), 01:00.0, 01:00.1 — и всё
cat > /etc/modprobe.d/vfio.conf <<'EOF'
options vfio-pci ids=10de:11e0,10de:0e0b
softdep nouveau pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
printf "vfio\nvfio_iommu_type1\nvfio_pci\n" >> /etc/modules
update-initramfs -u -k all && reboot
lspci -nnk -s 01:00 | grep 'in use'     # vfio-pci у обеих функций
```

`snd_hda_intel` не блэклистить — на нём звук самого ноутбука; softdep хватает, чтобы vfio
забрал HDMI-аудио первым. После проброса у хоста нет локального экрана: только SSH.

## Секреты и Vault

Terraform из Vault не читает, всё приходит через окружение.

| Путь | Что |
|---|---|
| `proxmox/terraform-provider` | `api_token` → `TF_VAR_proxmox_api_token` |
| `minio/credentials` | `access_key`, `secret_key` → `AWS_*` для backend |
| `minecraft-vm-gpu/infra/ssh` | `private_key`, `public_key` ключа `minecraft-vm-gpu-sandbox` |
| `minecraft-vm-gpu/infra/config` | `node`, `vm_ip`, `vm_user`, `ssh_jump`, `tailnet_host` |

```sh
export AWS_ACCESS_KEY_ID="$(vault kv get -field=access_key minio/credentials)"
export AWS_SECRET_ACCESS_KEY="$(vault kv get -field=secret_key minio/credentials)"
export AWS_ENDPOINT_URL_S3=...
export TF_VAR_proxmox_api_token="$(vault kv get -field=api_token proxmox/terraform-provider)"
export TF_VAR_ssh_public_keys="$(vault kv get -field=public_key minecraft-vm-gpu/infra/ssh | jq -Rn '[inputs]')"
echo "$TF_VAR_ssh_public_keys"   # не пустой массив: `export X="$(...)"` молча глотает ошибку
```

## Развёртывание с нуля

1. **VM:**
   ```sh
   cd env/sandbox && terraform init && terraform apply
   ```
2. **Дождаться vendor-data** и проверить GPU (через ноду, тайлнета ещё нет):
   ```sh
   ssh -J root@pve-rog.<tailnet> deploy@10.64.0.10 'cloud-init status --wait; systemctl is-active bots-x'
   ```
3. **Тайлнет с тегом** (политика с `tag:mc-bots` уже применена; `--accept-routes`
   обязателен — без него не работает app-connector, и Claude API недоступен):
   ```sh
   sudo tailscale up --advertise-tags=tag:mc-bots --accept-routes
   ```
4. **Horizon** — каталог версии целиком (вместе со скрытым `.local/horizon-client/<ver>`),
   той же версии, что и мир:
   ```sh
   scp -r ~/.local/share/horizon-launcher/versions/<nightly> deploy@minecraft-vm-gpu-sandbox:~/horizon-current
   ```
5. **Мир** — сервер на источнике остановлен:
   ```sh
   rsync -az --mkpath ~/.local/share/horizon-launcher/servers/coop/ deploy@minecraft-vm-gpu-sandbox:servers/coop/
   ```
   В VM: `bind = ""` в `[server]` файла `server.toml` (слушать все адреса), затем
   ```sh
   ~/horizon-current/horizon-server --dir ~/servers/coop service install
   ~/horizon-current/horizon-server --dir ~/servers/coop backup initial
   ```
6. **Куратор:** `git clone` `claude-player` в `~/claude-player`, затем
   ```sh
   ~/claude-player/gen-hands.sh 4        # агенты hands-N + MCP horizon-bot-N, horizon-server
   tmux new -s player -c ~/claude-player
   claude --model sonnet                  # логин по ссылке
   ```

## Проверки

```sh
lspci -nnk | grep -A3 -i nvidia                                  # nouveau / snd_hda_intel
MESA_VK_DEVICE_SELECT=list vulkaninfo 2>&1 | head                # GTX 770M (NVK GK106)
eglinfo -B -p surfaceless | grep renderer                        # NVE6
systemctl status bots-x --no-pager | head -3                     # active
~/horizon-current/horizon-server --dir ~/servers/coop status     # TPS 20
tailscale status --json | jq '.Self.Tags'                        # ["tag:mc-bots"]
curl -s https://checkip.amazonaws.com                            # IP app-connector'а (OCI)
for t in 100.110.130.14:9000 100.100.33.63:22 192.168.100.1:22; do
  timeout 3 bash -c "</dev/tcp/${t%:*}/${t#*:}" 2>/dev/null && echo "LEAK $t" || echo "blocked $t"
done
```

## Известные ограничения

### Проприетарного драйвера нет

Kepler поддерживает только ветка 470; в resolute её нет, на ядре 7.x она и не соберётся.
Работаем на nouveau + NVK. Если понадобится 470 — только noble (24.04) на ядре 6.8
и `pre_enrolled_keys = false`.

### Secure Boot и частоты GPU

`pre_enrolled_keys = true`: nouveau подписан и грузится. Но lockdown `integrity` закрывает
debugfs, поэтому ручной реклок nouveau (`pstate`) недоступен — карта работает на
загрузочных частотах. Для десятка ботов на дальности 2 и 10 fps хватает.

### `--accept-routes` и app-connector

Claude API с домашнего IP недоступен, к нему ходят через `tag:app-connector`. Нужны и
`--accept-routes` в VM, и грант `tag:mc-bots → autogroup:internet via tag:app-connector`.
Без любого из двух Claude Code в VM отваливается.

### Окно без файрвола и тайлнет

Правила файрвола VM создаются после старта VM — первые минуты cloud-init она без фильтра.
Файрвол Proxmox не видит трафик Tailscale (он внутри WireGuard): изоляцию по тайлнету
даёт только политика `tailscale-acl`.

### Что не в коде

Всё из шагов 3–6 — руками. `terraform apply -replace` VM вернёт голую систему с пакетами,
X и сервисами, но без тайлнета, Horizon, мира и логина Claude. Мир переживает пересоздание
только через бэкап (`horizon-server backup`) или rsync с VM заранее.

### Сниппет требует SSH под root к ноде

API Proxmox не загружает `snippets`; `proxmox_virtual_environment_file` кладёт vendor-data
по SSH (bpg/terraform-provider-proxmox#2112, wontfix). Единственный ресурс, которому нужен SSH.

### vendor-data — только первая загрузка

Изменённый сниппет Terraform перезальёт, но существующая VM его не применит — только
пересоздание (`-replace=module.vm.proxmox_virtual_environment_vm.this`).

### Образ `current` без checksum

`.../resolute/current/...` с `overwrite = false`: новый образ — осознанно, через
`-replace=module.vm.proxmox_download_file.image`. Destroy env удаляет образ с ноды.

### SDN apply трогает весь кластер

Applier делает `ifreload` на всех нодах; перед правками сегмента проверить `pvecm status`.

### Host key при пересоздании

`ssh_deletekeys: false` бережёт ключи только при смене instance-id. После пересоздания:
`ssh-keygen -R 10.64.0.10` и `ssh-keygen -R minecraft-vm-gpu-sandbox`.
