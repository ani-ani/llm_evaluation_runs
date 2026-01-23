module fizz_buzz (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [7:0] n,
   output reg [7:0] result,
   output reg done
);

// State definitions
localparam IDLE = 3'b000,
CHECK_DIVISIBILITY = 3'b001,
COUNT_SEVENS = 3'b010,
INCREMENT = 3'b011,
DONE = 3'b100;

reg [7:0] i;
reg [2:0] state;
reg [7:0] count_7; // Combinational signal for digit count

// Combinational logic to count '7's in i
always @(*) begin
   [7:0] temp = i;
   count_7 = 8'b0;
   if (temp >= 100) begin
      if (temp / 100 == 7) count_7 = count_7 + 1;
      temp = temp % 100;
   end
   if (temp >= 10) begin
      if (temp / 10 == 7) count_7 = count_7 + 1;
      temp = temp % 10;
   end
   if (temp == 7) count_7 = count_7 + 1;
end

// State machine
always @(posedge clk) begin
   if (!rst_n) begin
      i <= 8'b0;
      state <= IDLE;
      result <= 8'b0;
      done <= 1'b0;
   end else begin
      if (state == IDLE) begin
          if (start) begin
              i <= 8'b0;
              state <= CHECK_DIVISIBILITY;
          end
      end

      else if (state == CHECK_DIVISIBILITY) begin
          if (i >= n) begin
              state <= DONE;
              done <= 1'b1;
          end else begin
              if ((i % 11 == 0) || (i % 13 == 0)) begin
                  state <= COUNT_SEVENS;
              end else begin
                  state <= INCREMENT;
              end
          end
      end

      else if (state == COUNT_SEVENS) begin
          result <= result + count_7;
          state <= INCREMENT;
      end

      else if (state == INCREMENT) begin
          i <= i + 1;
          state <= CHECK_DIVISIBILITY;
      end

      else if (state == DONE) begin
          // Remain in DONE state
      end

   end
endmodule