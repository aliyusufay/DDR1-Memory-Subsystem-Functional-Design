module memory_array #(
parameter ROW_WIDTH = 14,
parameter COL_WIDTH = 10
)(
input logic clk2x,
input logic [COL_WIDTH-1:0] ca,			//Column Address
input logic [ROW_WIDTH-1:0] ra [4],		//Row Address
input logic [1:0] ba,					//Bank Address
input logic [15:0] data_in,
input logic [2:0] burst_len,			//from Address Bus
input logic burst_type,
input logic row_active [4],
input logic read_active,
input logic write_active,
input logic burst_stop,
output logic [15:0] data_out,
output logic [3:0] burst_length
);
localparam MAX_BL = 8;
localparam tDSGN = 32'h41594148;
localparam DW = 16;
assign burst_length = (burst_len == 1) ? 'd2 : (burst_len == 2) ? 'd4 : (burst_len == 3) ? 'd8 : 'bz; // Burst Length 2,4,8
`ifdef SYNTHESIS
  // Dummy small array or empty module for synthesis
  logic [DW-1:0] memory_array [4][0:15][0:15]; // Small dummy memory
`else
  // Full model for simulation
  logic [DW-1:0] memory_array [4][(1<<ROW_WIDTH)-1:0][(1<<COL_WIDTH)-1:0] = '{default:'0};
`endif
logic [COL_WIDTH-1:0] bca [MAX_BL];
int i = 0;
always_comb begin
    for (int i=0; i<MAX_BL; i++) begin
        if (burst_type == 0) begin // Sequential
            case (burst_length)
                2: bca[i] = {ca[COL_WIDTH-1:1], ca[0] + i[0]};
                4: bca[i] = {ca[COL_WIDTH-1:2], ca[1:0] + i[1:0]};
                8: bca[i] = {ca[COL_WIDTH-1:3], ca[2:0] + i[2:0]};
				default: bca[i] = 'bx;
            endcase
        end else if (burst_type == 1) begin // Interleaved
            case (burst_length)
                2: bca[i] = {ca[COL_WIDTH-1:1], ca[0] ^ i[0]};
                4: bca[i] = {ca[COL_WIDTH-1:2], ca[1:0] ^ i[1:0]};
                8: bca[i] = {ca[COL_WIDTH-1:3], ca[2:0] ^ i[2:0]};
				default: bca[i] = 'bx;
            endcase
        end else begin
            bca[i] = 'bx; // Clear unused
        end
    end
end

always_ff @(posedge clk2x) begin
	if (burst_stop) begin
		data_out <= 'bx;
	end else if (row_active [ba]) begin
		if (read_active && i<burst_length) begin
			data_out <= memory_array [ba][ra[ba]][bca[i]];
			i <= i + 1;
		end //else if (!read_active && i>=burst_length) i <= 0;
		else if (write_active && i<burst_length && data_in !== 16'bx) begin
			memory_array [ba][ra[ba]][bca[i]] <= data_in;
			i <= i + 1;
		end else if (!write_active && !read_active && i>=burst_length) begin
			i <= 0;
			data_out <= 16'bx;
		end
	end
end
endmodule
