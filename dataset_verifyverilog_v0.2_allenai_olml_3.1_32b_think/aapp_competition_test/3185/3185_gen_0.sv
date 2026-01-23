module factorial_inverse (
   input clk,
   input rst_n, // active-low reset
   input [63:0] target_factorial,
   input start,
   output reg [7:0] result_n,
   output reg valid,
   output reg found
);

// Internal registers
reg [1:0] state;
reg [63:0] target_reg;
reg [7:0] n_reg;
reg [63:0] fact_reg;
reg valid_reg;
reg found_reg;

// State definitions
localparam IDLE = 2'b00;
localparam CALCULATING = 2'b01;
localparam CHECKING = 2'b10;
localparam DONE = 2'b11;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      target_reg <= 64'b0;
      n_reg <= 8'b0;
      fact_reg <= 64'b0;
      valid_reg <= 0;
      found_reg <= 0;
      result_n <= 8'b0;
   end else begin
      if (state == IDLE && start) begin
         state <= CALCULATING;
         target_reg <= target_factorial;
         n_reg <= 1;
         fact_reg <= 64'b1;
      end
      else if (state == CALCULATING) begin
         if (fact_reg == target_reg) begin
            found_reg <= 1;
            result_n <= n_reg;
            state <= CHECKING;
         end else if (n_reg < 20) begin
            n_reg <= n_reg + 1;
            fact_reg <= fact_reg * n_reg;
            state <= CALCULATING;
         end else begin // n_reg == 20 and no match
            found_reg <= 0;
            state <= CHECKING;
         end
      end
      else if (state == CHECKING) begin
         state <= DONE;
         valid_reg <= 1;
      end
      // DONE state: no action, retain values
   end
end

// Output assignments
assign valid = valid_reg;
assign found = found_reg;
endmodule