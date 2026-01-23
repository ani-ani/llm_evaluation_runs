module dice_reroll_optimizer(input clk, input rst_n, input start, input [7:0] K, input [7:0] initial_rolls, output reg [3:0] optimal_k, output reg done);

// Registers
reg [3:0] current_K;
reg [15:0] current_target;
reg [15:0] current_sum;
reg [3:0] best_k;
reg [31:0] best_weight;
reg done_flag;
reg [2:0] state;

// States
localparam int IDLE = 3'd0;
localparam int COMPUTE_SUM = 3'd1;
localparam int COMPUTE_PROB = 3'd2;
localparam int DONE_STATE = 3'd3;

// Parameters
localparam integer [15:0] six_pow [0:8] = {1,6,36,216,1296,7776,46656,279936,1679616};
localparam integer [15:0] factor [0:8] = {1679616,279936,46656,7776,1296,216,36,6,1};

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
current_K <= 8'd0;
current_target <= 16'd0;
current_sum <= 16'd0;
best_k <= 4'd0;
best_weight <= 32'd0;
done_flag <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) state <= COMPUTE_SUM;
end
COMPUTE_SUM: begin
current_K <= K;
current_target <= {16'd0, target};
current_sum <= 16'd0;
state <= COMPUTE_PROB;
end
COMPUTE_PROB: begin
best_k <= 4'd0;
best_weight <= 32'd0;
// k=0 handling
wire [15:0] needed = current_target;
if (needed == 0) begin
reg [31:0] weight = factor[0];
if (weight > best_weight || (weight == best_weight && 0 < best_k)) begin
best_k <= 4'd0;
best_weight <= weight;
end
end
// k=1 handling
if (current_K >= 1) begin
if (needed >= 1 && needed <= 6) begin
reg [31:0] weight = factor[1];
if (weight > best_weight || (weight == best_weight && 1 < best_k)) begin
best_k <= 4'd1;
best_weight <= weight;
end
end
end
// k=2 handling
if (current_K >= 2) begin
if (needed >= 2 && needed <= 12) begin
reg [31:0] weight = factor[2];
if (weight > best_weight || (weight == best_weight && 2 < best_k)) begin
best_k <= 4'd2;
best_weight <= weight;
end
end
end
// Additional k handling would go here...
state <= DONE_STATE;
done_flag <= 1'b1;
end
DONE_STATE: begin
if (start) begin
state <= IDLE;
done_flag <=1'b0;
end
end
endcase
end
end

assign optimal_k = best_k;
assign done = done_flag;
endmodule