/* padavan-compat.h — то, чего нет в uClibc-ng этой прошивки.
 *
 * Подключается всем единицам трансляции d2k через "-include" (см. D2K_CFLAGS
 * в Makefile рядом), а не правкой исходников апстрима: обновление апстрима
 * тогда ничего здесь не задевает.
 *
 * Каждое определение закрыто #ifndef. Голый -DIPV6_HDRINCL=36 в CFLAGS этого
 * не даёт: когда библиотека макрос всё-таки объявит, получится «macro
 * redefined» в каждом файле, который включает <linux/in6.h> или <netinet/in.h>.
 */

#ifndef D2K_PADAVAN_COMPAT_H
#define D2K_PADAVAN_COMPAT_H

/* IPV6_HDRINCL — ядро 3.4 его знает (NEWIFI-D2 собирается с ним), а заголовки
 * uClibc-ng 1.0.58 не объявляют: в netinet/in.h есть только IP_HDRINCL для
 * IPv4. Апстрим зовёт setsockopt(IPPROTO_IPV6, IPV6_HDRINCL) безусловно —
 * datapath/raw.c (сырой сокет IPv6 датапата) и detect/raw.c (зонд
 * детектора), — поэтому без этого макроса сборка падает на обоих файлах.
 * Запасной "#define IPV6_HDRINCL (-1)" в detect/raw.c не помогает: он закрыт
 * условием defined(D2K_RAW_UNIT_TEST) и в прошивку не попадает.
 *
 * Значение — то же, что в uapi/linux/in6.h ядра: IPV6_HDRINCL 36. Это номер
 * параметра сокета в ABI ядра, он зафиксирован и меняться не может.
 */
#ifndef IPV6_HDRINCL
#define IPV6_HDRINCL 36
#endif

#endif /* D2K_PADAVAN_COMPAT_H */
