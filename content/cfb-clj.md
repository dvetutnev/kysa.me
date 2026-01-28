 [Clojure chunked binary sequences · GitHub](https://gist.github.com/stuartsierra/1472163)

# Inro

Мне давно хотелось освоить Лисп. В качестве реализации мой выбор пал на Clojure, как чаще используем (в отличии от Common Lisp, Scheme), а так же за наличие interop с Java-кодом из коробки (легко переиспользовать существующие Java библиотеки коих много). Ну а в качестве практической задачи я взял ту, которую недавно решал на C++: Microsoft Compound File Binary. Начну эту статью с описание что это за такой Compound File Binary (CFB).
# Что такое CFB
Compound File Binary (CFB) это майкрософтский контейнер, похожий на файловую систему FAT. Данные хранятся в **stream**-ах (аналог файла), сами **stream**-ы хранятся секторами. Множество **stream**-ов упорядочено в древовидную структуру аналогично дереву директорий/файлов файловой системе (FAT). Аналог директории называется **storage**.

Кроме самого контента, CFB содержит следующие компоненты:

- Header
- FAT
- DIFAT
- Directory
- MiniFAT/MiniStream

Единственной таблицей с привязанным местоположением (начало контейнера) является Header.

![[cfb-cloud.excalidraw]]
## Header
Таблица содержащая ссылки на остальные таблицы. Находиться в начале контейнера (файла). Так же в заголовке находиться начало DIFAT таблицы. Заголовок это единственная таблица с конкретным местоположением.

![[cfb-header.excalidraw]]
## FAT
Используется для выделения места для контента и служебных таблиц (Directory, DIFAT), в том числе для себя самой же. Каждой записи соответствует сектор в CFB, каждой **n**-ой записи FAT-таблицы соответствует смещение `offset = (n + 1) × SectorSize` в контейнере (файле) (заголовок не участвует в нумерации секторов). Сектора занятые stream-ми представлены FAT-цепочками, каждая запись в цепочке содержит номер следующего сектора либо метку ENDOFCHAIN. 

![[cfb-fat-chain.excalidraw]]

Исключение таблица DIFAT, она храниться связным списком (подробней ниже), соответствующие ей в FAT сектора содержат значение **DIFATSECID** (0xFFFFFFFC).

FAT-таблица хранится секторами как и все остальное в CFB.
Секторам занятым самой FAT-таблицей соответствует соответствуют записи **FATSECID** (0xFFFFFFFD) в ней же.

Расположена FAT-таблица (в отличии ФС FAT32 которая распологается в начале раздела HDD) может быть в любом месте, в том числе **не**обязательно непрерывным массивом секторов. Для локации ее секторов используется таблица DIFAT.

![[cfb-fat-location.excalidraw]]
## DIFAT
Описывает расположение секторов FAT-таблицы. Каждому сектору FAT-таблицы соответствует одна запись DIFAT-таблицы, содержащая номер сектора (FAT-таблицы). 

![[cfb-difat-fat.excalidraw]]

Первые 109 записей DIFAT-таблицы находяться в заголовке. Остальная часть DIFAT-таблицы храниться связным списком в DIFAT-секторах, последняя запись (4 байта) в DIFAT-секторе содержит номер следующего DIFAT-сектора. Номер первого сектора хвоста DIFAT-таблицы указан в заголовке.

Хвост таблицы DIFAT (начальная часть таблицы в заголовке), в отличии от остальных струкстур не описывается цепочками FAT, а хранится связным списком (последние 4 байта DIFAT сектора указывают на следующий сектор DIFAT), секторам занятым DIFAT соответствует записи DIFATSECID в FAT-таблице.

![[cfb-diifat.excalidraw]]


## Directory
В отличии FAT-системы на HDD, где директории хранятся как спец-файлы, тут единая структура на весь контейнер (CFB), описывающая все storage-ы (аналог в FAT32 каталог) и stream-ы (аналог файла).

![[cfb-directory.excalidraw]]

В каждом storage его дочерние элементы (storage-ы и stream-ы) хранятся как красно-черное дерево, поле **CHILDID** storage содержит корень этого дерева (номер записи в Directory stream), номера записей дочерних нод дерева лежат в полях **LEFTID/RIGHTID** верхней/родительской ноды.

Directory хранится FAT-цепочкой аналогично stream, начало этой цепочки находиться в заголовке контейнера.
## MiniStream/MiniFAT
Это механизм оптимизации хранения коротких stream-в. Место в FAT-таблице выделяется кратно размеру сектора CFB, т.е. 512 или 4096 байт. Поэтому короткие stream-ы хранятся отдельно со своей отдельной таблицей MiniFAT, с размером чанка 64 байт. Оба компонента (MiniFAT/MiniStream) хранятся FAT-цепочками. Номер первого сектора MiniStream находится в корневой (Root Entry) ноде directory, номер первого сектора MiniFAT в заголовке.

Данный проект учебно-демонстрационный, поэтому реализацию MiniFAT/MiniStream я делать не буду.

# Serializer
Особенностью CFB является то, у этой задачки множество решений: расположить компоненты можно множеством способов. Я выберу удобный для себя

![[cfb-fat-location2.excalidraw]]

Такой способ расположения позволят сгенерировать директорию за один проход (стартовые сектора стримов уже известны). Если же FAT-таблицу распологать в начале контейнера стартовые номера секторов стримов будут зависеть от их (стримов) размеров, т.к. записи описывающие саму таблицу будут расположены в начале FAT-таблица и их количество зависит от размера FAT-таблицы.
## FAT
Начнем с генерации FAT. Функция генерации одной цепочки:
```clojure
(defn make-fat-chain [start length]
  (let [start (inc start)
        end (+ start (dec length))]
    (conj (vec (range start end)) ENDOFCHAIN)))
```

Создание множества цепочке стримов. В качестве аргумента достаточно коллекции длин stream-ов.
```clojure
(defn make-proto-fat [sizes]
  (reduce (fn [[starts fat] size]
            (let [starts (conj starts (count fat))
                  chain (make-fat-chain (count fat) (calc-num-sector size))
                  fat (concat fat chain)]
              [starts fat]))
          [[] []] sizes))
```
Возвращает две коллекции:
- стартовые номера секторов FAT-цепочек
- плоскую коллекцию (все номера секторов в одной коллекции) "заготовку" FAT.

Вспомогательная функция `calc-num-sector`:
```clojure
(defn calc-num-sector
  ([length] (calc-num-sector length 1))
  ([length entry-size]
   (let [total-size (* length entry-size)
         num-full-sector (math/floor-div total-size SectorSize)]
     (if (zero? (mod total-size SectorSize))
       num-full-sector
       (inc num-full-sector)))))
```

Начало фат есть, теперь сгенирируем окончательная 
```clojure
(defn calc-num-difat-sector [num-fat-sector]
  (if (<= num-fat-sector difat-entry-in-header)
    0
    (let [num-full-sector (math/floor-div (- num-fat-sector difat-entry-in-header) 127)]
      (if (zero? (mod (- num-fat-sector difat-entry-in-header) 127))
        num-full-sector
        (inc num-full-sector)))))

(def fat-entry-peer-sector (/ SectorSize u32size))

(defn make-fat [proto-fat]
  (loop [num-fat-sector (calc-num-sector (count proto-fat) u32size)
         num-difat-sector (calc-num-difat-sector num-fat-sector)]
    (if (> (+ num-fat-sector (count proto-fat) num-difat-sector)
           (* num-fat-sector fat-entry-peer-sector))
      (recur (inc num-fat-sector)
             (calc-num-difat-sector (inc num-fat-sector)))
      (let [num-total-fat-entry (* num-fat-sector fat-entry-peer-sector)
            num-used-fat-entry (+ num-fat-sector (count proto-fat) num-difat-sector)
            num-pad-entry (- num-total-fat-entry num-used-fat-entry)
            start (+ (count proto-fat) num-difat-sector num-pad-entry)
            start-difat (if (zero? num-difat-sector)
                          ENDOFCHAIN
                          (count proto-fat))]
        [(concat proto-fat
                 (long-array num-difat-sector DIFATSEC)
                 (long-array num-pad-entry FREESEC)
                 (long-array num-fat-sector FATSEC))
         start num-fat-sector start-difat num-difat-sector num-pad-entry]))))
```
Вычисляется в цикле, если текущее число секторов не помещаются все компоненты (chains, FATSECID, DIFATSEC) запускаем итерацию с увеличенным числом FAT-секторов.
## Directory
# Parser
