Конфигурация виртуальной машины devops-vm
1. Параметры машины

Ubuntu Server 24.04 LTS (64-bit), имя devops-vm, ОЗУ 2048 МБ, 2 ядра, диск 25 ГБ (динамический).
Установка: English, Use an entire disk, пользователь student, OpenSSH server включён.
2. Сетевые интерфейсы

    Адаптер 1: NAT, 10.0.2.15 (Интернет, проброс портов)
    Адаптер 2: Host-only, 192.168.56.101 (доступ с хоста по имени devops.local)
    На хосте в файле hosts: 192.168.56.101 devops.local

3. Правило проброса портов

Адаптер 1, правило ssh, TCP, 127.0.0.1:2222 хоста -> порт гостя 2222.
После отката на 01-clean-install у правила порт гостя 22: его меняют на 2222 после настройки sshd.
4. Учётные записи

    student: создан установщиком, по SSH не входит (AllowUsers devops)
    devops: sudo adduser devops, sudo usermod -aG sudo devops; вход по ключу ed25519

Ключ на хосте: ssh-keygen -t ed25519 -C "devops-vm-key" -f ~/.ssh/devops_vm
Установка ключа: ssh-copy-id -i ~/.ssh/devops_vm.pub -p 2222 devops@127.0.0.1
Права: ~/.ssh 700, authorized_keys 600

    Клиентский ~/.ssh/config (хост): Host devops, HostName 127.0.0.1, Port 2222, User devops, IdentityFile ~/.ssh/devops_vm, IdentitiesOnly yes

5. Служба SSH

    Копия: sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    Файл /etc/ssh/sshd_config.d/99-hardening.conf: Port 2222, PermitRootLogin no, PasswordAuthentication no, PubkeyAuthentication yes, PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2
    Конфликт: если в sshd_config.d есть другой файл (например 50-cloud-init.conf) с PasswordAuthentication yes, закомментировать строку (проверка: grep -r "PasswordAuthentication" /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config)
    Применение: sudo sshd -t, sudo systemctl disable --now ssh.socket, sudo systemctl enable --now ssh.service, sudo systemctl restart ssh; проверка sudo ss -tlnp | grep sshd (порт 2222)

6. Правила межсетевого экрана

Политики: default deny incoming, default allow outgoing. Порядок (разрешения до enable):
sudo ufw default deny incoming, sudo ufw default allow outgoing,
sudo ufw allow 80/tcp comment 'HTTP', sudo ufw allow 443/tcp comment 'HTTPS',
sudo ufw limit 2222/tcp comment 'SSH rate-limited', sudo ufw enable, sudo ufw logging medium.
7. Снимки состояния

    01-clean-install: после установки и обновления (дата)
    02-keys-configured: после настройки ключей (дата)
    03-ssh-hardened: после усиления SSH (дата)

Имя узла

sudo hostnamectl set-hostname devops-vm; в /etc/hosts строка 127.0.1.1 devops-vm.devops.local devops-vm.

8. Веб-сервер

    Пакет: nginx (sudo apt install -y nginx)
    Конфигурация ресурса: /etc/nginx/sites-available/devops-site, включена ссылкой в /etc/nginx/sites-enabled/; стандартный ресурс default отключён (ссылка удалена)
    Блок на порту 80 выполняет return 301 на HTTPS; блок на порту 443 с ssl, ssl_protocols TLSv1.2 TLSv1.3
    Каталог ресурса: /var/www/devops-site, владелец devops, каталоги 755, файлы 644
    Сертификат: /etc/ssl/certs/devops.crt, права 644, владелец root
    Закрытый ключ: /etc/ssl/private/devops.key, права 600, владелец root
    Формирование: openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"; срок действия 365 дней
    Применение конфигурации: sudo nginx -t && sudo systemctl reload nginx
    Доставка содержимого: scripts/deploy.sh (rsync с --delete и --chmod=D755,F644)