---
title: STM8 Standard Peripherals Library
author: Dmitriy Vetutnev
date: January 2021
---

Standard Peripherals Library (она же SPL) - это модуль аппаратной абстракции  (HAL) для микроконтроллеров STM8/STM32 за авторством STMicroelectronics. Эта библиотека представляет собой описание регистров, констант и функций для взаимодействия с периферией. Необходимость HAL объясняется просто: бизнес-логика не должна напрямую зависеть от платформы на которой она работает. В этом случаи возможна безболезненная замена платформы. А еще становится доступно модульное тестирование за счет подмены функций HAL на mock-функции.

## Сборка библиотеки

В оригинальной версии эта библиотека не совместима с компилятором **SDCC**. Но сторонними разработчиками разработан публичный [патч](https://github.com/gicking/STM8-SPL_SDCC_patch?ref=kysa.me)

Компилятору необходимо передать дефайн **DEVICE=STM8SXXX**. _STM8SXXX_ - модель микроконтроллера, полный список можно посмотреть в заголовочном файле [stm8s.h](https://github.com/dvetutnev/hello_world_stm8/blob/master/vendor/STM8S_StdPeriph_Lib/Libraries/STM8S_StdPeriph_Driver/inc/stm8s.h?ref=kysa.me)

Часть файлов нужно включать в сборку условно в зависимости от модели микроконтроллера. Пример из [скрипта сборки](https://github.com/dvetutnev/hello_world_stm8/blob/master/vendor/STM8S_StdPeriph_Lib/CMakeLists.txt?ref=kysa.me):

```cmake
set(UART2_PRESENT
    "STM8S105"
    "STM8S005"
    "STM8AF626x"
)
if(${DEVICE} IN_LIST UART2_PRESENT)
    set(SPL_SOURCES ${SPL_SOURCES} ${SPL_SOURCE_DIR}/stm8s_uart2.c)
endif()
mark_as_advanced(UART2_PRESENT)
```

Также потребуется несколько дополнительных файлов. Шаблоны есть в документации к библиотеке.

**stm8s_conf.h**

В этом файле в зависимости от модели микроконтроллера (дефайн _DEVICE_) подключаются заголовочные файлы доступной перферии и определяется макрос _assert_param_, при помощи которого библиотека проверяет входные параметры функций. Проверка параметров мне сейчас не требуется, поэтому я удалил строчку `#define USE_FULL_ASSERT    (1))` для развертывания макроса _assert_param_ в пустое выражение. Этот файл включается в **stm8s.h** (основной загловочный файл SPL).

**stm8s_it.h**

Тут находятся объявления обработчиков прерываний. Включается в **stm8s.h**

**stm8s_it.c**

Определения обработчиков прерываний. Непосредственно для сборки SPL он не нужен, но потребуется при компоновке с ней.

## Hello world with SPL

Тестовый пример будет таким:

```c
#include <stm8s.h>

#define LED_GPIO_PORT  (GPIOB)
#define LED_GPIO_PINS  (GPIO_PIN_ALL)

void delay(uint32_t t) {
    while (t--)
        ;
}

void main(void) {
    GPIO_Init(LED_GPIO_PORT,
              (GPIO_Pin_TypeDef)LED_GPIO_PINS,
              GPIO_MODE_OUT_PP_LOW_FAST);

    for (;;) {
        GPIO_WriteReverse(LED_GPIO_PORT,
                          (GPIO_Pin_TypeDef)LED_GPIO_PINS);
        delay(10000UL);
    }
}
```

Функция _GPIO_Init_ выполняет настройку порта (выход, push-pull). Функция _GPIO_WriteReverse_ изменяет состояние порта для мигания светодиодом. Назначения функций и констант понятны из их имен.

К сборке бинарника (в главном CMakeLists.txt) добавляем добавляем опеределения обработчиков прерывания **(stm8s_it.c)** и линкуем его с SPL:

```cmake
set(DEVICE "STM8S103")
include_directories(${CMAKE_SOURCE_DIR})

add_subdirectory(vendor/STM8S_StdPeriph_Lib)

add_executable(blink
    main.c
    stm8s_it.c
)
target_link_libraries(blink spl)
```

## Таймер и прерывание при его переполнении

Пример для таймера TIM4. Обработчик прерывания таймера в **stm8s_it.c**:

```c
 /*
  *  Current frenq master clock: 16MHz HSI / 8 (default prescaler) = 2MHz
  *  Irq overflow frenq: 2MHz / (256 * 128 (max prescaler)) = ~60Hz
  */
 INTERRUPT_HANDLER(TIM4_UPD_OVF_IRQHandler, 23)
 {
     static uint8_t c = 0;

     c++;
     if (c == 15) {
         GPIO_WriteReverse(LED_GPIO_PORT,
                           (GPIO_Pin_TypeDef)LED_GPIO_PINS);
         c = 0;
     }

     TIM4_ClearITPendingBit(TIM4_IT_UPDATE);
 }
```

Для повторных срабатываний прерывания необходимо очищать флаг вызовом _TIM4_ClearITPendingsBit_.  
Так же внутри реализован импровизированый делитель, чтобы мигание можно было наблюдать без осцилографа.

В функции _main_ настраивается порт, таймер, разрешаются прерывания, включается счет таймера и запускается бесконечный цикл.

```c
int main(void) {
    GPIO_Init(LED_GPIO_PORT,
              (GPIO_Pin_TypeDef)LED_GPIO_PINS,
              GPIO_MODE_OUT_PP_LOW_FAST);

    TIM4_TimeBaseInit(TIM4_PRESCALER_128, TIM4_ARR_RESET_VALUE);
    TIM4_ClearFlag(TIM4_FLAG_UPDATE);
    TIM4_ITConfig(TIM4_IT_UPDATE, ENABLE);

    enableInterrupts();

    TIM4_Cmd(ENABLE);

    for (;;)
        ;
}
```

[Исходники тут.](https://github.com/dvetutnev/hello_world_stm8/tree/tim4_irq?ref=kysa.me)