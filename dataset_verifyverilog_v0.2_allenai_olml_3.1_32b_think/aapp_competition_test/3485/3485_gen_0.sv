module max_payout_calculator (
 input clk,
 input rst_n,
 input start,
 input [3:0] num_cards,
 input signed [15:0] card_values [0:15],
 output reg [31:0] result,
 output reg done
);

// Internal registers
reg [2:0] state;
reg [3:0] num_cards_reg;
reg [15:0] card_values_reg [0:15];
reg [31:0] result_reg;
reg done_reg;
reg [3:0] index;

// State assignments
localparam IDLE = 3'b000;
localparam CALCULATE_PREFIX = 3'b001;
localparam CALCULATE_SUFFIX = 3'b010;
localparam COMPUTE_RESULT = 3'b011;
localparam DONE = 3'b100;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      num_cards_reg <= 4'd0;
      index <= 4'd0;
      done_reg <= 1'b0;
      result_reg <= 32'd0;
   end else begin
      case (state)
         IDLE: begin
            if (start) state <= CALCULATE_PREFIX;
         end
         CALCULATE_PREFIX: begin
            if (index < num_cards_reg) begin
               index <= index + 1;
            end else begin
               state <= CALCULATE_SUFFIX;
            end
         end
         CALCULATE_SUFFIX: begin
            if (index > 0) begin
               index <= index - 1;
            end else begin
               state <= COMPUTE_RESULT;
            end
         end
         COMPUTE_RESULT: begin
            done_reg <= 1'b1;
            state <= DONE;
         end
         DONE: ;
      endcase
   end
end

// Combinational assignments
assign result = result_reg;
assign done = done_reg;

endmodule