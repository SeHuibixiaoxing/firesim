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
 * This example demonstrates FPGA interrupt handling using MSI-X
 * 0. Prerequisites: Must be run on an F2 Instance with proper PCI
 * device access. The FPGA must be loaded with the CL_DRAM_HBM_DMA AFI
 * 1. PCI Setup: Attaches to DDR BAR (BAR4) for memory access
 * 2. Interrupt Configuration:
 *    - Configures MSI-X vector assignments for 16 user interrupts
 *    - Sets up interrupt enable masks
 *    - Maps different interrupts to different MSI-X vectors
 * 3. Testing:
 *    - Triggers each interrupt sequentially
 *    - Monitors DDR memory for interrupt handler updates
 * 4. Cleanup:
 *    - Verifies interrupt completion
 *    - Clears interrupt status bits
 *    - Detaches from PCI resources
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fcntl.h>
#include <unistd.h>

#include <fpga_mgmt.h>
#include <fpga_pci.h>
#include <utils/lcd.h>

/* IRQ Block ID */
#define IRQ_TGT 0x2 
#define NUM_OF_USER_INTS 16

/* Register Offset Calculation */
uint32_t dma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset) {
  return ((target << 12) | (channel << 8) | offset);
}

int interrupt_example(int slot_id, int interrupt_number) {
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
  pci_bar_handle_t dma_bar_handle = PCI_BAR_HANDLE_INIT;
  pci_bar_handle_t ddr_bar_handle = PCI_BAR_HANDLE_INIT;

  uint32_t read_data;
  uint32_t last_read_data;
  int rc = 0;
  int pf_id = 0;
  int bar_id = 0;
  int fpga_attach_flags = 0;
  uint32_t interrupt_reg_offset = 0xd00;
  int i;

  printf("Starting MSI-X Interrupt test \n");

  /* Attach to PCI BARs */
  rc = fpga_pci_attach(slot_id, pf_id, bar_id, fpga_attach_flags,
                       &pci_bar_handle);
  fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

  rc = fpga_pci_attach(slot_id, pf_id, 2, fpga_attach_flags, &dma_bar_handle);
  fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

  rc = fpga_pci_attach(slot_id, pf_id, 4, fpga_attach_flags, &ddr_bar_handle);
  fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

  /* Read Initial Values */
  rc = fpga_pci_peek(ddr_bar_handle, 0, &last_read_data);
  printf("Initial DDR value: %0x\n", last_read_data);

  rc = fpga_pci_peek(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x000),
                     &read_data);
  printf("IRQ Block Identifier read_data: %0x\n", read_data);

  rc = fpga_pci_peek(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x004),
                     &read_data);
  printf("IRQ Block User Interrupt Enable Mask read_data: %0x, Addr: %0x\n",
         read_data, dma_reg_addr(IRQ_TGT, 0, 0x004));

  /* Pick different vector for each interrupt */
  rc = fpga_pci_peek(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x080),
                     &read_data);
  printf("IRQ Block User Vector Number read_data: %0x, Addr: %0x\n", read_data,
         dma_reg_addr(IRQ_TGT, 0, 0x080));

  /* Configure interrupt vectors */
  rc = fpga_pci_poke(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x080),
                     0x03020100);
  rc |= fpga_pci_poke(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x084),
                      0x07060504);
  rc |= fpga_pci_poke(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x088),
                      0x0b0a0908);
  rc |= fpga_pci_poke(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x08c),
                      0x0f0e0d0c);
  fail_on(rc, out, "Unable to write to the fpga !");

  /* Enable Interrupt Mask */
  rc = fpga_pci_poke(dma_bar_handle, dma_reg_addr(IRQ_TGT, 0, 0x004), 0xffff);

  uint32_t initial_ddr_value;
  uint32_t current_ddr_value;

  printf("\nTriggering single interrupt (interrupt 0)...\n");

  /* Read initial DDR value */
  rc = fpga_pci_peek(ddr_bar_handle, 0, &initial_ddr_value);
  printf("Initial DDR value: %0x\n", initial_ddr_value);

  /* Trigger single interrupt */
  rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, 1); 
  fail_on(rc, out, "Unable to trigger interrupt!");

  /* Poll until value changes */
  do {
      rc = fpga_pci_peek(ddr_bar_handle, 0, &current_ddr_value);
  } while (current_ddr_value == initial_ddr_value);
  
  printf("Current DDR value: %0x\n", current_ddr_value);

  /* Now proceed with triggering all interrupts as before */
  printf("\nTriggering each of the MSI-X interrupts...\n");
  for (i = 0; i < NUM_OF_USER_INTS; i++) {
      rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, 1 << i);
      printf("Triggering interrupt %d (bit %d)\n", i, i);
      fail_on(rc, out, "Unable to write to the fpga !");
      usleep(1000); // 1ms delay between interrupts
  }

  rc = fpga_pci_peek(pci_bar_handle, interrupt_reg_offset, &read_data);
  printf("CL interrupt status read_data: %08x\n", read_data);

  fail_on(rc, out, "Unable to read from the fpga !");

  /* Clear acknowledge bits */ 
  rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, read_data);
  fail_on(rc, out, "Unable to write to the fpga !");

  /* Make sure bits were cleared */ 
  rc = fpga_pci_peek(pci_bar_handle, interrupt_reg_offset, &read_data);
  printf("CL read_data: %08x\n", read_data);

  fail_on(rc, out, "Unable to read from the fpga !");

out:
  return rc;
}

int main(int argc, char **argv) {
  int rc;
  int slot_id;
  int interrupt_number;

  if (argc != 2) {
    printf("Usage: %s <slot_id>\n", argv[0]);
    return -1;
  }
  slot_id = atoi(argv[1]);
  interrupt_number = 0;

  rc = interrupt_example(slot_id, interrupt_number);
  fail_on(rc, out, "Interrupt example failed");

out:
  return rc;
}
