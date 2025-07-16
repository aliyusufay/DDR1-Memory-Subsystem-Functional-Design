`timescale 1ns/1ps

module ddr_memory_subsystem(
	input logic clk,
	input logic rst_n,
	input logic [2:0] icmd,
	input logic [31:0] data_in,
	input logic [31:0] iaddr,
	input logic [3:0] dmsel,
	input logic clk2x,
	output logic busy,
	output logic [31:0] dataout,
	output logic dataout_valid,
	input logic datain_valid
);

  // DDR-side
  logic         clkout, clk2xout, cke, cs_n, ras_n, cas_n, we_n;
  logic [1:0]   ba;
  logic [13:0]  addrout;
  logic         dm, ldm;
  tri  [15:0]  dq;
  tri          dqs;

  // Instance of DUT
  ddr_controller c1 (
    .clk             (clk),
    .rst_n           (rst_n),
    .icmd            (icmd),
    .data_in         (data_in),
    .iaddr           (iaddr),
    .dmsel           (dmsel),
    .clk2x           (clk2x),
    .busy            (busy),
    .dataout         (dataout),
    .dataout_valid   (dataout_valid),
    .datain_valid    (datain_valid),
    .clkout          (clkout),
    .clk2xout        (clk2xout),
    .cke             (cke),
    .cs_n            (cs_n),
    .ras_n           (ras_n),
    .cas_n           (cas_n),
    .we_n            (we_n),
    .ba              (ba),
    .addrout         (addrout),
    .dm              (dm),
    .ldm             (ldm),
    .dq              (dq),
    .dqs             (dqs)
  );

  ddr_sdram_control_logic d1 (
	.clk		(clkout),
	.clk2x		(clk2xout),
	.cke		(cke),
	.cs_n		(cs_n),
	.ras_n		(ras_n),
	.cas_n		(cas_n),
	.we_n		(we_n),
	.addr		(addrout),
	.ba			(ba),
	.dm			(dm),
	.dq			(dq),
	.dqs		(dqs)
);

endmodule
