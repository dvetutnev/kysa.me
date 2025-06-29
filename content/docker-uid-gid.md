---
title: Docker UID/GID
author: Dmitriy Vetutnev
date: Octoner 2021
---
По умолчанию внутри Docker-контейнера процесс запускается с **UID/GID 0:0**, что соответствует пользователю и группе **root:root**. Из этого вытекает два свойства:

1. Владелец создаваемых в примонтированых директориях файлов root. Для изменения/удаления этих файлов приходиться использовать **sudo**.
2. Нет возможности использовать внутри контейнера SSH-ключи простым монтированием директории **~/.ssh**. В целях безопасности SSH-клиент требует чтобы на файлах ключей стояли права **600** и владельцем файлов был пользователь запустившим клиент.

Решается эта проблема добавление в контейнер групп с ID равными 1001, 1000 и 2000 (самые распространенные ID групп пользователя рабочей станции), добавлением в пользователя включенным в эти группы, и указанием что процесс внутри контейнера должен запускаться под этим пользователем.

Пример для контейнеров на базе CentOS:

```docker
RUN groupadd g1001 --gid 1001 \
 && groupadd g1000 --gid 1000 \
 && groupadd g2000 --gid 2000 \
 && useradd --create-home --shell /bin/bash user --gid 1001 --groups g1000,g2000 \
 && printf "user:user" | chpasswd \
 && usermod --append --groups wheel user \
 && printf "user ALL= NOPASSWD: ALL\\n" >> /etc/sudoers
USER user
WORKDIR /home/user
ENV PATH=/home/user/.local/bin:${PATH} \
 CONAN_USER_HOME=/home/user
```

Эта идея подсмотрена [здесь](https://github.com/conan-io/conan-docker-tools/blob/master/modern/base/Dockerfile?ref=kysa.me#L58). Более подробная статья на эту тему [тут](https://medium.com/@mccode/understanding-how-uid-and-gid-work-in-docker-containers-c37a01d01cf?ref=kysa.me).