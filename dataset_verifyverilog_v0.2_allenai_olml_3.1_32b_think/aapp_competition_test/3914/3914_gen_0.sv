module curfew_enforcement (input clk, input rst_n, input start, input [7:0] d_in, input valid_in, input [31:0] a_in, output reg [15:0] result, output reg done, output reg req_en, output reg [5:0] addr_out);
localparam N = 64;
localparam MAX_D = 32;
localparam B = 16;
localparam IDLE = 2'd0;
localparam LOAD = 1;
localparam COMPUTE = 2;
localparam DONE = 3;
reg [1:0] state;
reg [31:0] total_sum;
reg [15:0] max_complaints;
reg [5:0] data_count;
reg [5:0] i_counter;
reg [7:0] d_val;
reg [5:0] addr_out;
reg [31:0] prefix [0:N-1];
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
total_sum <= 32'd0;
max_complaints <= 16'd0;
data_count <= 6'd0;
i_counter <= 6'd0;
d_val <= 8'd0;
addr_out <= 6'd0;
end else begin
case(state)
IDLE: begin
result <= 16'd0;
done <= 1'b0;
if (start) begin
state <= LOAD;
addr_out <= 6'd0;
data_count <= 6'd0;
total_sum <= 32'd0;
end else begin
state <= IDLE;
end
end
LOAD: begin
result <= 16'd0;
done <= 1'b0;
if (valid_in) begin
if (addr_out == 0) begin
prefix[0] = a_in;
total_sum <= a_in;
end else begin
prefix[addr_out] = prefix[addr_out-1] + a_in;
total_sum <= total_sum + a_in;
end
data_count <= data_count + 1;
addr_out <= addr_out + 1;
if (data_count < N) begin
state <= LOAD;
req_en <= 1'b1;
end else begin
state <= COMPUTE;
d_val <= d_in;
i_counter <= 1;
req_en <= 1'b0;
end
end else begin
state <= LOAD;
req_en <= 1'b1;
end
end
COMPUTE: begin
result <= 16'd0;
done <= 1'b0;
if (i_counter <= N/2) begin
wire [31:0] left_limit_val = i_counter * d_val;
wire [31:0] clamped_left_limit = (left_limit_val > N-1) ? N-1 : left_limit_val;
wire [31:0] right_limit_val = (N-1) - (i_counter * d_val);
wire [31:0] clamped_right_limit = (right_limit_val < 0) ? 0 : right_limit_val;
wire [31:0] left_students = prefix[clamped_left_limit];
wire [31:0] right_students = total_sum - prefix[clamped_right_limit];
wire [31:0] max_fill = (left_students < right_students) ? left_students : right_students;
wire [15:0] complaints = i_counter - (max_fill >> 4);
if (complaints > max_complaints) begin
max_complaints <= complaints;
end
i_counter <= i_counter + 1;
state <= COMPUTE;
req_en <= 1'b0;
end else begin
state <= DONE;
result <= max_complaints;
done <= 1'b1;
req_en <= 1'b0;
end
end
DONE: begin
result <= max_complaints;
done <= 1'b1;
state <= DONE;
req_en <= 1'b0;
end
endcase
end
endmodule