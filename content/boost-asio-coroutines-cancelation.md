---
title: Boost.ASIO coroutines. Cancelation
author: Dmitriy Vetutnev
date: July 2023
---
В ASIO есть возможность [отмены асинхронных](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/core/cancellation.html?ref=kysa.me) операций и в частности [отмена](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/cpp20_coroutines.html?ref=kysa.me#boost_asio.overview.composition.cpp20_coroutines.coroutines_and_per_operation_cancellation) ожидания завершения короутин, запущенных через `co_spawn`. Типичный пример использования это ожидание события/данных с таймаутом:

```cpp
std::variant<std::size_t, std::monostate> results =
  co_await (
    async_read(socket, input_buffer, use_awaitable)
      || timer.async_wait(use_awaitable)
  );
 if (result.index() == 0) {
     // Read complete
 } else {
     // Timeout
 }
```

Это основное отличие от [cppcoro](https://github.com/lewissbaker/cppcoro?ref=kysa.me), в которой нет возможности отменить ожидание приостановленной короутины. Спроектированные [ранее](https://kysa.me/tag/coro/) примитивы синхронизации об отмене ничего не знают, поэтому добавим соответствующий функционал. В дальнейшем это позволит реализовать быстрое и корректное завершение работы.

На текущий момент ASIO поддерживает три [стратегии отмены](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/reference/cancellation_type.html?ref=kysa.me) короутин:

- terminal - самая простой тип отмены. Объект, для которого отменена асинхронная операция, должен остаться в безопасном состоянии для удаления и/или закрытия. Выполнение же других операций с объектом небезопасно.
- partial - после успешной отмены этого типа, объект для которого была отменена асинхронная операция должен остаться в предопределенном (валидном) состоянии и может быть использован для последующих операций. Возможны определенные сторонние эффекты. Стороне, запустившей асинхронную операцию, может быть возвращен частичный результат. Пример использование - возобновления передачи данных (загрузки большого файла) после предшествующей отмены.
- total - объект должен обеспечивать полную гарантию безопасности. После отмены этого типа объект находится (для вызывающей стороны) в том же состоянии, что и до операции.

Запрос отмены представлен битовой маской. Каждый тип отмены включает в себя требования к гарантиям безопасности более _слабых_ типов отмены. Объект обеспечивающий безопасную **partial**-отмену должен также удовлетворять требованиям **terminal**-отмены, а объект поддерживающий total-отмену должен  в свою очередь удовлетворять требования **partial** и **total**.

Теперь примерим эти требования на [MultiProducerSequencer](https://kysa.me/boost-asio-coroutines-multiproducersequencer/) как на самый сложный примитив синхронизации. У этого объекта есть две (с половиной) асинхронных операции: `claim_one`/`claim_up_to` - захват слота(ов) продюсерами и `wait_until_published` - ожидание потребителей публикации продюсера записанных слотов. Операции `claim_one`/`claim_up_to` первым делом инкрементируют счетчик `MultiProducerSequencer::_nextToClaim` и запрашивают (асинхронно) свободный слот в барьере чтения. Если в этот момент отменить захват слота, то счетчик `nextToClaim` останется в измененном состоянии, последующие захваты слотов будут выполнятся относительно этого значения, но ни один продюсер не опубликует номер слота равный предшествующему значению `nextToClaim` перед отменой захвата слота. И в итоге при последующих операциях с этим секвенсором все встанет колом: потребитель будет ждать публикации номера слота, который никто уже не опубликует. С такой структурой не получается дать полные гарантии безопасности отмены. Поэтому остановимся на самом простом варианте отмены - **terminal**, который по умолчанию разрешен для короутин запущенных через [co_spawn](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/cpp20_coroutines.html?ref=kysa.me#boost_asio.overview.composition.cpp20_coroutines.coroutines_and_per_operation_cancellation).

# [Event](https://kysa.me/boost-asio-coroutines-event-rabota-nad-oshibkami/)

Реализовывать отмену начнем с базового примитива синхронизации [Event](https://kysa.me/boost-asio-coroutines-event-rabota-nad-oshibkami/), в конечном счете нужно отменять операции `co_await event.wait(executor)`. Сначала определимся с состояниями эвента.

```plantuml
[*] --> not_set
not_set --> not_set_consumer_waiting : co_await wait
not_set --> set : set
not_set --> canceled : cancel
not_set_consumer_waiting --> set : set
not_set_consumer_waiting --> canceled : cancel
set --> [*]
canceled --> [*]
```

К уже существующим состояниям добавилось четвертое - `canceled`. В него эвент попадает если запрос на отмену пришел раньше чем продюсер вызвал метод `set`. Т.к. мы реализуем только базовые гарантии безопасности отмены (terminal), то состояние `canceled` конечное, объект после этого можно удалить, но другие операции с ним не допускаются. Объекту нужно как-то передать запрос отмены, для этого добавим соответствующий метод `cancel`. После его вызова подписчик, приостановленный на вызове `co_await event.wait`, пробуждается и ему нужно как-то узнать что ожидание было отменено. Тут ничего нового я изобретать не буду и для этой сигнализации буду передавать ошибку `boost::asio::error::operation_aborted` по аналогии с закрытием сокета. Вызов подписчиком `co_await event.wait` в этом случаи завершается исключением `boost::system::system_error` с соответствующим `errc`. При необходимости событие отмены [можно получить](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/cpp20_coroutines.html?ref=kysa.me#boost_asio.overview.composition.cpp20_coroutines.error_handling) как `error_code` без выброса исключения.

Опишем нужное поведение тестами:

```cpp
BOOST_AUTO_TEST_CASE(install_cancellation_slot)
{
    Event event;

    auto main = [&]() -> awaitable<void> {
        auto result = co_await(
            event.wait(use_awaitable) ||
            async_sleep(50ms)
            );
        BOOST_TEST(result.index() == 1); // timer first
    };

    io_context ioContext;
    co_spawn(ioContext, main(), [](std::exception_ptr ex){ if (ex) std::rethrow_exception(ex); });
    ioContext.run();
}
```

При помощи перегрузки [`operator ||` для `awaitable<R>`](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/cpp20_coroutines.html?ref=kysa.me#boost_asio.overview.composition.cpp20_coroutines.co_ordinating_parallel_coroutines) параллельно запускаются две асинхронные операции, ожидание эвента и ожидание таймера (спрятано в `async_sleep`). Для эвента никто не вызывает метод `set` и первой завершается короутина `async_sleep(50ms)`, ожидание эвента автоматически отменяется. И пример с явной отменой ожидания эвента:

```cpp
BOOST_AUTO_TEST_CASE(cancel_example)
{
    Event event;

    auto consumer = [&]() -> awaitable<void> {
        auto [ec] = co_await event.wait(as_tuple(use_awaitable)); // -> std::tuple<boost::system::error_code>
        BOOST_TEST(ec == error::operation_aborted);
    };

    auto timeout = [&]() -> awaitable<void> {
        co_await async_sleep(50ms);
        event.cancel();
    };

    io_context ioContext;
    co_spawn(ioContext, consumer(), [](std::exception_ptr ex){ if (ex) std::rethrow_exception(ex); });
    co_spawn(ioContext, timeout(), [](std::exception_ptr ex){ if (ex) std::rethrow_exception(ex); });
    ioContext.run();
}
```

В нем используется [адаптер `as_tuple`](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/token_adapters.html?ref=kysa.me#boost_asio.overview.composition.token_adapters.as_tuple) для получения ошибки в форме `error_code` вместо исключения. В первом же примере ошибка остается в короутине `operator ||` согласно его семантике.

```cpp
class Event
{
    enum class State { not_set, not_set_consumer_waiting, set, canceled };
    mutable std::atomic<State> _state;
    mutable std::move_only_function<void(system::error_code)> _handler;

public:
    Event() : _state{State::not_set} {}

    Event(const Event&) = delete;
    Event& operator=(const Event&) = delete;

    template<completion_token_for<void(system::error_code)> CompletionToken>
    auto wait(CompletionToken&& completionToken) const {
        auto initiate = [this](auto&& handler) mutable
        {
            auto slot = get_associated_cancellation_slot(handler, cancellation_slot());
            if (slot.is_connected()) {
                slot.assign([this](cancellation_type)
                            {
                                const_cast<Event*>(this)->cancel();
                            });
            }

            this->_handler = [executor = get_associated_executor(handler),
                              handler = std::move(handler)](system::error_code ec) mutable
            {
                auto wrap = [handler = std::move(handler), ec]() mutable
                {
                    handler(ec);
                };
                post(executor, std::move(wrap));
            };

            State oldState = State::not_set;
            const bool isWaiting = _state.compare_exchange_strong(
                oldState,
                State::not_set_consumer_waiting,
                std::memory_order_release,
                std::memory_order_acquire);

            if (!isWaiting) {
                auto ec = (oldState == State::canceled) ? system::error_code{error::operation_aborted}
                                                        : system::error_code{}; // not error
                this->_handler(ec);
            }
        };

        return async_initiate<
            CompletionToken, void(system::error_code)>(
                initiate, completionToken);
    }

    void set() {
    //
    }

    void cancel() {
    //
    }
};
```

Добавлено новое состояние `canceled` и в сигнатуру обработчика добавлен `error_code` (5). В методе `wait` после попытки перевода в состояние `not_set_consumer_waiting` добавлен выбор аргумента для вызова обработчика если в состояние `not_set_consumer_waiting` перевести эвент не удалось (43,44). Если эвент раньше оказался в состоянии `canceled`, то обработчик будет вызван с ошибкой `boost::asio::error::operation_aborted`. Если же продюсер раньше успел переключить в состояние `set`, то соответственно с пустым `error_code`. Также устанавливается свой обработчик в слот отмены (17-23) чтобы автоматически получать запрос отмены. Заодно метод `wait` приведен к каноничной для ASIO форме шаблона и теперь может принимать различные [CompletionToken](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/model/completion_tokens.html?ref=kysa.me) и их [адаптеры](https://www.boost.org/doc/libs/1_82_0/doc/html/boost_asio/overview/composition/token_adapters.html?ref=kysa.me), параллельно избавились от необходимости передавать экзекьютор.

Изменений в методе `set` намного больше:

```cpp
void set() {
State oldState = State::not_set;
bool isSet = _state.compare_exchange_strong(
        oldState,
        State::set,
        std::memory_order_release,
        std::memory_order_acquire); // see change of handler if current state is not_set_consumer_waiting

    if (isSet) {
        return; // set before wait
    }
    else if (oldState == State::not_set_consumer_waiting) {
        // wait win
        isSet = _state.compare_exchange_strong(
            oldState,
            State::set,
            std::memory_order_relaxed,
            std::memory_order_relaxed);

        if (isSet) {
            auto dummy = system::error_code{}; // not error
            _handler(dummy); // set after wait
            return;
        }
    }

    assert(oldState == State::canceled); // cancel before set and wait
}
```

Первым делом он пытается переключить состояние в `set`, если получилось работа метода завершается, обработчик будет вызыван во время вызова `co_await event.wait()` (10). Если не получилось, то возможно состояние уже переключено в `not_set_consumer_waiting` (подписчик ожидает событие), в этом случаи повторно пытаемся переключить состояние в `set`. Если в этот раз удалось, то запускаем обработчик для пробуждения ожидающего на вызове `co_await event.wait()`. В противном случаи эвент уже был переключен в состояние `canceled` и просто завершаем работу. Такая сложная конструкция потребовалась для реализации машины состояний приведенной на диаграмме выше.

При первой попытке переключения состояния в `set` для неудачи используется семантика _acquire_ чтобы гарантировано увидеть обработчик `Event::_handler` записанный методом `wait`. Для варианта у удачным переключением используется семантика _release_, т.к. семантика для неудачи не может быть строже семантики удачного выполнения CAS (но это не точно). При второй попытке переключения состояния уже ничего синхронизировать не нужно и используется максимально ослабленная семантика `relaxed`.

Метод `cancel` реализован аналогично методу `set`, их работа по сути симметрична.

```cpp
void cancel() {
    State oldState = State::not_set;
    bool isCancel = _state.compare_exchange_strong(
        oldState,
        State::canceled,
        std::memory_order_release,
        std::memory_order_acquire); // see change of handler if current state is not_set_consumer_waiting

    if (isCancel) {
        return; // cancel before wait
    }
    else if (oldState == State::not_set_consumer_waiting) {
        // wait win
        isCancel = _state.compare_exchange_strong(
            oldState,
            State::canceled,
            std::memory_order_relaxed,
            std::memory_order_relaxed);

        if (isCancel) {
            system::error_code ec = error::operation_aborted;
            _handler(ec); // cancel after wait, but before
            return;
        }
    }

    assert(oldState == State::set); // set before wait and cancel
}
```

# [SequenceBarrier](https://kysa.me/boost-asio-coroutines-sequencebarrier/)

Этот примитив синхронизации конструктивно собой представляет связанный список авайтеров, а сами авайтеры расположены во фреймах короутин `wait_until_published`. В любой момент времени к ним могут быть обращения в методах `add_awaiter`/`publish` и нужно обеспечить валидность авайтеров. Т.е. фрейм короутины не должен быть разрушен до тех пор пока есть вероятность обращения к авайтеру.

Алгоритмы и синхронизация барьера построены на том, что меняются только поле `SequenceBarrier:_published` и список `SequenceBarrier::_awaiters`, сами же авайтеры до пробуждения в методах `add_awaiter`/`publish` остаются неизменными. В такой конструкции удалить один авайтер из списка довольно проблематично (если вообще возможно). Но можно расширить рамки и реализовать только самую простую стратегию отмены - **terminal**.  Добавим в барьер терминальное состояние, при переходе в которое отменяются все операции ожидания короутин `wait_until_published`, и метод `close()`, переводящий барьер в это состояние. Также в методе-короутине `wait_until_published` добавим установку в слот отмены обработчика, который будет вызывать метод `close()`, тем самым отменяя все остальные вызовы `wait_until_published`.

Метод `close`:

```cpp
void cancel_awaiters(Awaiter* awaiters)
{
    while (awaiters != nullptr)
    {
        Awaiter* next = awaiters->next;
        awaiters->cancel();
        awaiters = next;
    }
}

void close()
{
    _isClosed.exchange(true, std::memory_order_seq_cst);
    Awaiter* awaiters = _awaiters.exchange(nullptr, std::memory_order_seq_cst);
    cancel_awaiters(awaiters);
}
```

Тут все просто: поднимаем флажок закрытия, захватываем список авайтеров и пробуждаем их (если есть что) методом `cancel`, который вызывает `event.cancel()`. Обе операции выполняются с семантикой seq_cst для синхронизации с методами `add_awaiter`/`publish`.

В методе `wait_until_published` в слот отмены устанавливается обработчик (8-12) и запускается ожидание авайтера в параллельной короутине (19-25).

```cpp
awaitable wait_until_published(TSequence targetSequence) const
{
    TSequence lastPublished = last_published();
    if (!Traits::precedes(lastPublished, targetSequence)) {
        co_return lastPublished;
    }

    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ const_cast(this)->close(); });
    }

    auto awaiter = Awaiter{targetSequence};
    add_awaiter(&awaiter);

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    // We explicit call event.close() from awaiter
    lastPublished = co_await co_spawn(
        co_await this_coro::executor,
        awaiter.wait(),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );

    co_return lastPublished;
}
```

Запуск параллельной короутины производится с пустым слотом отмены. Это необходимо чтобы вызов `co_await event.wait()` не затер наш обработчик отмены, т.к. слот для него один для всей цепочки короутин, запущенной одним вызовом `co_spawn`.

Список авайтеров в любой момент может быть захвачен в методах `add_awaiter`/`publish` и быть недоступен в методе `close`, поэтому этой паре методов также нужно обрабатывать закрытие барьера и отменять авайтеры.

```cpp
void add_awaiter(Awaiter* awaiter)
{
    TSequence targetSequence = awaiter->targetSequence;
    Awaiter* awaitersToRequeue = awaiter;
    Awaiter** awaitersToRequeueTail = &(awaiter->next);

    TSequence lastKnownPublished;
    Awaiter* awaitersToResume;
    Awaiter** awaitersToResumeTail = &awaitersToResume;

    bool isClosed = false;

    do
    {
        // Enqueue awaiters
        
        lastKnownPublished = _lastPublished.load(std::memory_order_seq_cst);
        isClosed = _isClosed.load(std::memory_order_seq_cst);
        if (Traits::precedes(lastKnownPublished, targetSequence) &&
            !isClosed)
        {
            // None of the the awaiters we enqueued have been satisfied yet.
            break;
        }
        
        // Reacquire awaiters
        auto* awaiters = _awaiters.exchange(nullptr, std::memory_order_acquire);
        
        // list of awaiters and split them into 'requeue' and 'resume' lists.
        
    } while (awaitersToRequeue != nullptr && !isClosed);
    
    // Resume the awaiters that are ready
    resume_awaiters(awaitersToResume, lastKnownPublished);
    if (isClosed) {
        cancel_awaiters(awaitersToRequeue);
    }
}
```

После вставки авайтера(ов) в дополнение к загрузке последнего опубликованного номера, добавлено чтение флажка закрытия (19). Если он поднят, то выполняется захват списка авайтеров и его обработка вне зависимости от того, что опубликовал продюсер. После этого основной цикл метода останавливается, готовые для пробуждения просыпаются, остальные авайтеры в списке `awaiterToRequeue` отменяются. Синхронизация с методом `close` аналогична синхронизации с методом `publish`: либо текущий тред увидит последнее состояние флажка отмены, либо тред выполняющий `close()` увидит последний вставленный авайтер. Для этого пары операций запись флага / захват списка авайтеров, и вставка авайтера(ов) / чтения флага выполняются с семантикой `seq_cst`.

```cpp
void publish(TSequence sequence)
{
	_lastPublished.store(sequence, std::memory_order_seq_cst);
    Awaiter* = _awaiters.exchange(nullptr, std::memory_order_seq_cst);
    if (!awaiters) {
        return;
    }

    Awaiter* awaitersToRequeue;
    Awaiter** awaitersToRequeueTail = &awaitersToRequeue;

    Awaiter* awaitersToResume;
    Awaiter** awaitersToResumeTail = &awaitersToResume;
    
    // Split list of awaiters
    
    // null-terminate the two lists.
    *awaitersToRequeueTail = nullptr;
    *awaitersToResumeTail = nullptr;

    if (awaitersToRequeue)
    {
        Awaiter* oldHead = nullptr;
        while (!_awaiters.compare_exchange_weak(
            oldHead,
            awaitersToRequeue,
            std::memory_order_seq_cst,
            std::memory_order_relaxed))
        {
            *awaitersToRequeueTail = oldHead;
        }
    }
    
    resume_awaiters(awaitersToResume, sequence);
    if (_isClosed.load(std::memory_order_seq_cst))
    {
        awaiters = _awaiters.exchange(nullptr, std::memory_order_seq_cst);
        cancel_awaiters(awaiters);
    }
}
```

В методе `publish` доработок меньше: добавлена проверка флажка закрытия и захват/отмена авайтеров если он поднят (41-50). Загрузка флажка и сохрание перед этим списка ожидающих авайтеров (27) происходит с семантикой `seq_cst`, здесь используется аналогичная синхронизация: либо текущий тред видит последнее состояние флажка, либо тред выполняющий `close` видит самый последний авайтер.

# [SingleProducerSequencer](https://kysa.me/boost-asio-coroutines-singleproducersequencer/)

В секвенсоре находиться барьер продюсера и ссылка на барьер потребителя. После закрытия одного из барьеров продолжение работы очереди невозможно, поэтому при обнаружении этой ситуации нужно также закрыть второй барьер (чтобы остановить асинхронные операции с ним). Тут все довольно просто, добавляем метод `close`, закрывающий барьеры, и устанавливаем обработчик, вызывающий этот метод, в слот отмены во всех асинхронных методах, запросы `wait_until_published` к барьерам выполняются через `co_spawn` с пустым слотом отмены. Довольно похоже SequenceBarrier.

```cpp
awaitable<TSequence> claim_one()
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ this->close(); });
    }

    const auto toClaim = static_cast<TSequence>(_nextToClaim - _bufferSize);

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    co_await co_spawn(
        co_await this_coro::executor,
        _consumerBarrier.wait_until_published(toClaim),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );

    co_return _nextToClaim++;
}
```

```cpp
awaitable<SequenceRange<TSequence, Traits>> claim_up_to(std::size_t count)
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ this->close(); });
    }

    const auto toClaim = static_cast<TSequence>(_nextToClaim - _bufferSize);

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    const TSequence consumerPosition = co_await co_spawn(
        co_await this_coro::executor,
        _consumerBarrier.wait_until_published(toClaim),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );
    const TSequence lastAvailableSequence =
        static_cast<TSequence>(consumerPosition + _bufferSize);

    const TSequence begin = _nextToClaim;
    const std::size_t availableCount = static_cast<std::size_t>(lastAvailableSequence - begin) + 1;
    const std::size_t countToClaim = std::min(count, availableCount);
    const TSequence end = static_cast<TSequence>(begin + countToClaim);

    _nextToClaim = end;
    co_return SequenceRange&TSequence, Traits&{begin, end};
}
```

```cpp
awaitable<TSequence> wait_until_published(TSequence sequence) const
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ const_cast<SingleProducerSequencer*>(this)->close(); });
    }

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    co_return co_await co_spawn(
        co_await this_coro::executor,
        _producerBarrier.wait_until_published(sequence),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );
}
```

# [SequenceBarrierGroup](https://kysa.me/boost-asio-coroutines-sequencer-and-multiple-consumers/)

В этом классе содержаться ссылки на барьеры, его метод `wait_until_published` сам запускает группу короутин через `co_spawn` и дожидается их завершения. Запрос отмены автоматически передается в короутины этой группы. После завершения всех короутин остается выяснить по какой причине они завершились, и если они завершились из-за отмены просигнализировать об этом на верх (33-37).

```cpp
awaitable<TSequence> wait_until_published(TSequence targetSequence) const
{
    using experimental::make_parallel_group;
    using experimental::wait_for_one_error;

    auto executor = co_await this_coro::executor;

    auto makeOperation = [executor, targetSequence](BarrierRef barrier)
    {
        // As args, not capture
        auto coro = [](BarrierRef barrier, TSequence targetSequence) -> awaitable<TSequence>
        {
            co_return co_await barrier.get().wait_until_published(targetSequence);
        };

        return co_spawn(executor, coro(barrier, targetSequence), deferred);
    };

    using Operation = decltype(makeOperation(_barriers.front()));
    std::vector<Operation> operations;

    operations.reserve(_barriers.size());
    for (BarrierRef barrier : _barriers) {
        operations.push_back(makeOperation(barrier));
    }

    auto [order, exceptions, published] =
        co_await make_parallel_group(std::move(operations))
            .async_wait(wait_for_one_error(), use_awaitable);

    (void)order;

    if (std::ranges::any_of(_barriers,
                           [](BarrierRef b) { return b.get().is_closed(); }))
    {
        throw system::system_error{error::operation_aborted};
    }

    auto isThrow = [](const std::exception_ptr& ex) -> bool { return !!ex; };
    if (auto firstEx = std::find_if(std::begin(exceptions), std::end(exceptions), isThrow);
        firstEx != std::end(exceptions))
    {
        if (std::any_of(firstEx, std::end(exceptions), isThrow)) {
            throw multiple_exceptions(*firstEx);
        } else {
            std::rethrow_exception(*firstEx);
        }
    }

    auto it = std::min_element(std::begin(published), std::end(published),
                                   [](TSequence a, TSequence b) { return Traits::precedes(a, b); } );
    co_return *it;
}
```

Самый простой вариант - это проверить состояния барьеров, такой функционал естественен для них и легко реализуется. Чтобы обработать ситуацию в которой один из барьеров закрывается по сторонним причинам, запуск группы короутин выполняется с токеном отмены `wait_for_one_error` (29), в этом режиме если одна из операций завершиться ошибкой все остальные автоматически отменяются, что нам и надо.

# [MultiProducerSequencer](https://kysa.me/boost-asio-coroutines-multiproducersequencer/)

В секвенсоре для нескольких продюсеров находится список авайтеров, аналогичный SequenceBarrier и ссылка на барьер чтения. Реализация отмены для этого секвенсора представляет собой объедение функционала отмена для барьера и секвенсора для одного продюсера. Добавлен метод `close` и в асинхронных операция в слот устанавливается свой обработчик, вызывающий этот метод. Синхронизация та же, что и для барьера: либо тред, выполняющий `close`, увидит последний добавленный авайтер, либо тред, выполняющий `add_awaiter` / `resume_ready_awaiters` увидит поднятый флажок закрытия.

```cpp
awaitable<TSequence> claim_one()
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ this->close(); });
    }

    const TSequence claimedSequence = _nextToClaim.fetch_add(1, std::memory_order_relaxed);

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    co_await co_spawn(
        co_await this_coro::executor,
        _consumerBarrier.wait_until_published(claimedSequence - buffer_size()),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );

    co_return claimedSequence;
}
```

```cpp
awaitable<SequenceRange<TSequence, Traits>> claim_up_to(std::size_t count)
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ this->close(); });
    }

    count = std::min(count, buffer_size());
    const TSequence first = _nextToClaim.fetch_add(count, std::memory_order_relaxed);
    auto claimedRange = SequenceRange<TSequence, Traits>{first, first + count};

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    co_await co_spawn(
        co_await this_coro::executor,
        _consumerBarrier.wait_until_published(claimedRange.back() - buffer_size()),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );

    co_return claimedRange;
}
```

```cpp
awaitable<TSequence> wait_until_published(TSequence sequence,
                                          TSequence lastKnownPublished) const
{
    auto cs = co_await this_coro::cancellation_state;
    auto slot = cs.slot();
    if (slot.is_connected()) {
        slot.assign([this](cancellation_type){ const_cast(this)->close(); });
    }

    auto awaiter = Awaiter{targetSequence, lastKnownPublished};
    add_awaiter(&awaiter);

    // Spawn new coro-thread with dummy cancellation slot and co_await-ed its
    // We explicit call event.close() from awaiter
    TSequence available = co_await co_spawn(
        co_await this_coro::executor,
        awaiter.wait(),
        bind_cancellation_slot(
            cancellation_slot(),
            use_awaitable)
        );

    co_return available;
}
```

```cpp
void add_awaiter(Awaiter* awaiter) const
{
    TSequence targetSequence = awaiter->targetSequence;
    TSequence lastKnownPublished = awaiter->lastKnownPublished;

    Awaiter* awaitersToEnqueue = awaiter;
    Awaiter** awaitersToEnqueueTail = &(awaiter->next);

    Awaiter* awaitersToResume;
    Awaiter** awaitersToResumeTail = &awaitersToResume;

    bool isClosed = false;

    do
    {
        // Enqueue awaiters
        awaitersToEnqueueTail = &awaitersToEnqueue;
        
        while (_published[(lastKnownPublished + 1) & _indexMask]
               .load(std::memory_order_seq_cst) == (lastKnownPublished + 1))
        {
            ++lastKnownPublished;
        }
        isClosed = _isClosed.load(std::memory_order_seq_cst);

        if (!Traits::precedes(lastKnownPublished, targetSequence)
            || isClosed)
        {
            Awaiter* awaiters = _awaiters.exchange(nullptr, std::memory_order_acquire);
            
            // Split list of awaiters
            // Calc minDiff
            
            targetSequence = 
                static_cast<TSequence>(lastKnownPublished + minDiff);
        }
        
        // Null-terminate list of awaiters to enqueue.
        *awaitersToEnqueueTail = nullptr;

    } while (awaitersToEnqueue != nullptr && !isClosed)

    // Null-terminate awaiters to resume.
    *awaitersToResumeTail = nullptr;

    // Finally, resume any awaiters we've found that are ready to go.
    resume_awaiters(awaitersToResume, lastKnownPublished);
    if (isClosed) {
        cancel_awaiters(awaitersToEnqueue);
    }
}
```

```cpp
void resume_ready_awaiters()
{
    Awaiter* awaiters = _awaiters.exchange(nullptr, std::memory_order_seq_cst);
    if (awaiters == nullptr) {
        return;
    }

    TSequence lastKnownPublished;

    Awaiter* awaitersToResume;
    Awaiter** awaitersToResumeTail = &awaitersToResume;

    Awaiter* awaitersToRequeue;
    Awaiter** awaitersToRequeueTail = &awaitersToRequeue;

    bool isClosed = false;

    do
    {
        lastKnownPublished = last_published_after(awaiters->lastKnownPublished);
        
        // Split awaiters
        // Calc minDiff
        
        // Null-terinate the requeue list
        *awaitersToRequeueTail = nullptr;

        if (awaitersToRequeue != nullptr)
        {
            // Enqueue awaitersToRequeue
            
            // Reset the awaitersToRequeue list
            awaitersToRequeueTail = &awaitersToRequeue;
            
            // Check published
            
            isClosed = _isClosed.load(std::memory_order_seq_cst);
            if (isClosed && awaiters == nullptr) {
                awaiters = _awaiters.exchange(nullptr, std::memory_order_acquire);
            }
        }
    } while(awaiters != nullptr && !isClosed);

    // Null-terminate list of awaiters to resume.
    *awaitersToResumeTail = nullptr;

    resume_awaiters(awaitersToResume, lastKnownPublished);
    if (isClosed) {
        cancel_awaiters(awaiters);
    }
}
```

Основное отличие короутин ASIO от cppcoro это наличие механизма, который позволяет [оборвать выполнение всей цепочки](https://github.com/lewissbaker/cppcoro/issues/131?ref=kysa.me#issuecomment-557936671) короутин, запущенной через `co_spawn`. Для реализации подобного механизма с cppcoro потребовалось бы каждой короутине явно передавать [токен отмены](https://github.com/lewissbaker/cppcoro?ref=kysa.me#Cancellation), а самим короутинам периодически явно проверять токен и/или регистрировать в нем callback, отменяющий последнюю асинхронную операцию. Изначально алгоритмы синхронизации в барьере/секвенсоре из cppcoro вообще на отмену асинхронных операций не расчитанны, поэтому при переносе алгоритмов из cppcoro потребовались дополнительные усилия по реализации отмены в виде установки своих обработчиков отмены, а где-то принудительное кастование к не константной ссылке, что само по себе немного фу. Так же не получилось сделать _чистую_ отмену (в терминологии ASIO **total**), отмена одной операции переводит весь примитив синхронизации в терминальное состояние, что может вызывать потерю данных.

Но возможная потеря данных в исключительных ситуациях для моих задач допустимое поведение. Разрабатываемые (перенесенные из cppcoro) примитивы синхронизации я задумывал использовать в качестве lockfree очередей внутри клиента для [NATS](https://docs.nats.io/nats-concepts/overview?ref=kysa.me). Особенностью его протокола является то, что в нем нет подтверждений и при большинстве ошибок сервер [отключает](https://docs.nats.io/reference/reference-protocols/nats-protocol?ref=kysa.me#+ok-err) клиент. Даже если клиент сразу переподключится, узнать какие сообщения доставлены, а какие нет, он не может. Т.е. уже на уровне протокола нельзя гарантировать отсутствие потерь в исключительных ситуациях, если же требуется гарантированная доставка данных, то это реализуется прикладным протоколом более высокого уровня, например [JetStream](https://docs.nats.io/nats-concepts/jetstream?ref=kysa.me).

Раз гарантированная доставка данных все равно невозможна, то можно реализовать довольно простое завершение работы клиента при ошибках. Ниже приведены наброски короутин обрабатывающий IO с сервером.

```cpp
auto tx(TXQueue&& txQueue) -> awaitable<void>
{
    std::size_t nextToRead = 0;
    bool isEOF = false;
    do
    {
        std::size_t available = 
            co_await txQueue.wait_until_publish(nextToRead, nextToRead - 1);
        do
        {
            Message& msg = txBuffer[nextToRead & indexMask];
            co_await async_write(socket, to_buffer(msg), use_awaitable);
            isEOF = isEndOfStream(msg);
        } while (nextToread++ != available);
        
        txQueue.publish(available);
        
    } while (!isEOF);
}
```

В короутину-передатчик передается RAII-обертка очереди как _rvalue,_ ее деструктор закрывает очередь (уведомляет другую сторону, что слать сюда больше не нужно) при завершении короутины.

```cpp
auto rx() -> awaitable<void>
{
    for (;;) {
	    Message msg = co_await get_message(); // async read socket
        if (msg.type == SrvMsg::MSG) {
            if (auto sub = find_subscribe(msg.subject) !!sub) {
                co_await sub.push(std::move(msg));
            else {
                // Unexpected message
            }
        } else if (msg.type == SrvMsg::PING) {
            co_await pong();
        } else {
            break; // Server sent `-ERR`
        }
    }
}
```

Теперь их достаточно просто запустить:

```cpp
using experimantal::awaitable_operators;
co_await(tx() || rx());
```

Если соединение с сервером оборвется, то обе короутины завершаться автоматически, в том числе если короутина-передатчик была приостановлена на ожидании появления в очереди сообщений для отправки. Теперь остается дождаться короутин, обрабатывающих подписки и после их завершения все используемые объекты можно безопасно удалить. На этом остановка закончена. Без механизма отмены пришлось бы цикле передачи и в цикле обработки подписки вводить флажок закрытия и дополнительные ветки кода для _поедания_ всех необработанных сообщения из очереди.

Разработка NATS-клиента будет продолжена в следующих статьях, а на этом пока все. Код [тут](https://github.com/dvetutnev?ref=kysa.me).