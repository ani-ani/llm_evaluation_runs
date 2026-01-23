module maximal_factoring (input clk, input rst_n, input start, input [7:0] char_in, input valid_in, input [4:0] str_len, output reg [7:0] result, output reg done);

// Internal registers
reg [7:0] string [15:0];
reg [7:0] dp [15:0][15:0];
reg [4:0] captured_str_len;
reg [3:0] load_count;
reg [31:0] cycle_counter;
reg [31:0] start_time;
reg [2:0] state;
reg [7:0] result_temp;
reg [15:0] delay_counter;

// State values
localparam IDLE = 3'd0, LOAD=3'd1, COMPUTE=3'd2, WAIT=3'd3;

// Initialize registers on reset
always_ff @(posedge clk) begin
 if (!rst_n) begin
 string <= 16'b0;
 dp <= {{16{16'b0}}};
 captured_str_len <= 5'b0;
 load_count <= 4'b0;
 cycle_counter <= 32'b0;
 start_time <= 32'b0;
 state <= 3'b0;
 result_temp <= 8'b0;
 delay_counter <= 16'b0;
 result <= 8'b0;
 done <= 1'b0;
 end else begin
 cycle_counter <= cycle_counter + 1;
 if (state == WAIT) begin
 delay_counter <= delay_counter - 1;
 end
 end
end

// Combinational logic
always_comb begin
 if (state == IDLE) begin
 if (start == 1'b1) begin
 captured_str_len <= str_len;
 load_count <= 4'b0;
 start_time <= cycle_counter;
 state <= LOAD;
 end
 end else if (state == LOAD) begin
 if (load_count < 16) begin
 string[load_count] <= valid_in ? char_in : 8'h00;
 load_count <= load_count + 1;
 state <= LOAD;
 end else begin
 state <= COMPUTE;
 end
 end else if (state == COMPUTE) begin
 result_temp <= captured_str_len;
 state <= WAIT;
 delay_counter <= 5000;
 end else if (state == WAIT) begin
 if (delay_counter == 0) begin
 done <= 1'b1;
 result <= result_temp;
 end else begin
 done <= 1'b0;
 result <= 8'h00;
 end
 end
end

// Default assignments
assign state = 3'b0;
assign delay_counter = 16'b0;

endmodule