#!/bin/sh
# padavan-paths.sh — переписывает пути апстрима на те, что есть в прошивке.
#
# Апстрим d2k рассчитан на Entware (Keenetic/OpenWrt): службы лежат в
# /opt/sbin, рабочий каталог — /opt/d2k, init-скрипт — /opt/etc/init.d/S99d2k.
# В padavan ничего из этого нет: корень только для чтения, /opt без USB не
# существует вовсе. Раскладка в прошивке:
#
#   /usr/sbin/d2kd, d2kc, d2kpanel, d2ktg   двоичные службы
#   /usr/share/d2k/                         скрипты, ресурсы панели, данные
#   /usr/share/d2k/d2k-service              этот самый S99d2k после правки
#   /usr/bin/d2k.sh                         обёртка padavan (её зовут панель,
#                                           сторож и сам пользователь)
#   /etc/storage/d2k/config                 настройки (переживают перезагрузку)
#   /tmp/d2k/{run,log,state}                состояние, живёт до перезагрузки
#
# Каждая подстановка проверяется до и после. Несработавшая — отказ сборки:
# служба со скриптами, которые ищут себя в /opt, молча не поднимется, и это
# самый дорогой вид поломки — прошивка собралась, а обхода нет.
set -u

SRC=${1:-}
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    echo "использование: $0 <каталог распакованного d2k>" >&2
    exit 1
fi

STAMP=$SRC/.padavan-paths-done
if [ -f "$STAMP" ]; then
    echo "padavan-paths.sh: дерево уже переписано, пропускаю"
    exit 0
fi

RC=0
fail() { echo "padavan-paths.sh: $*" >&2; RC=1; }

# Построчная замена по точному совпадению: ни sed-экранирования, ни регулярных
# выражений. Значения передаются через окружение, а не -v: awk обрабатывает в
# -v escape-последовательности, и строка с завершающим "\" (перенос в вызове
# панели) поехала бы.
replace_line() {
    f=$SRC/$1
    D2K_OLD=$2
    D2K_NEW=$3
    export D2K_OLD D2K_NEW

    if [ ! -f "$f" ]; then
        fail "нет файла $1"
        return 1
    fi
    n=$(grep -Fxc -e "$D2K_OLD" "$f")
    if [ "$n" != 1 ]; then
        fail "$1: ожидалась ровно одна строка [$D2K_OLD], найдено $n"
        return 1
    fi
    if ! awk 'BEGIN { o = ENVIRON["D2K_OLD"]; n = ENVIRON["D2K_NEW"] }
              $0 == o { print n; next }
              { print }' "$f" > "$f.d2ktmp"; then
        fail "$1: не записать временный файл"
        rm -f "$f.d2ktmp"
        return 1
    fi
    if ! mv -f "$f.d2ktmp" "$f"; then
        fail "$1: не заменить файл"
        rm -f "$f.d2ktmp"
        return 1
    fi
    if ! grep -Fxq -e "$D2K_NEW" "$f"; then
        fail "$1: строка [$D2K_NEW] не появилась"
        return 1
    fi
    if grep -Fxq -e "$D2K_OLD" "$f"; then
        fail "$1: строка [$D2K_OLD] осталась"
        return 1
    fi
    return 0
}

###############################################################################
# files/S99d2k -> /usr/share/d2k/d2k-service
#
# DIR и CONF разведены: у апстрима настройки лежат внутри рабочего каталога
# ($DIR/config), а здесь рабочий каталог — tmpfs (/tmp/d2k), настройки же
# обязаны жить в /etc/storage, иначе они не переживут перезагрузку. RELEASE у
# апстрима равен DIR; через него разрешаются все вспомогательные скрипты и
# ресурсы панели, поэтому он уходит в неизменяемый /usr/share/d2k.
#
# Все три значения ещё и переопределяемы окружением: именно так их задаёт
# /usr/bin/d2k.sh, а правка здесь остаётся работающим значением по умолчанию.
###############################################################################
replace_line files/S99d2k \
    'PATH=/opt/sbin:/opt/bin:/opt/usr/sbin:/opt/usr/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
    'PATH=/usr/sbin:/usr/bin:/sbin:/bin'
replace_line files/S99d2k \
    'DIR=${D2K_DIR:-/opt/d2k}' \
    'DIR=${D2K_DIR:-/tmp/d2k}'
replace_line files/S99d2k \
    'RELEASE=$DIR' \
    'RELEASE=${D2K_RELEASE:-/usr/share/d2k}'
replace_line files/S99d2k \
    'CONF=$DIR/config' \
    'CONF=${D2K_CONFIG:-/etc/storage/d2k/config}'
replace_line files/S99d2k \
    'BIN=/opt/sbin/d2kc' \
    'BIN=/usr/sbin/d2kc'
replace_line files/S99d2k \
    'PANELBIN=/opt/sbin/d2kpanel' \
    'PANELBIN=/usr/sbin/d2kpanel'
replace_line files/S99d2k \
    'DPBIN=/opt/sbin/d2kd' \
    'DPBIN=/usr/sbin/d2kd'
replace_line files/S99d2k \
    'TGBIN=/opt/sbin/d2ktg' \
    'TGBIN=/usr/sbin/d2ktg'
# Панель исполняет этот путь (execl) для кнопок «старт/стоп/перезапуск». Он
# должен указывать на обёртку padavan, а не на сам S99d2k: иначе дочерний
# процесс не получит ни путей, ни проверки nvram.
replace_line files/S99d2k \
    '            --queue "$QUEUE_NUM" --service /opt/etc/init.d/S99d2k \' \
    '            --queue "$QUEUE_NUM" --service /usr/bin/d2k.sh \'

###############################################################################
# files/d2k-log-maintenance.sh — ротация журналов службы.
###############################################################################
replace_line files/d2k-log-maintenance.sh \
    'DIR=${D2K_DIR:-/opt/d2k}' \
    'DIR=${D2K_DIR:-/tmp/d2k}'
replace_line files/d2k-log-maintenance.sh \
    'CONF=$DIR/config' \
    'CONF=${D2K_CONFIG:-/etc/storage/d2k/config}'

###############################################################################
# files/d2k-tg-watchdog.sh — сторож туннеля Telegram. Единственный скрипт
# апстрима, где пути зашиты без ${...:-}.
###############################################################################
replace_line files/d2k-tg-watchdog.sh \
    'PATH=/opt/sbin:/opt/bin:/opt/usr/sbin:/opt/usr/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
    'PATH=/usr/sbin:/usr/bin:/sbin:/bin'
replace_line files/d2k-tg-watchdog.sh \
    'DIR=/opt/d2k' \
    'DIR=${D2K_DIR:-/tmp/d2k}'
replace_line files/d2k-tg-watchdog.sh \
    'INIT=/opt/etc/init.d/S99d2k' \
    'INIT=${INIT:-/usr/bin/d2k.sh}'
# У апстрима рабочий каталог и каталог поставки — один и тот же /opt/d2k,
# поэтому сторож ищет напарника как "$DIR/d2k-tg-firewall.sh". Здесь они
# разведены: DIR стал /tmp/d2k, а скрипты лежат в /usr/share/d2k. Без этой
# правки проверка [ -x ... ] просто не сработала бы, и правила туннеля
# остались бы без присмотра — молча, потому что строка кончается "|| true".
replace_line files/d2k-tg-watchdog.sh \
    '    [ -x "$DIR/d2k-tg-firewall.sh" ] && "$DIR/d2k-tg-firewall.sh" heal >/dev/null 2>&1 || true' \
    '    FW=${D2K_RELEASE:-/usr/share/d2k}/d2k-tg-firewall.sh; [ -x "$FW" ] && "$FW" heal >/dev/null 2>&1 || true'

###############################################################################
# files/d2k-fw-heal.sh — сторож правил. INIT_SCRIPT он и так берёт из
# окружения (его задаёт d2k.sh), но дописывание /opt в PATH здесь всё равно
# убирается: иначе итоговая проверка ниже не смогла бы быть строгой.
###############################################################################
replace_line files/d2k-fw-heal.sh \
    '    *:/opt/sbin:*) ;;' \
    '    *:/usr/sbin:*) ;;'
replace_line files/d2k-fw-heal.sh \
    '    *) PATH="/opt/sbin:/opt/bin:/sbin:/usr/sbin:/bin:/usr/bin${PATH:+:}${PATH}" ;;' \
    '    *) PATH="/sbin:/usr/sbin:/bin:/usr/bin${PATH:+:}${PATH}" ;;'
replace_line files/d2k-fw-heal.sh \
    'INIT_SCRIPT="${INIT_SCRIPT:-/opt/etc/init.d/S99d2k}"' \
    'INIT_SCRIPT="${INIT_SCRIPT:-/usr/bin/d2k.sh}"'

###############################################################################
# Итоговый аудит. В скриптах, которые поедут в прошивку, не должно остаться ни
# одной РАБОЧЕЙ строки с /opt — только упоминания в комментариях (а их там
# много: авторские заметки про Keenetic и NDM).
###############################################################################
for f in S99d2k d2k-fw-heal.sh d2k-log-maintenance.sh d2k-tg-firewall.sh d2k-tg-watchdog.sh; do
    if [ ! -f "$SRC/files/$f" ]; then
        fail "нет files/$f"
        continue
    fi
    left=$(grep -n '/opt' "$SRC/files/$f" | grep -v '^[0-9]*:[[:space:]]*#')
    if [ -n "$left" ]; then
        fail "files/$f: остались рабочие пути /opt:"
        printf '%s\n' "$left" >&2
    fi
done

if [ "$RC" != 0 ]; then
    echo "padavan-paths.sh: правка путей не удалась" >&2
    exit "$RC"
fi

: > "$STAMP"
echo "padavan-paths.sh: пути переписаны под padavan"
exit 0
