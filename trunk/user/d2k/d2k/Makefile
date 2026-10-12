# https://github.com/necronicle/d2k

SRC_COMMIT = 4f8615f4603fea79a0eef3db774f7756468c7631
SRC_NAME = d2k-$(SRC_COMMIT)
SRC_URL = https://github.com/necronicle/d2k/archive/$(SRC_COMMIT).tar.gz

# Один release id на все четыре службы: d2kc сверяет его со строкой, которую
# d2kd присылает в приветствии управляющего сокета, и при расхождении
# отказывается работать с датапатом (core/d2kc.c).
RELEASE_ID = padavan-$(shell printf '%.7s' $(SRC_COMMIT))

# Апстрим задаёт свои флаги через "CFLAGS ?= ... -Iinclude ...", а padavan
# экспортирует CFLAGS в окружение (.EXPORT_ALL_VARIABLES в user/Makefile),
# поэтому ?= не срабатывает и каталоги -I теряются. Собираем полный набор
# сами - поверх флагов padavan, а не вместо них.
#
# Один объединённый набор -I годится для datapath, core, detect и telegram:
# из каталога каждого из них все четыре пути указывают либо на его
# собственный include, либо на include соседа, либо сами на себя.
D2K_INCS = -Iinclude -I../core/include -I../datapath/include -I../detect/include
# padavan-compat.h добирает то, чего нет в заголовках uClibc-ng (IPV6_HDRINCL).
# Через -include, а не -D: определения в нём закрыты #ifndef, так что когда
# библиотека макрос объявит сама, повторного определения не будет. Путь
# абсолютный — сборка идёт из каталогов $(SRC_NAME)/*, не отсюда.
D2K_CFLAGS = $(CFLAGS) $(D2K_INCS) -D_DEFAULT_SOURCE -include $(CURDIR)/padavan-compat.h
D2K_LDFLAGS = $(LDFLAGS)

# -Werror и -pedantic апстрима рассчитаны на clang+musl из Zig; gcc 7.5 с
# uClibc-ng предупреждает в других местах, поэтому их здесь нет. Диалект
# оставлен авторский (c99 для датапата и ядра, c11 для панели и туннеля), но
# в варианте gnu*: со -std=c99 определяется __STRICT_ANSI__, и features.h
# uClibc-ng прячет часть объявлений POSIX.
all: download_test extract_test
	CFLAGS="$(D2K_CFLAGS) -std=gnu99" LDFLAGS="$(D2K_LDFLAGS)" \
		$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/datapath d2kd RELEASE_ID=$(RELEASE_ID)
	CFLAGS="$(D2K_CFLAGS) -std=gnu99" LDFLAGS="$(D2K_LDFLAGS)" \
		$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/core d2kc RELEASE_ID=$(RELEASE_ID)
	CFLAGS="$(D2K_CFLAGS) -std=gnu11 -D_POSIX_C_SOURCE=200809L" \
		$(MAKE) -C $(SRC_NAME)/panel d2kpanel RELEASE_ID=$(RELEASE_ID)
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K_TELEGRAM),y)
	# Здесь CFLAGS идёт аргументом make, а не через окружение: иначе
	# "CFLAGS += -Werror -pedantic" в telegram/Makefile всё равно добавится.
	# Свой CPPFLAGS апстрима при этом остаётся в силе - padavan переменную
	# CPPFLAGS не определяет. pkg-config без подсказки нашёл бы OpenSSL
	# хозяйской машины, поэтому пути к библиотеке заданы явно.
	$(MAKE) -C $(SRC_NAME)/telegram d2ktg RELEASE_ID=$(RELEASE_ID) \
		CFLAGS="$(D2K_CFLAGS) -std=gnu11" \
		OPENSSL_CFLAGS="-I$(STAGEDIR)/include" \
		OPENSSL_LIBS="-L$(STAGEDIR)/lib -lssl -lcrypto"
endif

download_test:
	( if [ ! -f $(SRC_NAME).tar.gz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.gz $(SRC_URL) || rm -f $(SRC_NAME).tar.gz; \
	fi )

# padavan-paths.sh переписывает пути /opt/... в скриптах апстрима на те, что
# есть в прошивке. Если он не справился, распакованное дерево удаляется: со
# скриптами, которые ищут себя в /opt, служба молча не поднимется.
#
# Зовётся ВСЕГДА, а не только на свежей распаковке. Он идемпотентен сам: после
# успеха кладёт в дерево метку .padavan-paths-done и при следующем вызове
# выходит сразу. А вот обратный порядок — звать его лишь когда дерева не было —
# прощает ровно одну ошибку и делает её тихой: дерево, распакованное руками
# (tar zxf, чтобы собрать патч или посмотреть исходник), остаётся с путями
# /opt навсегда, потому что следующая сборка его уже не тронет. Так и вышло
# после подготовки patches/0001. Цена ошибки — максимальная: BIN, PANELBIN,
# DPBIN и TGBIN зашиты без ${...:-}, окружением из d2k.sh их не переопределить,
# и в прошивку уехал бы S99d2k, который ищет d2kd в /opt/sbin — то есть не
# запускается вообще ничего, при полностью успешной сборке.
#
# Снимок d2k целиком в .gitignore — на каждую сборку (в том числе на CI) он
# качается из интернета заново, поэтому правки в распакованном дереве не
# переживают следующую. Все изменения к апстриму лежат тут, в patches/*.patch,
# и накладываются поверх скачанного дерева — та же конвенция, что у библиотек
# firmware (trunk/libs/*/patches).
#
# Патчи идут ПОСЛЕ padavan-paths.sh, и порядок этот обязателен: скрипт правит
# строки по точному совпадению (grep -Fxc, ровно одно вхождение), поэтому
# патч, который менял бы ту же строку, оставил бы его без работы и свалил бы
# сборку. Поэтому же контекст в patches/*.patch берётся от ПЕРЕПИСАННОГО
# дерева.
#
# Применённый патч пропускается, а не ломает сборку вторым применением:
# patch -R --dry-run отвечает, стоит ли патч уже, и локальное дерево живёт
# между сборками. Путь к патчу АБСОЛЮТНЫЙ: patch уходит в дерево через -d, и
# относительный путь он искал бы уже внутри дерева.
extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_NAME).tar.gz || exit 1; \
	fi )
	( if ! ./padavan-paths.sh $(SRC_NAME) ; then \
		rm -rf $(SRC_NAME); \
		exit 1; \
	fi )
	( for p in "$(CURDIR)"/patches/*.patch; do \
		[ -f "$$p" ] || continue; \
		if patch -d $(SRC_NAME) -R --dry-run -p1 -i "$$p" >/dev/null 2>&1; then \
			echo "d2k: $$(basename $$p) уже применён"; \
		elif patch -d $(SRC_NAME) -p1 -i "$$p"; then \
			echo "d2k: применён $$(basename $$p)"; \
		else \
			echo "d2k: не применить $$p" >&2; \
			exit 1; \
		fi; \
	done )

clean:
	( if [ -d $(SRC_NAME) ]; then \
		for d in datapath core detect panel telegram ; do \
			$(MAKE) -C $(SRC_NAME)/$$d clean ; \
		done ; \
	fi )

romfs:
	$(ROMFSINST) -p +x $(SRC_NAME)/datapath/d2kd /usr/sbin/d2kd
	$(ROMFSINST) -p +x $(SRC_NAME)/core/d2kc /usr/sbin/d2kc
	$(ROMFSINST) -p +x $(SRC_NAME)/panel/d2kpanel /usr/sbin/d2kpanel
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K_TELEGRAM),y)
	$(ROMFSINST) -p +x $(SRC_NAME)/telegram/build/d2ktg /usr/sbin/d2ktg
endif
	$(ROMFSINST) -d -p +x $(SRC_NAME)/files/S99d2k /usr/share/d2k/d2k-service
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-fw-heal.sh /usr/share/d2k/d2k-fw-heal.sh
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-log-maintenance.sh /usr/share/d2k/d2k-log-maintenance.sh
# files/d2k-ppe-deoffload.sh НЕ ставится намеренно. Он целиком про Keenetic:
# ставит "-j PPE" с "-m connskip", а в этой прошивке нет ни цели PPE, ни
# совпадения connskip — ускорителем здесь управляет nvram hw_nat_mode
# (user/rc/net.c, is_hwnat_allow), и выключать его не требуется: правила D2K
# ограничены первыми восьмью пакетами соединения, до которых запись в быстром
# пути ещё не заведена (подробно — в d2k.sh, перед load_modules).
# Без файла S99d2k не подключает его через ".", и все проверки
# "command -v d2k_ppe_*" в нём честно возвращают 0: ppe_up, ppe_down и
# ppe_ensure становятся пустыми операциями, в status строки про PPE не
# печатаются, а "ppe-ensure" из d2k-fw-heal.sh отдаёт успех. Команды
# ppe-remove/ppe-status d2k.sh отклоняет сам, до службы.
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K_TELEGRAM),y)
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-tg-firewall.sh /usr/share/d2k/d2k-tg-firewall.sh
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-tg-watchdog.sh /usr/share/d2k/d2k-tg-watchdog.sh
	$(ROMFSINST) -S -d $(SRC_NAME)/files/tg-roots.pem /usr/share/d2k/files/tg-roots.pem
endif
	$(ROMFSINST) -S -d $(SRC_NAME)/files/meta-ranges.txt /usr/share/d2k/files/meta-ranges.txt
	$(ROMFSINST) -S -d $(SRC_NAME)/files/fake/stun.bin /usr/share/d2k/files/fake/stun.bin
	$(ROMFSINST) -S $(SRC_NAME)/files/fake/quic_initial_dbankcloud_ru.bin /usr/share/d2k/files/fake/quic_initial_dbankcloud_ru.bin
	$(ROMFSINST) -d $(SRC_NAME)/internal/web/assets /usr/share/d2k/panel
