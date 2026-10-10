#!/bin/sh

### D2K (Dynamic2Keenetic) — обход DPI. https://github.com/necronicle/d2k
#
# Это обёртка padavan. Сама служба — /usr/share/d2k/d2k-service: апстримовый
# init-скрипт S99d2k с переписанными путями (user/d2k/d2k/padavan-paths.sh).
# Разделение намеренное: апстрим мы правим минимально, по одной строке на путь,
# а всё, что знает про padavan, лежит здесь и обновление апстрима не задевает.
#
# Обёртка делает то, чего апстрим про эту прошивку знать не может:
#   * задаёт раскладку каталогов через окружение;
#   * заводит /etc/storage/d2k и первый config (команда config — её зовёт
#     mtd_storage.sh на каждой загрузке);
#   * сверяется с nvram d2k_enable, прежде чем поднимать службу;
#   * грузит модули Netfilter ДО запуска службы (см. load_modules ниже);
#   * предупреждает про аппаратный ускоритель NAT, который уводит пакеты
#     мимо NFQUEUE;
#   * отвечает понятным отказом на команды, которых в прошивке нет
#     (самообновление, Instagram DNS, PPE-разгрузка Keenetic);
#   * умеет save — перенести /etc/storage в flash.
#
# Панель d2kpanel исполняет ИМЕННО этот файл для кнопок управления: в
# d2k-service ей передаётся --service /usr/bin/d2k.sh. Поэтому обёртка
# самодостаточна и не полагается на унаследованное окружение.

SERVICE="/usr/share/d2k/d2k-service"
RELEASE_DIR="/usr/share/d2k"
DEFCONF="$RELEASE_DIR/config.default"

STORAGE_DIR="/etc/storage/d2k"
CONF="$STORAGE_DIR/config"

# Рабочий каталог — tmpfs. Корень прошивки только для чтения, а писать службе
# надо постоянно: pid-файлы, журналы, live.json, каталог найденных планов.
RUNTIME_DIR="/tmp/d2k"

DPBIN="/usr/sbin/d2kd"
TGBIN="/usr/sbin/d2ktg"
TG_FIREWALL="$RELEASE_DIR/d2k-tg-firewall.sh"

# Раскладка каталогов. Апстрим читает все три как ${...:-значение}, так что
# здесь именно переопределение, а не единственный источник.
export D2K_DIR="$RUNTIME_DIR"
export D2K_RUNTIME_DIR="$RUNTIME_DIR"
export D2K_RELEASE="$RELEASE_DIR"
export D2K_CONFIG="$CONF"
export D2K_MODULES_DIR="/lib/modules"

# Два пути зашиты в C-частях и ключами командной строки не покрываются:
# core/voice.c ищет заготовки пакетов в D2K_FAKE_DIR, telegram/src/config.c
# берёт корневые сертификаты из D2K_TG_CA_BUNDLE.
export D2K_FAKE_DIR="$RELEASE_DIR/files/fake"
export D2K_TG_CA_BUNDLE="$RELEASE_DIR/files/tg-roots.pem"

# Сторож правил и сторож туннеля ищут службу по этим двум переменным. Оба
# должны попасть на обёртку, а не на d2k-service напрямую.
export INIT_SCRIPT="/usr/bin/d2k.sh"
export INIT="/usr/bin/d2k.sh"

# В прошивке только iptables, nft нет вовсе. Без явного указания апстрим
# выбирает движок правил по наличию двоичных файлов, а detect/raw.c читает
# D2K_FW, чтобы понимать, чьи метки он видит.
export FW_BACKEND="iptables"
export D2K_FW="iptables"

PATH="/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

pid=$$

log() {
	echo "$@" >&2
	logger -t "d2k$pid" "$@"
}

error() {
	log "$@"
	exit 1
}

# /etc/storage — tmpfs, который распаковывается из flash при загрузке. Каталога
# d2k в нём может не быть вовсе (первая прошивка, сброс настроек), а веб-страница
# пишет config прямо туда: write_textarea_to_file каталогов не создаёт.
init_storage() {
	[ -f "$STORAGE_DIR" ] && rm -f "$STORAGE_DIR"
	[ -d "$STORAGE_DIR" ] || mkdir -p -m 700 "$STORAGE_DIR" || return 1

	if [ ! -f "$CONF" ]; then
		if [ -f "$DEFCONF" ]; then
			cp -f "$DEFCONF" "$CONF" || return 1
		else
			# Апстрим без config работает на своих значениях по умолчанию,
			# но set_telegram_enabled требует существующий файл.
			: > "$CONF" || return 1
		fi
		log "создан $CONF"
	fi

	# В config лежит TG_RELAY_SECRET. Апстрим, когда правит файл сам, ставит
	# 0600 — держим тот же режим и после записи из веб-интерфейса.
	chmod 700 "$STORAGE_DIR" 2>/dev/null
	chmod 600 "$CONF" 2>/dev/null
	return 0
}

init_runtime() {
	[ -L "$RUNTIME_DIR" ] && rm -f "$RUNTIME_DIR"
	( umask 077; mkdir -p "$RUNTIME_DIR/run" "$RUNTIME_DIR/log" "$RUNTIME_DIR/state" ) || return 1
	chmod 700 "$RUNTIME_DIR" 2>/dev/null
	return 0
}

# Аппаратный ускоритель уводит транзитные пакеты мимо Netfilter, и в NFQUEUE не
# попадает ничего: движок работает, правила стоят, обхода нет. Чужую настройку
# не меняем — она рвёт соединения и влияет на скорость, это решение владельца, —
# но молчать здесь хуже всего: симптом выглядит как «D2K не работает».
check_hwnat() {
	hwnat="$(nvram get hw_nat_mode)"
	[ -z "$hwnat" ] && return 0
	[ "$hwnat" = "2" ] && return 0
	log "ВНИМАНИЕ: hw_nat_mode=$hwnat — аппаратное ускорение NAT включено. Пакеты обходят NFQUEUE, и обход DPI работать не будет. Выключите ускоритель: Дополнительные настройки / WAN / Hardware NAT = Disabled."
	return 1
}

# МОДУЛИ ЯДРА ДО ЗАПУСКА СЛУЖБЫ.
#
# Почти весь нужный Netfilter в этой прошивке собран модулями, а ни одна из
# автоматических загрузок до них не доходит:
#   * tools/depmod.sh удаляет modules.alias, поэтому request_module() ядра —
#     "net-pf-16-proto-12" из netlink_create() и "nfnetlink-subsys-3" из
#     nfnetlink_rcv_msg() — не находит ничего;
#   * busybox modprobe собран без CONFIG_FEATURE_MODUTILS_ALIAS и псевдонимы
#     тоже не разбирает.
# Работает только явный modprobe по настоящему имени модуля. modules.dep
# depmod.sh оставляет, так что зависимости modprobe разрешает сам.
#
# У апстрима свой load_modules(), но в start_engine он стоит ПОСЛЕ запуска
# датапата и после ожидания привязки очереди:
#       spawn_daemon ... d2kd --queue "$QUEUE_NUM" ...
#       пока 5 с: awk ... /proc/net/netfilter/nfnetlink_queue
#       [ -z "$bound" ] && die "очередь $QUEUE_NUM не привязалась"
#       load_modules
#       fw_up
# На Keenetic, под который он писался, очередь к этому моменту уже есть. Здесь
# на холодной загрузке nfnetlink_queue не загружен, самого файла
# /proc/net/netfilter/nfnetlink_queue ещё не существует (его создаёт этот
# модуль), привязка не наступает — и загрузка модулей просто не выполняется.
# Отсюда и наблюдавшееся поведение: d2k поднимался, в панели ошибок не было, а
# трафик мимо; после "modprobe nfnetlink_queue" из zapret (user/zapret/zapret.sh)
# модуль оставался в памяти, и следующий запуск d2k работал.
#
# Перечислены только те, что в NEWIFI-D2 действительно модули. В ядро собраны и
# в список не входят: xt_mark (CONFIG_NETFILTER_XT_MARK=y — и совпадение, и
# цель MARK), xt_connmark (CONFIG_NETFILTER_XT_CONNMARK=y — вместе с целью
# CONNMARK, отдельного xt_CONNMARK.ko в 3.4 нет), xt_multiport, xt_conntrack.
NF_MODULES="nfnetlink nfnetlink_queue xt_NFQUEUE iptable_mangle ip6table_mangle xt_connbytes xt_addrtype xt_comment nf_conntrack_netlink"

# Правила туннеля Telegram: "-m set ... -j REDIRECT" в таблице nat
# (d2k-tg-firewall.sh). Модули ipset грузит сам rc при загрузке
# (user/rc/rc.c, load_ipset_modules), а ipt_REDIRECT — никто:
# CONFIG_IP_NF_TARGET_REDIRECT=m, и без него правило v4 не встаёт.
NF_MODULES_TG="ipt_REDIRECT"

NFQUEUE_PROC="/proc/net/netfilter/nfnetlink_queue"

load_modules() {
	kver="$(uname -r 2>/dev/null)"
	for m in "$@"; do
		# Встроенный в ядро или уже загруженный модуль виден в /sys/module.
		[ -d "/sys/module/$m" ] && continue
		modprobe -q "$m" >/dev/null 2>&1 && continue
		# Запасной путь, если modules.dep не пережил пересборку раздела.
		ko="$(find "/lib/modules/$kver" -name "$m.ko" -type f 2>/dev/null | head -1)"
		[ -n "$ko" ] && insmod "$ko" >/dev/null 2>&1
	done
	return 0
}

# Единственная проверка, которая решает: нет этого файла — датапат не привяжет
# очередь, и запуск встанет на ожидании привязки.
check_nfqueue() {
	[ -e "$NFQUEUE_PROC" ] && return 0
	log "ВНИМАНИЕ: нет $NFQUEUE_PROC — модуль nfnetlink_queue не загрузился. Датапат не сможет привязать очередь NFQUEUE. Проверьте, что в прошивке есть /lib/modules/$(uname -r)/kernel/net/netfilter/nfnetlink_queue.ko"
	return 1
}

unsupported() {
	log "команда '$1' в этой прошивке не поддерживается: $2"
	exit 1
}

usage() {
	cat <<EOF >&2
использование: $0 КОМАНДА

  config                 завести /etc/storage/d2k и первый config
  start | stop | restart  вся служба (движок, панель, туннель)
  status                 состояние
  reapply                поставить правила firewall заново
  heal                   проверка сторожем и починка при необходимости
  engine-start | engine-stop | engine-restart
                         только движок; панель остаётся доступной
  telegram-enable | telegram-disable | telegram-restart | telegram-reapply
                         туннель Telegram
  log-tick               ротация журналов вручную
  save                   сохранить /etc/storage во flash
EOF
	exit 2
}

[ "$(id -u)" != "0" ] && error "запускать только от root"

case "$1" in
config)
	# Зовётся из mtd_storage.sh на каждой загрузке и ничего не запускает:
	# службу поднимает rc, когда дойдёт до своих сервисов.
	init_storage || error "не создать $STORAGE_DIR"
	exit 0
	;;
start)
	if [ "$(nvram get d2k_enable)" != "1" ]; then
		log "D2K выключен в настройках (d2k_enable=0) — не запускаю"
		exit 0
	fi
	[ -x "$DPBIN" ] || error "нет $DPBIN — прошивка собрана без D2K"
	init_storage || error "не создать $STORAGE_DIR"
	init_runtime || error "не создать $RUNTIME_DIR"
	check_hwnat
	load_modules $NF_MODULES
	check_nfqueue
	exec "$SERVICE" start
	;;
restart)
	init_storage || error "не создать $STORAGE_DIR"
	init_runtime || error "не создать $RUNTIME_DIR"
	if [ "$(nvram get d2k_enable)" != "1" ]; then
		# Выключенная служба перезапуску не подлежит: правила надо снять, и
		# на этом всё. Иначе «Применить» на выключённой странице поднимало бы
		# службу обратно.
		log "D2K выключен в настройках (d2k_enable=0) — только останавливаю"
		exec "$SERVICE" stop
	fi
	check_hwnat
	load_modules $NF_MODULES
	check_nfqueue
	exec "$SERVICE" restart
	;;
reapply|heal|engine-start|engine-restart)
	# Эти четыре ставят правила или поднимают движок заново — модули нужны им
	# так же, как start. heal вызывает d2k-fw-heal.sh, который при развале
	# перезапускает движок целиком.
	init_storage || error "не создать $STORAGE_DIR"
	init_runtime || error "не создать $RUNTIME_DIR"
	load_modules $NF_MODULES
	check_nfqueue
	exec "$SERVICE" "$1"
	;;
stop|status|log-tick|engine-stop|ppe-ensure)
	# status идёт наружу без изменений: d2k-fw-heal.sh принимает решение,
	# разбирая именно эти строки ("датапат: работает", "правила: стоят").
	# Модули здесь не грузятся: снятие правил и чтение состояния работают с
	# тем, что уже есть, а гасить модулем то, чего нет, нечего.
	# ppe-ensure у апстрима сам проверяет наличие библиотеки PPE и без неё
	# тихо возвращает успех — пропускаем как есть.
	init_storage || error "не создать $STORAGE_DIR"
	init_runtime || error "не создать $RUNTIME_DIR"
	exec "$SERVICE" "$1"
	;;
telegram-enable|telegram-disable|telegram-restart|telegram-reapply|tg-heal|tg-stop-rules)
	if [ ! -x "$TGBIN" ] || [ ! -x "$TG_FIREWALL" ]; then
		unsupported "$1" "прошивка собрана без туннеля Telegram (CONFIG_FIRMWARE_INCLUDE_D2K_TELEGRAM)"
	fi
	init_storage || error "не создать $STORAGE_DIR"
	init_runtime || error "не создать $RUNTIME_DIR"
	case "$1" in
	telegram-disable|tg-stop-rules) ;;
	*) load_modules $NF_MODULES_TG ;;
	esac
	exec "$SERVICE" "$1"
	;;
save)
	# /etc/storage — tmpfs. Без этого правки config (в том числе сделанные
	# самой службой: telegram-enable переписывает TG_ENABLED) не переживут
	# перезагрузку.
	/sbin/mtd_storage.sh save || error "не сохранить /etc/storage во flash"
	log "настройки сохранены во flash"
	exit 0
	;;
update-check|update-install|update-auto-on|update-auto-off)
	# Самообновление апстрима подменяет файлы в /opt. Здесь службы лежат в
	# squashfs, который только для чтения: обновляться можно лишь вместе с
	# прошивкой. Панель эти кнопки показывает — отвечаем ей внятно.
	unsupported "$1" "службы лежат в образе прошивки; обновление — только пересборкой и перепрошивкой"
	;;
dns-tick|dns-refresh|dns-remove)
	unsupported "$1" "помощник Instagram DNS в сборку не входит (он правит DNS Keenetic через ndmc)"
	;;
ppe-remove|ppe-status)
	unsupported "$1" "разгрузка PPE — особенность Keenetic; в этой прошивке ускорителем управляет hw_nat_mode"
	;;
*)
	usage
	;;
esac
