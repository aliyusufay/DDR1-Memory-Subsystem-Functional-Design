`timescale 1ns/1ps

module tb_ddr_axi_slave;
// Clock & reset
logic ACLK;
logic clk2x;
logic ARESETn;
// Write Address Channel
logic [31:0] S0_AWADDR;
logic        S0_AWVALID;
logic        S0_AWREADY;
logic [3:0]  S0_AWLEN;
// Write Data Channel
logic [31:0] S0_WDATA;
logic [3:0]  S0_WSTRB;
logic        S0_WVALID;
logic        S0_WREADY;
logic        S0_WLAST;
// Write Response Channel
logic [1:0]  S0_BRESP;
logic        S0_BVALID;
logic        S0_BREADY;
// Read Address Channel
logic [31:0] S0_ARADDR;
logic        S0_ARVALID;
logic        S0_ARREADY;
logic [3:0]  S0_ARLEN;
// Read Data Channel
logic [31:0] S0_RDATA;
logic [1:0]  S0_RRESP;
logic        S0_RVALID;
logic        S0_RREADY;
logic        S0_RLAST;

  // Instance of DUT
ddr_axi_slave das1 (
.ACLK(ACLK),
.clk2x(clk2x),
.ARESETn(ARESETn),
.S0_AWADDR(S0_AWADDR),
.S0_AWVALID(S0_AWVALID),
.S0_AWREADY(S0_AWREADY),
.S0_AWLEN(S0_AWLEN),
.S0_WDATA(S0_WDATA),
.S0_WSTRB(S0_WSTRB),
.S0_WVALID(S0_WVALID),
.S0_WREADY(S0_WREADY),
.S0_WLAST(S0_WLAST),
.S0_BRESP(S0_BRESP),
.S0_BVALID(S0_BVALID),
.S0_BREADY(S0_BREADY),
.S0_ARADDR(S0_ARADDR),
.S0_ARVALID(S0_ARVALID),
.S0_ARREADY(S0_ARREADY),
.S0_ARLEN(S0_ARLEN),
.S0_RDATA(S0_RDATA),
.S0_RRESP(S0_RRESP),
.S0_RVALID(S0_RVALID),
.S0_RREADY(S0_RREADY),
.S0_RLAST(S0_RLAST)
);
  // Clock generation
  initial begin
    ACLK <= 0;
    forever #5 ACLK <= ~ACLK; // 100 MHz
  end
  initial begin
    clk2x <= 0;
    forever #2.5 clk2x <= ~clk2x; // 200 MHz
  end

  // Reset sequence
  initial begin
    ARESETn <= 0;
    repeat (10) @(posedge ACLK);
    ARESETn <= 1;
  end

  // Fixed-4-beat write task
  task automatic write4 (
    input logic [31:0] addr,
    input logic [31:0] data0,
    input logic [31:0] data1,
    input logic [31:0] data2,
    input logic [31:0] data3
  );
    int i;
    logic [31:0] wdata_arr [0:3];
    begin
      wdata_arr[0] = data0;
      wdata_arr[1] = data1;
      wdata_arr[2] = data2;
      wdata_arr[3] = data3;

      // Address phase
      S0_AWADDR  <= addr;
      S0_AWLEN   <= 4-1;      // fixed 4 beats → AWLEN = 3
      S0_AWVALID <= 1;
      @(posedge ACLK);
      while (!S0_AWREADY) @(posedge ACLK);
      S0_AWVALID <= 0;

      // Data phase: 4 beats
      for (i = 0; i < 4; i++) begin
        S0_WDATA  <= wdata_arr[i];
        S0_WSTRB  <= 4'b1111;  // all bytes valid
        S0_WLAST  <= (i == 3);
        S0_WVALID <= 1;
        @(posedge ACLK);
        while (!S0_WREADY) @(posedge ACLK);
        S0_WVALID <= 0;
      end

      // Response phase
      @(posedge ACLK);
      while (!S0_BVALID) @(posedge ACLK);
      S0_BREADY <= 1;
	  S0_WLAST  <= 0;
      @(posedge ACLK);
      if (S0_BRESP != 2'b00) $display("ERROR: Write BRESP=%0b", S0_BRESP);
      S0_BREADY <= 0;
    end
  endtask

  // Fixed-4-beat read task
  task automatic read4 (
    input  logic [31:0] addr,
    output logic [31:0] data0,
    output logic [31:0] data1,
    output logic [31:0] data2,
    output logic [31:0] data3
  );
    int beat_cnt;
    begin
      // Address phase
      S0_ARADDR  <= addr;
      S0_ARLEN   <= 4-1;      // fixed 4 beats → ARLEN = 3
      S0_ARVALID <= 1;
      @(posedge ACLK);
      while (!S0_ARREADY) @(posedge ACLK);
      S0_ARVALID <= 0;

      // Data phase
      S0_RREADY <= 1;
      beat_cnt = 0;
      while (beat_cnt < 4) begin
        @(posedge ACLK);
        if (S0_RVALID) begin
          case (beat_cnt)
            0: data0 = S0_RDATA;
            1: data1 = S0_RDATA;
            2: data2 = S0_RDATA;
            3: data3 = S0_RDATA;
          endcase
          if (S0_RRESP != 2'b00)
            $display("ERROR: Read beat %0d RRESP=%0b", beat_cnt, S0_RRESP);
          beat_cnt++;
        end
      end
      S0_RREADY <= 0;
    end
  endtask
    logic [31:0] r0, r1, r2, r3;
  // Test sequence
  initial begin
    // Initialize AXI inputs
    S0_AWADDR  <= 0;
    S0_AWVALID <= 0;
    S0_AWLEN   <= 0;

    S0_WDATA   <= 0;
    S0_WSTRB   <= 0;
    S0_WVALID  <= 0;
    S0_WLAST   <= 0;

    S0_BREADY  <= 0;

    S0_ARADDR  <= 0;
    S0_ARVALID <= 0;
    S0_ARLEN   <= 0;

    S0_RREADY  <= 0;
	
	// Optional monitoring of handshake signals
	/*$display("AWV  AWR  WV  WR  BV  ARV  ARR  RV  RR");
    $monitor(" %b    %b   %b  %b  %b   %b   %b  %b  %b", S0_AWVALID, S0_AWREADY, S0_WVALID,
	S0_WREADY, S0_BVALID, S0_ARVALID, S0_ARREADY, S0_RVALID, S0_RREADY);*/
	
    // Wait for reset release
    @(posedge ACLK);
    wait (ARESETn);

    // Small delay
    repeat (5) @(posedge ACLK);

    // Example: write 4 beats to address 0x1000
    $display("Time %0t   === Write 4 beats to 0x0000 ===",$time);
    write4(32'h0000_0000, 32'hDEAD_BEEF, 32'hC0DE_CAFE, 32'h1234_5678, 32'h8765_4321);
    $display("Write DEADBEEF, C0DECAFE, 12345678, 87654321 done.");

    // Delay
    repeat (2) @(posedge ACLK);
	$display("Time %0t   === Write 4 beats to 0x1000 ===",$time);
	 write4(32'h0000_1000, 32'hFADE_DEAF, 32'hFEED_DEED, 32'hDEC0_DED1, 32'h4159_4148);
    $display("Write FADEDEAF, FEEDDEED, DEC0DED1, 41594148 done.");

    // Delay
    repeat (2) @(posedge ACLK);

    // Example: read 4 beats from address 0x1000

    $display("Time %0t   === Read 4 beats from 0x0000 ===",$time);
    read4(32'h0000_0000, r0, r1, r2, r3);
    $display("Read data: %0h, %0h, %0h, %0h", r0, r1, r2, r3);
	// Delay
	repeat (2) @(posedge ACLK);
	$display("Time %0t   === Read 4 beats from 0x1000 ===",$time);
    read4(32'h0000_1000, r0, r1, r2, r3);
    $display("Read data: %0h, %0h, %0h, %0h", r0, r1, r2, r3);

    // End simulation
    #1000;
    $finish;
  end
endmodule
