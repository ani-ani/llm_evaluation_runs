module min_perm_deviation(input clk, input rst_n, input start, input [2:0] n, input [63:0] p_in, output reg [15:0] min_dev, output reg [2:0] best_shift, output reg done);

// Local parameters
localparam N = 8;

// Registers
reg [15:0] current_dev, min_dev;
reg [2:0] best_shift, current_shift;
reg [2:0] shift_count;
reg [3:0] i_count;
reg [2:0] state;
reg done_flag;

// State definitions
parameter IDLE = 3'd0, INIT = 3'd1, ITERATE = 3'd2, DONE = 3'd3;

// Default assignments
always @(*)
begin
min_dev <= 16'd0;
best_shift <= 3'd0;
shift_count <= 3'd0;
i_count <= 4'd0;
state <= IDLE;
done_flag <= 1'b0;
end

// Main state machine
always @(posedge clk or negedge rst_n)
if (!rst_n) begin
state <= IDLE;
current_dev <= 16'd0;
min_dev <= 16'd0;
best_shift <= 3'd0;
shift_count <= 3'd0;
i_count <= 4'd0;
done_flag <= 1'b0;
end else begin
case (state)
IDLE:
if (start) state <= INIT;
INIT:
if (i_count < N) begin
wire [7:0] p_i = p_in >> (i_count * 8) & 8'hFF;
current_dev += abs(p_i - (i_count + 1));
i_count <= i_count + 1;
end else begin
state <= ITERATE;
i_count <= 4'd0;
min_dev <= current_dev;
best_shift <= 3'd0;
end
ITERATE:
if (shift_count < N-1) begin
shift_count <= shift_count + 1;
// Placeholder for incremental deviation calculation
// current_dev = current_dev + (p_val - N) - (count_greater - count_less);
if (shift_count == N-1) state <= DONE;
end else begin
state <= DONE;
end
DONE:
done_flag <= 1'b1;
endcase
end

// Assign done output
assign done = done_flag;

endmodule