# Makefile for F2 MSI-X driver
# This manages building, installing, and removing the kernel module for FPGA control

obj-m += f2_msix_driver.o

# Default target: build the kernel module
all: check_env
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

check_env:
ifndef SDK_DIR
	$(error SDK_DIR is undefined. Try "source sdk_setup.sh" in the root of the repository to set the software environment)
endif

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	rm -rf f2_test

test: f2_test.c
	gcc -I$(SDK_DIR)/userspace/include -L$(SDK_DIR)/userspace/lib -o f2_test f2_test.c -lfpga_mgmt

# Verify SLOT parameter and find corresponding PCIe bus number
check_slot:
ifndef SLOT
	$(error SLOT is undefined. Usage: make install SLOT=<slot_number>)
endif
	$(eval BUS := $(shell lspci | grep -B1 "Device 9248" | grep "00\.0" | sed -n "$(shell echo $$(( $(SLOT) + 1 )))p" | cut -d: -f1))
	@if [ -z "$(BUS)" ]; then \
		echo "Error: Could not find bus number for slot $(SLOT)"; \
		exit 1; \
	fi

# Install the driver for a specific FPGA slot
install: check_slot
	@echo "Installing driver for FPGA Slot ${SLOT} with bus 0x$(BUS)"
	sudo insmod f2_msix_driver.ko bus=0x$(BUS)

remove:
	sudo rmmod f2_msix_driver || true
