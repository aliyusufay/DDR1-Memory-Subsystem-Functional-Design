module ddr_axi_slave(
// AXI3 Slave Interface (Memory Controller Side)
// Dedicated signals only for DDR Memory
input logic clk2x,					//Half time period of ACLK
// Global signals
input logic ACLK,
input logic ARESETn,
// Write Address Channel
input  logic [31:0] S0_AWADDR,
input  logic        S0_AWVALID,
output logic        S0_AWREADY,
input  logic [3:0]  S0_AWLEN,
input  logic [2:0]  S0_AWSIZE,		//Bytes per beat (e.g., 2 = 4 bytes = 32 bits) not connected since no logic possible as size is fixed 32 bit
input  logic [1:0]  S0_AWBURST,		//not connected since only acceptable values is 001 incremental/sequential burst
// Write Data Channel
input  logic [31:0] S0_WDATA,
input  logic [3:0]  S0_WSTRB,
input  logic        S0_WVALID,
output logic        S0_WREADY,
input  logic        S0_WLAST,
// Write Response Channel
output logic [1:0]  S0_BRESP,
output logic        S0_BVALID,
input  logic        S0_BREADY,
// Read Address Channel
input  logic [31:0] S0_ARADDR,
input  logic        S0_ARVALID,
output logic        S0_ARREADY,
input  logic [3:0]  S0_ARLEN,
input  logic [2:0]  S0_ARSIZE,
input  logic [1:0]  S0_ARBURST,
// Read Data Channel
output logic [31:0] S0_RDATA,
output logic [1:0]  S0_RRESP,
output logic        S0_RVALID,
input  logic        S0_RREADY,
output logic        S0_RLAST
);

logic [2:0] icmd;
logic [31:0] data_in;
logic [31:0] iaddr;
logic [3:0] dmsel;
logic busy;
logic [31:0] dataout;
logic dataout_valid = 0;
logic datain_valid;

ddr_memory_subsystem dms1(
.clk2x(clk2x),
.clk(ACLK),
.rst_n(ARESETn),
.icmd(icmd),
.data_in(data_in),
.iaddr(iaddr),
.dmsel(dmsel),
.busy(busy),
.dataout(dataout),
.dataout_valid(dataout_valid),
.datain_valid(datain_valid)
);

logic [3:0][31:0] read_data;
int i = 0, j = 0;
logic [3:0] burst_len;
logic read_mode, write_mode;
//assign S0_WREADY = datain_valid;
assign dmsel = (write_mode) ? S0_WSTRB : 4'bx;
assign data_in = (datain_valid) ? S0_WDATA : 32'bx;
assign datain_valid = S0_WREADY;

always_ff @(posedge ACLK or negedge ARESETn) begin
	if (!ARESETn) begin
		S0_AWREADY		<=	'b0;
		S0_WREADY		<=	'b0;
		S0_BRESP		<=	2'bx;
		S0_BVALID		<=	'b0;
		S0_ARREADY		<=	'b0;
		S0_RDATA		<=	32'bx;
		S0_RRESP		<=	2'bx;
		S0_RVALID		<=	'b0;
		S0_RLAST		<=	'b0;
		write_mode		<=	0;
		read_mode		<=	0;
		//datain_valid	<=	0;
		i				<=	0;
		j				<=	0;
	end else begin
		if (S0_AWVALID && S0_AWREADY) begin
			icmd <= 1;
			iaddr <= S0_AWADDR;
			burst_len <= S0_AWLEN;
			write_mode <= 1;
		end
		if (S0_ARVALID && S0_ARREADY) begin
			icmd <= 0;
			iaddr <= S0_ARADDR;
			burst_len <= S0_ARLEN;
			read_mode <= 1;
		end
		if (!busy && !write_mode && !read_mode) begin
			if (S0_AWVALID) begin
				S0_AWREADY <= 1;
			end
			else if (S0_ARVALID) begin
				S0_ARREADY <= 1;
			end
		end
		//Write
		if (write_mode) begin
			icmd <= 4;
			iaddr <= 32'bx;
			S0_AWREADY <= 0;
			if (S0_WVALID && S0_WREADY) begin
				S0_WREADY <= 0;
			end else if (S0_WVALID && !S0_WREADY) begin
				S0_WREADY <= 1;
			end
			if (S0_WVALID && S0_WREADY) begin
				if (S0_WLAST) begin
					S0_BVALID <= 1;
					S0_BRESP <= 0;
				end
			end
			if (S0_BVALID && S0_BREADY) begin
				S0_BVALID <= 0;
				S0_BRESP <= 2'bx;
				write_mode <= 0;
			end
		end
		//Write Complete
		//Read
		if (read_mode) begin
			icmd <= 4;
			iaddr <= 32'bx;
			S0_ARREADY <= 0;
			if (i >= 4 && j<4) begin
				if (S0_RREADY && S0_RVALID) begin
					S0_RVALID <= 0;
					S0_RLAST <= 0;
					S0_RRESP <= 2'bx;
					j <= j + 1;
				end else if (read_data [j] !== 32'bx && read_data [j] !== 32'bz && read_data [j] !== 32'b0) begin
					S0_RVALID <= 1;
					S0_RRESP <= 0;
					S0_RDATA <= read_data [j];
					if (j == 3) S0_RLAST <= 1;
				end
			end else if (j >= 4) begin
				i <= 0;
				S0_RDATA <= 32'bx;
				read_mode <= 0;
				j <= 0;
			end
			if (dataout_valid && dataout !== 32'bx && dataout !== 32'bz && read_data [i] !== dataout && i<4) begin
				read_data [i] <= dataout;
				i <= i + 1;
				j <= 0;
			end
		end
	end
end
endmodule
