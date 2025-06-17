# DDR1 Memory Subsystem – Functional Design (SystemVerilog)

A synthesizable DDR1 SDRAM subsystem comprising:
1. A timing-accurate DDR1 controller that generates DDR command signals.
2. A control-logic block that decodes those signals.
3. A behavioral DDR1 SDRAM model (memory array) that, with the control logic, mimics a DRAM stick.
4. An AXI3-like slave interface for host access.
5. A functional testbench.

## 🎯 Features

- **JEDEC JESD79F-compliant DDR1 controller** (`ddr_controller.sv`):
  - Generates commands: READ, WRITE, PRECHARGE (auto-precharge via A10), SELF-REFRESH, POWER-DOWN, MODE REGISTER SET, AUTO-REFRESH.
  - Enforces key timings: tRCD, tRP, tRAS, tRFC, tWR, tMRD, tCCD, tWTR, tRTP, tRRD, tCKE delays, etc.
  - Bank management: tracks 4 banks, open-row policies, auto-precharge flows.
  - Burst handling: programmable burst length via mode register, with burst counter in datapath.
  - Two-phase clocking: host-side 32-bit interface synchronized to internal DDR-side 16-bit operations with clk and clk2x.
  - **Generates** RAS_n, CAS_n, WE_n, addr, ba, CKE, CS_n signals.

- **DDR Signal Decoder & Interface Logic** (`ddr_sdram_control_logic.sv`):
  - **Decodes** DDR command signals (RAS_n, CAS_n, WE_n, address, bank, etc.) from the controller.
  - Drives/receives DQ/DQS lines, data masks, and manages timing alignment to model pin behavior.
  - Tracks per-bank states internally (IDLE, ACTIVE, READ, WRITE, PRECHARGE) based on the incoming signals.
  - Works together with `memory_array.sv` to emulate the DRAM device’s behavior.

- **DDR1 SDRAM Behavioral Model** (`memory_array.sv`):
  - Parameterized: row/column widths (e.g., ROW_WIDTH=14, COL_WIDTH=10) and number of banks.
  - Implements the internal array and burst read/write logic.
  - Uses decoded signals (e.g., row active, read/write strobes) from control logic to perform actual memory operations.
  - Together with the control-logic block, mimics a real DRAM stick.

- **AXI3-like Slave Interface** (`top_level_ddr_axi_slave.sv`):
  - Simplified AXI write/read channels (AW, W, B, AR, R).
  - Translates AXI bursts (AWADDR, AWLEN, WDATA, etc.) into sequences of host-level commands (`icmd`, `iaddr`, `data_in`, `datain_valid`) for the DDR controller.
  - Collects read data from the controller into AXI read responses.

- **Memory Subsystem Wrapper** (`ddr_memory_subsystem.sv`):
  - Ties the host interface signals to the controller.
  - Instantiates `ddr_controller.sv`, `ddr_sdram_control_logic.sv`, and `memory_array.sv`, wiring DDR-side signals appropriately.
  - Exposes simple host ports (`icmd`, `iaddr[31:0]`, `data_in[31:0]`, `datain_valid`, `busy`, `dataout[31:0]`, `dataout_valid`, plus `clk2x`).

- **Functional Testbench** (`tb/ddr_axi_slave_tb.sv`):
  - Exercises the AXI interface, sequences of reads/writes.
  - Checks data integrity, timing compliance, and controller busy signaling.
  - Includes initialization (mode register set, initial refreshes) before normal traffic.

## 📂 File Structure

| File/Folder | Description |
|-------------|-------------|
| `rtl/ddr_controller.sv` | Generates DDR commands (RAS/CAS/WE, addr, ba, CKE, etc.) | 
| `rtl/ddr_sdram_control_logic.sv` | Decodes DDR commands and drives/receives DQ/DQS to mimic DRAM pins |
| `rtl/memory_array.sv` | Behavioral DDR1 SDRAM model (internal array + burst logic) |
| `rtl/ddr_memory_subsystem.sv` | Wrapper connecting host interface, controller, control logic & SDRAM model |
| `rtl/top_level_ddr_axi_slave.sv` | AXI3-like slave interface to drive the DDR subsystem |
| `tb/ddr_axi_slave_tb.sv` | Functional testbench for AXI-driven read/write sequences |
| `README.md` | This file |

## ⚙️ Interface Details

### DDR Controller (`ddr_controller.sv`)
- **Host-side Ports**:
  - `input logic clk` / `rst_n`: system clock/reset.
  - `input logic [2:0] icmd`: host command code (e.g., `3'b000=READ`, `3'b001=WRITE`, `3'b010=SELF_REFRESH`, etc.).
  - `input logic [31:0] data_in`: write data (32-bit). Valid when `datain_valid` is asserted.
  - `input logic [31:0] iaddr`: host address bus; internally split into bank/row/column per parameters.
  - `input logic [3:0] dmsel`: byte-mask for writes.
  - `input logic clk2x`: doubled-frequency clock for aligning internal 16-bit DDR transfers.
  - `input logic datain_valid`: indicates valid `data_in` for write bursts.
  - `output logic busy`: high while processing a command or sequencing DDR operations.
  - `output logic [31:0] dataout`: read data when `dataout_valid` asserted.
  - `output logic dataout_valid`: indicates `dataout` is valid.

- **DDR-side Command Outputs**:
  - Generates `logic cke`, `cs_n`, `ras_n`, `cas_n`, `we_n`, `addr[ROW_WIDTH+COL_WIDTH-1:0]`, `ba[1:0]`, etc., which feed `ddr_sdram_control_logic.sv`.

- **Command Encoding** (`icmd`):
  - Defined via `typedef enum logic [2:0]` in code, e.g.:
    ```systemverilog
    typedef enum logic [2:0] {
      C_READ         = 3'b000,
      C_WRITE        = 3'b001,
      C_SELF_REFRESH = 3'b010,
      C_PRECHARGE    = 3'b011,
      C_POWER_DOWN   = 3'b100,
      C_MRS          = 3'b101,
      C_AUTO_REFRESH = 3'b110,
      C_NOP          = 3'b111
    } d_cmd_t;
    ```

- **Timings**:
  - All key DDR1 timings are parameters: `tRCD`, `tRP`, `tRAS`, `tRFC`, `tWR`, `tMRD`, `tCCD`, `tWTR`, `tRTP`, `tRRD`, `tCKE`, etc.
  - Controller enforces them before emitting next command.

### DDR Signal Decoder & Interface (`ddr_sdram_control_logic.sv`)
- **Inputs**: `clk`, `clk2x` (for data strobes), plus the signals generated by the controller: `cke`, `cs_n`, `ras_n`, `cas_n`, `we_n`, `addr[...]`, `ba[...]`, `dm`, etc.
- **Responsibilities**:
  - Decodes command signals each cycle to determine bank events (activate, read, write, precharge, refresh).
  - Drives or captures `dq[15:0]` and `dqs` according to the read/write strobes and timing alignment.
  - Tracks per-bank state transitions internally to validate correct sequence (optional assertions can be added here).
  - Feeds the memory model with read/write enables, row/column addresses, burst parameters.

### SDRAM Model (`memory_array.sv`)
- **Parameters**: `ROW_WIDTH`, `COL_WIDTH`, burst length, number of banks.
- **Ports**: receives decoded control signals (e.g., `row_active`, `read_enable`, `write_enable`, column addr, bank addr, DQ in for writes, returns DQ out for reads).
- Implements the internal multi-bank array as `logic [15:0] mem [NUM_BANKS][2**ROW_WIDTH][2**COL_WIDTH]`.
- Handles burst counters, auto-precharge completion, and returns data on appropriate cycles.

### AXI Slave (`top_level_ddr_axi_slave.sv`)
- **AXI Write Address Channel**: `S0_AWADDR[31:0]`, `S0_AWVALID`, `S0_AWREADY`, `S0_AWLEN`, `S0_AWSIZE`, `S0_AWBURST`, ...
- **AXI Write Data Channel**: `S0_WDATA[31:0]`, `S0_WSTRB[3:0]`, `S0_WVALID`, `S0_WREADY`, `S0_WLAST`, ...
- **AXI Write Response Channel**: `S0_BRESP`, `S0_BVALID`, `S0_BREADY`.
- **AXI Read Address Channel**: `S0_ARADDR`, `S0_ARVALID`, `S0_ARREADY`, `S0_ARLEN`, `S0_ARSIZE`, `S0_ARBURST`, ...
- **AXI Read Data Channel**: `S0_RDATA[31:0]`, `S0_RVALID`, `S0_RREADY`, `S0_RLAST`, `S0_RRESP`.
- Converts bursts into multiple host-level commands for the controller, handles data masks, assembles read data beats.

### Memory Subsystem Wrapper (`ddr_memory_subsystem.sv`)
- **Ports**:
  - `input logic clk`, `rst_n`.
  - Host interface: `icmd`, `iaddr[31:0]`, `data_in[31:0]`, `datain_valid`, `dmsel[3:0]`.
  - `input logic clk2x`.
  - Outputs: `busy`, `dataout[31:0]`, `dataout_valid`.
- Instantiates `ddr_controller`, `ddr_sdram_control_logic`, `memory_array`, wiring signals so the controller’s generated DDR commands go into the control logic, which in turn interacts with memory array to produce data back.
