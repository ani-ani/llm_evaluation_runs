module equivalent_divisors (
   input clk,
   input rst_n,
   input start,
   input [7:0] num1,
   input [7:0] num2,
   output reg result,
   output reg done
);

reg [2:0] state;
reg [9:0] sum1, sum2;
reg [3:0] i1, i2;
reg [7:0] num1_reg, num2_reg;
parameter IDLE = 0, CALC1 =1, CALC2=2, COMPARE=3, DONE=4;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      sum1 <=0;
      sum2 <=0;
      i1 <=0;
      i2 <=0;
      num1_reg <=0;
      num2_reg <=0;
      result <=0;
      done <=0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               num1_reg <= num1;
               num2_reg <= num2;
               state <= CALC1;
            end
         end

         CALC1: begin
            if (i1 ==0) begin
               if (num1_reg ==1) sum1 <=0;
               else if (num1_reg ==0) sum1 <=0;
               else sum1 <=1;
               i1 <=2;
            end else begin
               if (i1 * i1 > num1_reg) begin
                  state <= CALC2;
               end else begin
                  if (num1_reg % i1 ==0) begin
                     if (i1 != num1_reg / i1) begin
                        sum1 <= sum1 + i1 + (num1_reg / i1);
                     end else begin
                        sum1 <= sum1 + i1;
                     end
                  end
                  i1 <= i1 +1;
                  state <= CALC1;
               end
            end

         end

         CALC2: begin
            if (i2 ==0) begin
               if (num2_reg ==1) sum2 <=0;
               else if (num2_reg ==0) sum2 <=0;
               else sum2 <=1;
               i2 <=2;
            end else begin
               if (i2 * i2 > num2_reg) begin
                  state <= COMPARE;
               end else begin
                  if (num2_reg % i2 ==0) begin
                     if (i2 != num2_reg / i2) begin
                        sum2 <= sum2 + i2 + (num2_reg / i2);
                     end else begin
                        sum2 <= sum2 + i2;
                     end
                  end
                  i2 <= i2 +1;
                  state <= CALC2;
               end
            end

         end

         COMPARE: begin
            result <= (sum1 == sum2);
            state <= DONE;
         end

         DONE: begin
            done <=1;
         end

      endcase
   end
endmodule