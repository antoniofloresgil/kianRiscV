
//
// Copyright (c) 2023/2024 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS.
//
// RISC-V SoC Configuration Defines
//
// This file defines constants and addresses for the SoC configuration, 
// including memory mappings, GPIO, UART, SPI, and other peripheral devices.
//

`ifndef KIANV_SOC
`define KIANV_SOC

// SPI Controller Frequencies
`define KIANV_SPI_CTRL0_FREQ 35_000_000  // SD Card SPI frequency
`define KIANV_SPI_CTRL1_FREQ 13_000_000  // Network SPI frequency
`define KIANV_SPI_CTRL2_FREQ 20_000_000  // OLED Display SPI frequency

// Access Fault Enable
`define ENABLE_ACCESS_FAULT 1'b1

// FPGA Multiplier Support
`define FPGA_MULTIPLIER

// Reboot and Halt Signals
`define REBOOT_ADDR 32'h11_100_000
`define REBOOT_DATA 16'h7777
`define HALT_DATA   16'h5555

// CPU Configuration Registers
`define DIV_ADDR               32'h10_000_010
`define CPU_FREQ_REG_ADDR      32'h10_000_014
`define CPU_MEMSIZE_REG_ADDR   32'h10_000_018

// GPIO Registers
`define KIANV_GPIO_DIR         32'h10_000_700
`define KIANV_GPIO_OUTPUT      32'h10_000_704
`define KIANV_GPIO_INPUT       32'h10_000_708

// UART Peripheral Registers
`define UART_TX_ADDR0          32'h10_000_000
`define UART_RX_ADDR0          32'h10_000_000
`define UART_LSR_ADDR0         32'h10_000_005

`define UART_TX_ADDR1          32'h10_000_100
`define UART_RX_ADDR1          32'h10_000_100
`define UART_LSR_ADDR1         32'h10_000_105

`define UART_TX_ADDR2          32'h10_000_200
`define UART_RX_ADDR2          32'h10_000_200
`define UART_LSR_ADDR2         32'h10_000_205

`define UART_TX_ADDR3          32'h10_000_300
`define UART_RX_ADDR3          32'h10_000_300
`define UART_LSR_ADDR3         32'h10_000_305

`define UART_TX_ADDR4          32'h10_000_400
`define UART_RX_ADDR4          32'h10_000_400
`define UART_LSR_ADDR4         32'h10_000_405

// SPI Controller Registers
`define KIANV_SPI_CTRL0        32'h10_500_000  // SD Card
`define KIANV_SPI_DATA0        32'h10_500_004

`define KIANV_SPI_CTRL1        32'h10_500_100  // Network
`define KIANV_SPI_DATA1        32'h10_500_104

`define KIANV_SPI_CTRL2        32'h10_500_200  // OLED Display
`define KIANV_SPI_DATA2        32'h10_500_204

// Sound Register
`define KIANV_SND_REG          32'h10_500_300
`define KIANV_AUDIO_PWM_BUFFER (1 << 16)

// SDRAM Configuration
`define SDRAM_MEM_ADDR_START   32'h80_000_000
`define SDRAM_MEM_ADDR_END     (`SDRAM_MEM_ADDR_START + `SDRAM_SIZE)

// SPI NOR Flash Memory
`define QUAD_SPI_FLASH_MODE    1'b1
`define SPI_NOR_MEM_ADDR_START 32'h20_000_000
`define SPI_MEMORY_OFFSET      (1024 * 1024 * 1)
`define SPI_NOR_MEM_ADDR_END   (`SPI_NOR_MEM_ADDR_START + (16 * 1024 * 1024))

// Bootloader and BRAM Configuration
`define HAS_BRAM
`define RESET_ADDR             0
`define BOOTLOADER_BRAM0       "bootloader/bootloader0.hex"
`define BOOTLOADER_BRAM1       "bootloader/bootloader1.hex"
`define BOOTLOADER_BRAM2       "bootloader/bootloader2.hex"
`define BOOTLOADER_BRAM3       "bootloader/bootloader3.hex"
`define BRAM_WORDS             (1024 * 4)

`endif // KIANV_SOC
