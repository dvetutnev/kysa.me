---
title: Boost.ASIO coroutines. Scheduler
author: Dmitriy Vetutnev
date: June 2022
---
Для реализации примитивов синхронизации короутин (например [sequence_barrier](https://github.com/andreasbuhr/cppcoro?ref=kysa.me#sequence_barrier)) нужен [механизм для приостановки](https://github.com/andreasbuhr/cppcoro?ref=kysa.me#Scheduler-concept) короутины до следующей итерации цикла событий. По сути это аналог функции [pthread_yield](https://man7.org/linux/man-pages/man3/pthread_yield.3.html?ref=kysa.me) для синхронного кода.

Пример использования выглядит как-то так:

```c++
do {
    co_await schedule(executor);
    do_some_thing();
} while(condition);
```

а типовая реализация так:

```cpp
struct Awaiter
{
    boost::asio::any_io_executor executor;

    bool await_ready() { return false; }
    void await_suspend(std::coroutine_handle<> handle) {
        boost::asio::post(executor, [handle]() mutable
        {
            handle.resume();
        });
    }
    void await_resume() {}
}

Awaiter schedule(boost::asio::any_io_executor executor) {
	return Awaiter{executor};
}
```

Но для короутин **boost::asio::awaitable** это [не подходит.](https://github.com/lewissbaker/cppcoro/issues/131?ref=kysa.me#issuecomment-557936671) Поэтому сделаем реализацию средствами Boost, используя функцию [boost::asio::async_initiate](https://www.boost.org/doc/libs/develop/doc/html/boost_asio/overview/model/completion_tokens.html?ref=kysa.me) инстанционирующую специализацию класса [boost::asio::async_result](https://www.boost.org/doc/libs/1_80_0/doc/html/boost_asio/reference/async_result.html?ref=kysa.me) для [use_awaitable](https://github.com/boostorg/asio/blob/boost-1.80.0/include/boost/asio/impl/use_awaitable.hpp?ref=kysa.me#L258).

```cpp
inline auto schedule(boost::asio::any_io_executor executor) -> boost::asio::awaitable<void>
{
    auto initiate = [executor]<typename Handler>(Handler&& handler) mutable
    {
        boost::asio::post(executor, [handler = std::forward<Handler>(handler)]() mutable
        {
            handler();
        });
    };

    return boost::asio::async_initiate<
            decltype(boost::asio::use_awaitable), void()>(
                initiate, boost::asio::use_awaitable);
}
```

В async_initiate передается функтор (выполняющий планирование пробуждения и вызова обработчика завершения) и экземпляр [use_awaitable](https://www.boost.org/doc/libs/develop/doc/html/boost_asio/reference/use_awaitable.html?ref=kysa.me). Аналогичным образом реализована поддержка короутин у [таймеров](https://github.com/boostorg/asio/blob/boost-1.80.0/include/boost/asio/basic_waitable_timer.hpp?ref=kysa.me#L782) и [сокетов](https://github.com/boostorg/asio/blob/boost-1.80.0/include/boost/asio/basic_stream_socket.hpp?ref=kysa.me#L1106). Тест:

```cpp
#include "schedule.h"

#include <boost/asio/io_context.hpp>
#include <boost/asio/detached.hpp>
#include <boost/asio/experimental/awaitable_operators.hpp>

#include <boost/test/unit_test.hpp>

BOOST_AUTO_TEST_CASE(test_schedule)
{
    bool reachedPointA = false;
    bool reachedPointB = false;

    auto process = [&]() -> boost::asio::awaitable<void> {
            reachedPointA = true;

            boost::asio::any_io_executor executor = co_await boost::asio::this_coro::executor;
            co_await schedule(executor);

            reachedPointB = true;
            co_return;
    };

    auto check = [&]() -> boost::asio::awaitable<void> {
            BOOST_TEST(reachedPointA);
            BOOST_TEST(!reachedPointB);
            co_return;
    };

    auto main = [&]() -> boost::asio::awaitable<void> {
            using namespace boost::asio::experimental::awaitable_operators;
            co_await(process() && check());
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