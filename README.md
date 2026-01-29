# CTF

## Spis plików

- `virt-install-script.sh` - skrypt do **stawiania gotowego środowiska**
- `debian-13-generic-amd64-20251117-2299.qcow2` - obraz  źródłowy dla pozostałych ([link do pobrania](https://cloud.debian.org/images/cloud/trixie/20251117-2299/debian-13-generic-amd64-20251117-2299.qcow2))
- `host*-gold-image.qcow2` - "golden image" nie powinno się go zmieniać
- `host*-work.qcow2` - obraz różnicowy do działania maszynki, można go spokojnie usuwać i odtwarzać
- `net*.xml` - definicja sieci dla virt-managera
- `new-host-script.sh` - skrypt do początkowej konfiguracji hosta
- `host*-skrypt.sh` - skrypt który powinien w teorii na czystym obrazie debian postawić to co znajduje się w golden image, po wykonaniu początkowej konfiguracji 
  - `host0` - attacker (NAT + net01)
  - `host1` - webapp (net01 + net12)
  - `host2` - webmin (net12 + net23)
  - `host3` - postgres (net23 + net34)
  - `host4` - log4shell (net34)

## Uruchomienie gotowego środowiska

```
sudo ./virt-install-script.sh
```

## Tworzenie nowego hosta
Przykładowe wartości

### 1. Utworzenie golden-image
```
sudo ./new-host-script.sh host1 Password123 default net12
```
- host1 - nazwa hosta
- Password123 - hasło
- default net12 - sieci do podłączenia

Polecam do jednej z tych sieci podłączyć maszynkę wirtualną nad którą się panuje i pozwala na korzystanie z konsoli i wklejania np.: kali

### 2. Zalogowanie się w okienku maszyny wirtualnej
Przy pomocy root:hasło można się zalogować
#### 2.1 Konfigurowanie ssh

Wykonujemy polecenia, żeby móc łączyć się po ssh dla ułatwienia pracy

```
apt install -y openssh-server
rm -f /etc/ssh/ssh_host_*
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server
```
W pliku `/etc/ssh/sshd_config` usatwiamy wartości/odkomentowujemy
```
PermitRootLogin yes
PasswordAuthentication yes
```
Wykonujemy
```
systemctl restart sshd
systemctl restart ssh
```
#### 2.2 Konfigurowanie dhcp
Tworzymy plik `/etc/systemd/network/10-wired.network`
```
[Match]
Name=enp*

[Network]
DHCP=yes
```
Wykonujemy
```
systemctl enable systemd-networkd
systemctl restart systemd-networkd
```
Powinno pozwolić na nadanie jakiś adresów i zalogowanie się po ssh do maszyny w celu dalszej konfiguracji

Na późniejszym etapie lepiej usunąć `/etc/systemd/network/10-wired.network` i zastąpić go konfiguracjami dla konkretnych adresów dla naszych interfejsów

### 3. Logowanie po SSH i konfiguracja maszyny

Używając skryptu lub pojedyńczych poleceń należy skonfigurować maszynę

### 4. Zapisanie gold-image i stworzenie work

Po konfiguracji, maszynę z virt-managera należy usunąć, zmienić uprawnienia pliku na read_only i dodać do `virt-install-script.sh` jak dla innych maszyn
