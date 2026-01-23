module unlucky_buyer (
input clk,
input rst_n,
input start,
input [63:0] n,
output reg [63:0] result,
output reg done
);

// Registers
reg [63:0] current_n;
reg [1:0] state;
reg [5:0] counter;

// State definitions
localparam IDLE = 2'b00,
CHECK_REMAINDER = 2'b01,
UPDATE_N = 2'b10,
DONE = 2'b11;

// Default assignments
always @(posedge clk) begin
   if (!rst_n) begin
      current_n <= 64'b0;
      state <= IDLE;
      counter <= 6'b0;
      result <= 64'b0;
      done <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               current_n <= n;
               counter <= 6'b0;
               state <= CHECK_REMAINDER;
            end
            done <= 1'b0;
         end

         CHECK_REMAINDER: begin
            if (counter < 64) begin
               if (current_n % 3 == 0) begin
                  counter <= counter + 1;
                  state <= UPDATE_N;
               end else begin
                  state <= DONE;
               end
            end else begin
               state <= DONE;
            end
            done <= 1'b0;
         end

         UPDATE_N: begin
            current_n <= current_n / 3;
            state <= CHECK_REMAINDER;
            done <= 1'b0;
         end

         DONE: begin
            result <= current_n + 1;
            done <= 1'b1;
         end

      endcase
   end
endmodule