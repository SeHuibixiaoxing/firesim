/*
 * Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"). You may
 * not use this file except in compliance with the License. A copy of the
 * License is located at
 *
 *     http://aws.amazon.com/apache2.0/
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

/*
 * This Linux kernel module demonstrates PCI device driver implementation for F2
 * 0. Prerequisites: This module must be compiled and loaded on an F2 Instance
 * 1. Module Setup: Initializes PCI device handling and sets up MSI-X interrupts
 * 2. Memory Mapping: Maps DDR BAR (BAR4) for DDR memory access
 * 3. Interrupt Handling: Implements an ISR (Interrupt Service Routine) that:
 *    - Uses spinlocks for thread safety
 *    - Increments a counter in DDR memory
 *    - Logs interrupt events to kernel log
 * 4. Resource Management: Properly allocates and frees PCI resources:
 *    - Enables/disables PCI device
 *    - Manages memory regions
 *    - Handles MSI-X vectors
 * 5. Cleanup: Implements proper cleanup in module exit:
 *    - Frees interrupts
 *    - Releases memory mappings
 *    - Releases PCI resources
 */

#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/slab.h>
#include <linux/stat.h>
#include <linux/uaccess.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_VERSION("1.0.0");
MODULE_INFO(intree, "Y");

/* PCI device configuration */
static int bus = 0;
module_param(bus, int, 0644);
MODULE_PARM_DESC(bus, "FPGA bus number");

/* BAR (Base Address Register) definition */
#define DDR_BAR 4

#define NUM_OF_USER_INTS 16

/* MSI-X interrupt entry table */
struct msix_entry f2_ints[] = {
    {.vector = 0, .entry = 0},  {.vector = 0, .entry = 1},
    {.vector = 0, .entry = 2},  {.vector = 0, .entry = 3},
    {.vector = 0, .entry = 4},  {.vector = 0, .entry = 5},
    {.vector = 0, .entry = 6},  {.vector = 0, .entry = 7},
    {.vector = 0, .entry = 8},  {.vector = 0, .entry = 9},
    {.vector = 0, .entry = 10}, {.vector = 0, .entry = 11},
    {.vector = 0, .entry = 12}, {.vector = 0, .entry = 13},
    {.vector = 0, .entry = 14}, {.vector = 0, .entry = 15}};

struct pci_dev *f2_dev;
int *f2_dev_id[NUM_OF_USER_INTS];

/* Memory-mapped I/O regions */
void __iomem *ddr_base;

static DEFINE_SPINLOCK(f2_isr_lock);

static irqreturn_t f2_isr(int a, void *dev_id) {
  unsigned long flags;

  spin_lock_irqsave(&f2_isr_lock, flags);

  printk(KERN_NOTICE "f2_isr: %d\n", *(int *)dev_id);
  printk(KERN_NOTICE "DDR base value before increment: %u\n",
         *(unsigned int *)ddr_base);
  *(unsigned int *)ddr_base += 1;

  spin_unlock_irqrestore(&f2_isr_lock, flags);

  /* Notify the kernel that the interrupt was handled */
  return IRQ_HANDLED;
}

static int init_pci_device(void) {
  int status;

  f2_dev = pci_get_domain_bus_and_slot(0, bus, PCI_DEVFN(0, 0));
  if (f2_dev == NULL) {
    printk(KERN_ALERT "F2 Driver: Unable to locate PCI card on bus 0x%02x.\n", bus);
    return -1;
  }

  printk(KERN_INFO "Found device - vendor: %x, device: %x at %02x:%02x.%x\n",
         f2_dev->vendor, f2_dev->device, f2_dev->bus->number,
         PCI_SLOT(f2_dev->devfn), PCI_FUNC(f2_dev->devfn));

  status = pci_enable_device(f2_dev);
  if (status) {
    printk(KERN_ERR "Failed to enable PCI device: %d\n", status);
    return status;
  }
  pci_set_master(f2_dev);
  return 0;
}

static int map_pci_bar(void) {
  int status;

  status = pci_request_region(f2_dev, DDR_BAR, "DDR Region");
  if (status < 0) {
    printk(KERN_ALERT "F2 Driver: cannot obtain the DDR region.\n");
    return status;
  }

  ddr_base = (void __iomem *)pci_iomap(f2_dev, DDR_BAR, 0);

  *(unsigned int *)ddr_base = 0x0;

  return 0;
}

static int setup_interrupts(void) {
  int status, i;
  status = pci_enable_msix_exact(f2_dev, f2_ints, NUM_OF_USER_INTS);

  if (status) {
    printk(KERN_ERR "Failed to enable MSI-X: %d\n", status);
    return status;
  }
  printk(KERN_INFO "MSI-X enabled successfully\n");

  /* Initialize user interrupts with interrupt specific data */
  for (i = 0; i < NUM_OF_USER_INTS; i++) {
    f2_dev_id[i] = kmalloc(sizeof(int), GFP_DMA | GFP_USER);
    *f2_dev_id[i] = i;
    status =
        request_irq(f2_ints[i].vector, f2_isr, 0, "F2 Driver", f2_dev_id[i]);
    if (status) {
      printk(KERN_ERR "F2 Driver: Failed to request IRQ %d\n", i);
    }
  }
  return 0;
}

static int __init f2_init(void) {
  int status;

  printk(KERN_NOTICE "Inserting PCI Driver Module\n");
  status = init_pci_device();
  if (status)
    return status;

  status = map_pci_bar();
  if (status)
    return status;

  status = setup_interrupts();
  if (status)
    return status;

  return 0;
}

static void cleanup_resources(void) {
  int i;
  /* Free up interrupt vectors and resources */
  for (i = 0; i < NUM_OF_USER_INTS; i++) {
    free_irq(f2_ints[i].vector, f2_dev_id[i]);
    kfree(f2_dev_id[i]);
  }

  /* Free up MSI-X resources */
  pci_disable_msix(f2_dev);

  if (f2_dev != NULL) {
    pci_iounmap(f2_dev, ddr_base);
    pci_release_region(f2_dev, DDR_BAR);

    pci_disable_device(f2_dev);
    pci_dev_put(f2_dev);
  }
}

static void __exit f2_exit(void) {
  cleanup_resources();
  printk(KERN_NOTICE "Removing PCI Driver Module\n");
}

module_init(f2_init);
module_exit(f2_exit);
