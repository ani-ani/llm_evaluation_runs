module largest_prime_factor (
   input clk,
   input rst_n,
   input start,
   input [15:0] n,
   output reg [15:0] result,
   output reg done
);

reg [1:0] state;      // 0: IDLE, 1: FACTOR
reg [15:0] current;
reg [8:0] divisor;    // 9 bits, range 0..511

wire [17:0] sqr = divisor * divisor;   // 9x9=18 bits

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= 0;
      current <= 0;
      divisor <= 0;
      result <= 0;
      done <= 0;
   end
   else begin
      case (state)
         0: begin
            if (start) begin
               current <= n;
               divisor <= 2;
               result <= 0;
               done <= 0;
               state <= 1;
            end
         end

         1: begin
            if (sqr > {2'b0, current}) begin
               result <= current;
               done <= 1;
               state <= 0;
            end
            else if (current % divisor == 0) begin
               current <= current / divisor;
            end
            else begin
               if (divisor == 2)
                  divisor <= 3;
               else
                  divisor <= divisor + 2;
            end
         end
      endcase
   end
end

endmodule