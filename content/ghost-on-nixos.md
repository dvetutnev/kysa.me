---
title: Ghost on NixOS
author: Dmitriy Vetutnev
date: February 2023
---
![](ghost-logo-dark.png)

В этой заметке описана установка движка блога [Ghost](https://ghost.org/?ref=kysa.me) на [NixOS](https://nixos.org/?ref=kysa.me). Существует более каноничный способ установки без Docker в виде [пакета NixOS](https://notes.abhinavsarkar.net/2022/ghost-on-nixos?ref=kysa.me), но я сделал так, как понятней мне.

# MySQL

Ghost [задеприкейтил SQLite](https://ghost.org/docs/faq/supported-databases/?ref=kysa.me) для боевого режима, поэтому используется MySQL (если точнее, то MariaDB).

```nix
{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        bind-address = "172.17.0.1";
      };
    };
  };

  networking.firewall.interfaces."docker0".allowedTCPPorts = [ 3306 ];
}
```

Не очевидные моменты это биндиг сервера БД на интерфейс Docker и необходимость разрешить порт в фаерволе. Это нужно для доступа изнутри контейнера к сервису, запущенном на хосте. У модуля MySQL из Nixpkgs [есть возможность](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/databases/mysql.nix?ref=kysa.me#L192) добавить пользователя и дать ему нужные права, но этот пользователь создается без пароля и с доступом только с localhost, поэтому пользователя создаем ручками.

```shell
$ sudo -u root mysql -u root
```

```sql
CREATE DATABASE 'ghost';
CREATE USER 'ghost'@'%'
  IDENTIFIED VIA unix_socket
  OR mysql_native_password USING PASSWORD("password");
GRANT ALL PRIVILEGES ON ghost.* TO 'ghost'@'%';
```

# Docker container

Сперва нужно включить сервис Docker:

```nix
{
  virtualisation.docker.enable = true;
}
```

Запуск контейнера:

```shell
docker run --restart=always -p 127.0.0.1:2368:2368 \
	-e url=https://kysa.me \
	-v /var/www/ghost/content:/var/lib/ghost/content  \
	--add-host=host.docker.internal:host-gateway \
	-e database__client=mysql \
	-e database__connection__host=host.docker.internal \
	-e database__connection__user=ghost \
	-e database__connection__password="password" \
	-e database__connection__database=ghost \
	--name ghost-alpine -d ghost:alpine
```

- `--restart=always` - автозапуск контейнера (при перезагрузке ОС).
- `-p 127.0.0.1:2368:2368` - публикуем порт на котором запущен наш Ghost.
- `-v /var/www/ghost/content:/var/lib/ghost/content` - монтирование постоянного хранилища в контейнер (картинки, темы, логи и т.д.).
- `-e url=https:\\kysa.me` - URL по которому будет доступен блог. Без этой переменной окружения не будут доступны вложения (картинки).
- `--add-host=host.docker.internal:host-gateway` _волшебная_ строчка дающая доступ к сервисам хоста из контейнера. `host.docker.internal` добавляет в `/etc/hosts` контейнера запись, указывающую на IP хоста; `host-gateway` добавляет в контейнер сетевой маршрут на хост.
- `-e database__*` - реквизиты доступа к БД.

# NGINX frontend

Контейнер с движком блога запущен, теперь нужно организовать к нему доступ из интернета.

```nix
{
  # Let`s Encrypt
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "user@example.com";
  security.acme.certs."kysa.me".extraDomainNames = [ "static.kysa.me" ];
  # NGINX frontend
  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "kysa.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/ghost/" = {
          extraConfig =
           "allow 10.100.0.0/24;" +
           "deny all;"
           ;
          proxyPass = "http://127.0.0.1:2368";
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:2368";
        };
      };

      "static.kysa.me" = {
        forceSSL = true;
        useACMEHost = "kysa.me";
        locations."/" = {
          root = "/var/www/static";
        };
      };
    };
  };
}
```

`security.acme.*` - получение сертификатов от [Let`s Encrypt](https://letsencrypt.org/?ref=kysa.me) для HTTPS. Ограничен по IP доступ к админке блога (`/ghost`, `10.100.0.0/24` - сеть моего [VPN](wireguard.md)). Также добавлен виртуальный хост `static.kysa.me` для раздачи всякой статики (например Prism.js). Не забываем открыть порты в фаерволе:

```nix
{
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22     # ssh
    80     # http
    443    # https
  ];
}
```

# Prism.js

И последний штрих - добавление [Prism.js](https://prismjs.com/?ref=kysa.me) для подсветки синтаксиса в блоках кода. Скачиваем библиотеку, кладем в директорию из которой NGINX раздает статику. Конечно можно подгружать Prism.js из CDN, но я предпочитаю не добавлять лишних зависимостей. Идем в админку блога, Settings -> Code injection, подключаем библиотеку:

В Site Header вставляем (дополнительно я подстроил размер шрифта для блоков кода):

```html
<link rel="stylesheet" type="text/css" href="https://static.kysa.me/prism/prism.css"/>
<style>
  pre[class*="language-"] {
      font-size: 1em;
  }
</style>
```

В Site Footer:

```html
<script type="text/javascript" src="https://static.kysa.me/prism/prism.js">
</script>
```
