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
D2K_CFLAGS = $(CFLAGS) $(D2K_INCS) -D_DEFAULT_SOURCE -DIPV6_HDRINCL=36
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
extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar zxf $(SRC_NAME).tar.gz || exit 1; \
		if ! ./padavan-paths.sh $(SRC_NAME) ; then \
			rm -rf $(SRC_NAME); \
			exit 1; \
		fi; \
	fi )

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
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K_TELEGRAM),y)
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-tg-firewall.sh /usr/share/d2k/d2k-tg-firewall.sh
	$(ROMFSINST) -p +x $(SRC_NAME)/files/d2k-tg-watchdog.sh /usr/share/d2k/d2k-tg-watchdog.sh
	$(ROMFSINST) -S -d $(SRC_NAME)/files/tg-roots.pem /usr/share/d2k/files/tg-roots.pem
endif
	$(ROMFSINST) -S -d $(SRC_NAME)/files/meta-ranges.txt /usr/share/d2k/files/meta-ranges.txt
	$(ROMFSINST) -S -d $(SRC_NAME)/files/fake/stun.bin /usr/share/d2k/files/fake/stun.bin
	$(ROMFSINST) -S $(SRC_NAME)/files/fake/quic_initial_dbankcloud_ru.bin /usr/share/d2k/files/fake/quic_initial_dbankcloud_ru.bin
	$(ROMFSINST) -d $(SRC_NAME)/internal/web/assets /usr/share/d2k/panel
