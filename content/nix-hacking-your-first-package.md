---
title: Nix. Hacking your first package
author: Dmitriy Vetutnev
date: July 2023
---

# Intro

Киллер-фича Nix это воспроизводимое развертывание окружения. Одной командой:


```shell
$ nix develop
```


После этого мы получаем ровно такой же шел в котором и разрабатывался пакет. Это очень сильно упрощает жизнь т.к. пропадает головная боль с затаскиванием зависимостей и настройкой инфраструктуры. Иногда глянешь исходники на гитхабе и вроде сразу понятно что исправить нужно, но потом посмотришь на конфигурацию CI/DI, чтобы прикинуть как девелоперское окружение развернуть для запуска тестов, офигеешь, закроешь вкладку и забьешь. И мир чуточку лучше не стал. Т.е. проблема в довольно высоком начальном пороге входа. Nix же снижает его почти до нуля. И это очень сильно упрощает эксперименты, если для подготовки нужно выполнить одну команду, то почему бы не попробовать? А патчить будем как ни странно сам Nix.


# Problem


Problem
Nix не понимает пути в которых есть @.


```shell
$ nix eval --expr '/path/p@a'
error: syntax error, unexpected '@', expecting end of file

       at «string»:1:8:

            1| /path/p@
             |        ^
```


Хотя этот символ вполне допустим в пути ФС. Например это мешает развернуть Home Manager на машине с доменной авторизацией. Это не бага, это всего лишь излишне строгая проверка, а значит ее всегда можно отломать.


# Prepare environment


Клонируем репу, заходим в эту директорию и поднимаем шелл для разработки.


```shell
$ git clone https://github.com/NixOS/nix.git
$ cd nix
$ nix develop .#native-clangStdenvPackages
```


Окружение сборки на Clang выбрано потому что там есть преднастроенный clangd. Посмотреть доступные окружения можно командной nix flake show, нужный нам раздел devShells. Теперь запускаем сборку с мониторингом.


```shell
$ make clean && bear -- make -j$NIX_BUILD_CORES install
```


Bear эта такая штука, которая мониторит команды запуска компилятора и генерирует compile_commands.json. Этот файлик подхватывается clangd выступающим в роли lsp-сервера.


Теперь нам остается только запустить свою любимую IDE и попросить ее использовать в качестве lsp-сервера clangd, который она найдет первым в переменной окружения PATH. IDE при этом может быть любая, лишь бы умела в LSP. Ну или хотя бы смогла понять compile_commands.json. На этом шаге мы получаем проект развернутый в IDE с нормальной навигацией по исходникам (goto to definition/declaration).


# Hack hack hack


Поиск в исходниках текста сообщения об ошибке ничего не дал, оно генерируется динамически, придется трассировать. По идее, если происходит ошибка, то скорее всего будет выброшено исключение. Добавляем в конфигурацию отладчика (gdb) команду `catch throw` чтобы он останавливался в точке выброса исключения и несколько раз нажимаем F5 пока не увидим в локальных переменных что-то похожее на наш путь с @.


![](nix-hacking-your-first-package/nix_hacking_1.png)

И тут мы понимаем что вляпались в формальную грамматику и отправляемся читать документацию на [Bison](https://www.gnu.org/software/bison/manual/?ref=kysa.me).

Неожиданно, правда:

![](nix-hacking-your-first-package/you_are_here.png)

В парсере определен токен path, он может состоять из нескольких лексем PATH, HPATH, SPATH, PATH_END:

```bison
%type <e> start expr expr_function expr_if expr_op
%type <e> expr_select expr_simple expr_app
%type <list> expr_list
%type <attrs> binds
%type <formals> formals
%type <formal> formal
%type <attrNames> attrs attrpath
%type <string_parts> string_parts_interpolated
%type <ind_string_parts> ind_string_parts
%type <e> path_start string_parts string_attr
%type <id> attr
%token <id> ID
%token <str> STR IND_STR
%token <n> INT
%token <nf> FLOAT
%token <path> PATH HPATH SPATH PATH_END
%token <uri> URI
%token IF THEN ELSE ASSERT WITH LET IN REC INHERIT EQ NEQ AND OR IMPL OR_KW
%token DOLLAR_CURLY /* == ${ */
%token IND_STRING_OPEN IND_STRING_CLOSE
%token ELLIPSIS
```

Определение лексем предсказуемо находится в лексере. Здесь определена лексема PATH, которая может состоять из лексем PATH_CHAR, лексема же PATH_CHAR определена как множество конкретных символов:

```bison
ANY         .|\n
ID          [a-zA-Z\_][a-zA-Z0-9\_\'\-]*
INT         [0-9]+
FLOAT       (([1-9][0-9]*\.[0-9]*)|(0?\.[0-9]+))([Ee][+-]?[0-9]+)?
PATH_CHAR   [a-zA-Z0-9\.\_\-\+]
PATH        {PATH_CHAR}*(\/{PATH_CHAR}+)+\/?
PATH_SEG    {PATH_CHAR}*\/
HPATH       \~(\/{PATH_CHAR}+)+\/?
HPATH_START \~\/
SPATH       \<{PATH_CHAR}+(\/{PATH_CHAR}+)*\>
URI         [a-zA-Z][a-zA-Z0-9\+\-\.]*\:[a-zA-Z0-9\%\/\?\:\@\&\=\+\$\,\-\_\.\!\~\*\']+
```

Ну что же, давайте попробуем добавить туда нашу собачку @

```diff
--- a/src/libexpr/lexer.l
+++ b/src/libexpr/lexer.l
@@ -114,7 +114,7 @@ ANY         .|\n
 ID          [a-zA-Z\_][a-zA-Z0-9\_\'\-]*
 INT         [0-9]+
 FLOAT       (([1-9][0-9]*\.[0-9]*)|(0?\.[0-9]+))([Ee][+-]?[0-9]+)?
-PATH_CHAR   [a-zA-Z0-9\.\_\-\+]
+PATH_CHAR   [a-zA-Z0-9\.\_\-\+\@]
 PATH        {PATH_CHAR}*(\/{PATH_CHAR}+)+\/?
 PATH_SEG    {PATH_CHAR}*\/
 HPATH       \~(\/{PATH_CHAR}+)+\/?
```


Собираем, проверяем:


```shell
$ make install
$ outputs/out/bin/nix eval --expr '/path/p@a'
/path/p@a
```


# Deploy


Патч традиционно получаем при помощи git diff > enable_at_in_path.patch, теперь его нужно прикрутить к конфигурации, я это сделал через overlay

```nix
nixOverlay = final: prev:
{
  nix = prev.nix.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./enable_at_in_path.patch
    ];
  });
};

system = "x86_64-linux";
pkgs = import nixpkgs {
  inherit system;
  config.allowUnfree = true;
  overlays = [
    nixOverlay
  ];
};
```


# Retro

Вот так довольно простыми и воспроизводимыми действиями получилось внести нужное изменение и прикрутить его к своей системе. После множества мучений с установкой зависимостей выглядит это как "а что, так можно было?".
