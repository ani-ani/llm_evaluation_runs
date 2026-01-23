module election_winner (
 input clk,
 input rst_n, // active-low reset
 input start,
 input [7:0] total_delegates,
 input [7:0] state_delegates_0, state_delegates_1, state_delegates_2,
 input [15:0] state_c_0, state_c_1, state_c_2,
 input [15:0] state_f_0, state_f_1, state_f_2,
 input [15:0] state_u_0, state_u_1, state_u_2,
 output reg [31:0] result,
 output reg done,
 output reg impossible
);

// Convert inputs to signed for subtraction
wire signed [15:0] F0 = (signed) state_f_0;
wire signed [15:0] C0 = (signed) state_c_0;
wire [15:0] U0 = state_u_0;
wire signed [15:0] F1 = (signed) state_f_1;
wire signed [15:0] C1 = (signed) state_c_1;
wire [15:0] U1 = state_u_1;
wire signed [15:0] F2 = (signed) state_f_2;
wire signed [15:0] C2 = (signed) state_c_2;
wire [15:0] U2 = state_u_2;

// Compute temp_cost for each state
wire [15:0] temp_cost0 = (F0 - C0 + U0 + 2) / 2;
wire [15:0] temp_cost1 = (F1 - C1 + U1 + 2) / 2;
wire [15:0] temp_cost2 = (F2 - C2 + U2 + 2) / 2;

// Determine cost and winnable
wire [15:0] cost0 = (temp_cost0 <= U0) ? temp_cost0 : 16'd65536;
wire [15:0] cost1 = (temp_cost1 <= U1) ? temp_cost1 : 16'd65536;
wire [15:0] cost2 = (temp_cost2 <= U2) ? temp_cost2 : 16'd65536;
wire winnable0 = (temp_cost0 <= U0);
wire winnable1 = (temp_cost1 <= U1);
wire winnable2 = (temp_cost2 <= U2);

// State delegates
wire [7:0] sd0 = state_delegates_0;
wire [7:0] sd1 = state_delegates_1;
wire [7:0] sd2 = state_delegates_2;

// Compute needed_delegates
wire [15:0] needed_delegates = (total_delegates >> 1) + 1;

// Compute max_possible
wire [7:0] max_possible = (winnable0 ? sd0 : 8'd0) + (winnable1 ? sd1 : 8'd0) + (winnable2 ? sd2 : 8'd0);

// Check impossibility
wire impossible_flag = (max_possible < needed_delegates[7:0]);

// Compute total_cost_selected and total_delegates_selected
reg [15:0] total_cost_selected;
reg [7:0] total_delegates_selected;

always @(*) begin
   if (!impossible_flag) begin
      total_cost_selected = 0;
      total_delegates_selected = 0;
      if (winnable0 && total_delegates_selected < needed_delegates) begin
         total_cost_selected += cost0;
         total_delegates_selected += sd0;
      end
      if (winnable1 && total_delegates_selected < needed_delegates) begin
         total_cost_selected += cost1;
         total_delegates_selected += sd1;
      end
      if (winnable2 && total_delegates_selected < needed_delegates) begin
         total_cost_selected += cost2;
         total_delegates_selected += sd2;
      end
   end else begin
      total_cost_selected = 0;
      total_delegates_selected = 0;
   end
end

// Apply division by 256
wire [31:0] result_val = total_cost_selected >> 8; // divide by 256

// State machine
reg [3:0] state;
reg [15:0] needed_delegates_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= 4'd0; // IDLE
      needed_delegates_reg <= needed_delegates;
      total_cost_selected <= 0;
      total_delegates_selected <= 0;
      done <= 1'b0;
      impossible <= 1'b0;
      result <= 32'd0;
   end else begin
      if (start) begin
         if (state == 4'd0) begin // IDLE
            state <= 4'd1; // PARSE
         end
         if (state == 4'd1) begin // PARSE
            state <= 4'd2; // CALCULATE_COSTS
         end
         if (state == 4'd2) begin // CALCULATE_COSTS
            state <= 4'd3; // SORT
         end
         if (state == 4'd3) begin // SORT
            state <= 4'd4; // SELECT
         end
         if (state == 4'd4) begin // SELECT
            state <= 4'd5; // DONE
         end
      end
      if (state == 4'd5) begin // DONE
         done <= 1'b1;
         impossible <= impossible_flag;
         result <= result_val;
         state <= 4'd5; // Stay in DONE
      end
   end
end

endmodule