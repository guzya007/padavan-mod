all:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K),y)
	$(MAKE) -C d2k all
endif

clean:
	( if [ -d d2k ]; then \
		$(MAKE) -C d2k clean; \
	fi )

# config/config ставится как /usr/share/d2k/config.default, а оттуда d2k.sh
# копирует его в /etc/storage/d2k/config, если настроек там ещё нет. Ключи
# -S -d обязательны: каталог /usr/share/d2k создаёт romfs вложенного Makefile,
# то есть позже, а strip текстовому файлу не нужен.
romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_D2K),y)
	$(ROMFSINST) -p +x /usr/bin/d2k.sh
	$(ROMFSINST) -S -d config/config /usr/share/d2k/config.default
	$(MAKE) -C d2k romfs
endif
