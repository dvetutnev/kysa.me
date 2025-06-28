---
title: Boost.ASIO coroutines. Event
author: Dmitriy Vetutnev
date: August 2022
---
В этот раз реализую простейший [примитив синхронизации](https://github.com/lewissbaker/cppcoro?ref=kysa.me#single_consumer_event) двух короутин. Его назначение довольно просто: одна короутина приостанавливается на ожидании сигнала, другая этот сигнал отправляет. По сути это аналог пары `std::future<void>`/`std::promise<void>`. Короутины могут выполняться в разных потоках, ожидать сигнала может только одна короутина.

```cpp
#include "event.h"

Event event;

auto consumer = [&]() -> awaitable<void> {
	std::cout << "Waiting... ";
    boost::asio::any_io_executor executor = co_await boost::asio::this_coro::executor;
    co_wait event.wait(executor);
    std::cout << "event received, consumer is done."  << std::endl;
    co_return;
}

auto producer = [&]() -> awaitable<void> {
    std::cout << "Send event" << std::endl;
    event.set();
    co_return;
}

auto main = []() -> awaitable<void> {
    co_await(
      process() &&
      check()
    );
    co_return;
};

io_context ioContext;
co_spawn(ioContext, main(), detached);
ioContext.run();
```

Реализован он так:

```cpp
class Event
{
    enum class State { not_set, not_set_consumer_waiting, set };
    std::atomic<State> _state;
    std::move_only_function<void()> _handler;

public:
    Event() : _state{State::not_set} {}

    boost::asio::awaitable<void> wait(boost::asio::any_io_executor executor) {
        auto initiate = [this, executor]<typename Handler>(Handler&& handler) mutable
        {
            this->_handler = [executor, handler = std::forward<Handler>(handler)]() mutable {
                boost::asio::post(executor, std::move(handler));
            };

            State oldState = State::not_set;
            const bool isWaiting = _state.compare_exchange_strong(
                oldState,
                State::not_set_consumer_waiting,
                std::memory_order_release,
                std::memory_order_acquire);

            if (!isWaiting) {
                this->_handler();
            }
        };

        return boost::asio::async_initiate<
            decltype(boost::asio::use_awaitable), void()>(
                initiate, boost::asio::use_awaitable);
    }

    void set() {
        const State oldState = _state.exchange(State::set, std::memory_order_acq_rel);
        if (oldState == State::not_set_consumer_waiting) {
            _handler();
        }
    }
};
```

Механизм межпоточной инхронизации (строки 18 и 35) взят из [реализации cppcoro](https://github.com/lewissbaker/cppcoro/blob/master/include/cppcoro/single_consumer_event.hpp?ref=kysa.me#L92), пробуждение реализовано аналогично функции [schedule](https://kysa.me/boost-asio-coroutines-scheduler/), отправкой функтора на исполнение в _экзекьютер_. Особенность этой реализации в том, что она всегда приостанавливает короутину-подписчек, даже если к моменту вызова метода **wait** другой поток уже переключил состояние эвента методом **set**. Аналогично этому в [Boost](https://www.boost.org/doc/libs/1_80_0/doc/html/boost_asio/reference/basic_waitable_timer/async_wait.html?ref=kysa.me) работают асинхронные операции:

> Regardless of whether the asynchronous operation completes immediately or not, the completion handler will not be invoked from within this function. On immediate completion, invocation of the handler will be performed in a manner equivalent to using [post](https://www.boost.org/doc/libs/1_80_0/doc/html/boost_asio/reference/post.html?ref=kysa.me).

Это конечно не самая оптимальная реализация, но тем не мение ее можно использовать для реализации [sequence barrier](https://github.com/lewissbaker/cppcoro/?ref=kysa.me#sequence_barrier) и в дальнейшем кольцевого буфера.

```cpp
#include "event.h"
#include "schedule.h"

#include <boost/asio/io_context.hpp>
#include <boost/asio/detached.hpp>
#include <boost/asio/experimental/awaitable_operators.hpp>

#include <boost/test/unit_test.hpp>

BOOST_AUTO_TEST_CASE(test_Event)
{
    bool reachedPointA = false;
    bool reachedPointB = false;
    Event event;

    auto consumer = [&]() -> boost::asio::awaitable<void> {
        reachedPointA = true;

        boost::asio::any_io_executor executor = co_await boost::asio::this_coro::executor;
        co_await event.wait(executor);

        reachedPointB = true;
        co_return;
    };

    auto producer = [&]() -> boost::asio::awaitable<void> {
        BOOST_TEST(reachedPointA);
        BOOST_TEST(!reachedPointB);

        boost::asio::any_io_executor executor = co_await boost::asio::this_coro::executor;
        co_await schedule(executor);

        BOOST_TEST(reachedPointA);
        BOOST_TEST(!reachedPointB);

        event.set();
        co_return;
    };

    auto main = [&]() -> boost::asio::awaitable<void> {
        using namespace boost::asio::experimental::awaitable_operators;
        co_await(consumer() && producer());
        co_return;
    };

    boost::asio::io_context ioContext;
    boost::asio::co_spawn(ioContext, main(), boost::asio::detached);
    ioContext.run();

    BOOST_TEST(reachedPointA);
    BOOST_TEST(reachedPointB);
}

BOOST_AUTO_TEST_CASE(test_Event_set_before_wait)
{
    bool reachedPointA = false;
    bool reachedPointB = false;
    Event event;

    event.set();

    auto consumer = [&]() -> boost::asio::awaitable<void> {
        reachedPointA = true;

        boost::asio::any_io_executor executor = co_await boost::asio::this_coro::executor;
        co_await event.wait(executor);

        reachedPointB = true;
        co_return;
    };

    auto producer = [&]() -> boost::asio::awaitable<void> {
        BOOST_TEST(reachedPointA);
        BOOST_TEST(!reachedPointB);
        co_return;
    };

    auto main = [&]() -> boost::asio::awaitable<void> {
        using namespace boost::asio::experimental::awaitable_operators;
        co_await(consumer() && producer());
        co_return;
    };

    boost::asio::io_context ioContext;
    boost::asio::co_spawn(ioContext, main(), boost::asio::detached);
    ioContext.run();

    BOOST_TEST(reachedPointA);
    BOOST_TEST(reachedPointB);
}
```

Код [тут](https://github.com/dvetutnev/boost_asio_awaitable_ext?ref=kysa.me).

У этой статьи есть [продолжение](https://kysa.me/boost-asio-coroutines-event-rabota-nad-oshibkami/).