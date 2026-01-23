module roman_converter (
input clk,
input rst_n,
input start,
input [9:0] number,
output reg [9:0][7:0] roman_chars,
output reg done,
output reg error
);

localparam IDLE = 3'd0,
CHECK_M = 1,
CHECK_CM = 2,
CHECK_D = 3,
CHECK_CD =4,
CHECK_C =5,
CHECK_XC=6,
CHECK_L=7,
CHECK_XL=8,
CHECK_X=9,
CHECK_IX=10,
CHECK_V=11,
CHECK_IV=12,
CHECK_I=13,
APPEND=14,
DONE=15;

reg [3:0] state;
reg [9:0] remaining;
reg [3:0] pos;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      remaining <= 0;
      pos <= 0;
      error <= 0;
      done <= 0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               if (number >= 1 && number <= 1000) begin
                  state <= CHECK_M;
                  remaining <= number;
                  pos <= 0;
                  error <= 0;
               end else begin
                  error <= 1;
                  done <= 1;
                  state <= DONE;
               end
            end
         end

         CHECK_M: begin
            if (remaining >= 1000) begin
               roman_chars[pos] = 8'h6d;
               pos <= pos + 1;
               remaining <= remaining - 1000;
            end
            state <= CHECK_CM;
         end

         CHECK_CM: begin
            if (remaining >= 900) begin
               roman_chars[pos] = 8'h63;
               roman_chars[pos + 1] = 8'h6d;
               pos <= pos + 2;
               remaining <= remaining - 900;
            end
            state <= CHECK_D;
         end

         CHECK_D: begin
            if (remaining >= 500) begin
               roman_chars[pos] = 8'h64;
               pos <= pos + 1;
               remaining <= remaining - 500;
            end
            state <= CHECK_CD;
         end

         CHECK_CD: begin
            if (remaining >= 400) begin
               roman_chars[pos] = 8'h63;
               roman_chars[pos + 1] = 8'h64;
               pos <= pos + 2;
               remaining <= remaining - 400;
            end
            state <= CHECK_C;
         end

         CHECK_C: begin
            if (remaining >= 100) begin
               roman_chars[pos] = 8'h63;
               pos <= pos + 1;
               remaining <= remaining - 100;
            end
            state <= CHECK_XC;
         end

         CHECK_XC: begin
            if (remaining >= 90) begin
               roman_chars[pos] = 8'h78;
               roman_chars[pos + 1] = 8'h63;
               pos <= pos + 2;
               remaining <= remaining - 90;
            end
            state <= CHECK_L;
         end

         CHECK_L: begin
            if (remaining >= 50) begin
               roman_chars[pos] = 8'h6c;
               pos <= pos + 1;
               remaining <= remaining - 50;
            end
            state <= CHECK_XL;
         end

         CHECK_XL: begin
            if (remaining >= 40) begin
               roman_chars[pos] = 8'h78;
               roman_chars[pos + 1] = 8'h6c;
               pos <= pos + 2;
               remaining <= remaining - 40;
            end
            state <= CHECK_X;
         end

         CHECK_X: begin
            if (remaining >= 10) begin
               roman_chars[pos] = 8'h78;
               pos <= pos + 1;
               remaining <= remaining - 10;
            end
            state <= CHECK_IX;
         end

         CHECK_IX: begin
            if (remaining >= 9) begin
               roman_chars[pos] = 8'h69;
               roman_chars[pos + 1] = 8'h78;
               pos <= pos + 2;
               remaining <= remaining - 9;
            end
            state <= CHECK_V;
         end

         CHECK_V: begin
            if (remaining >= 5) begin
               roman_chars[pos] = 8'h76;
               pos <= pos + 1;
               remaining <= remaining - 5;
            end
            state <= CHECK_IV;
         end

         CHECK_IV: begin
            if (remaining >= 4) begin
               roman_chars[pos] = 8'h69;
               roman_chars[pos + 1] = 8'h76;
               pos <= pos + 2;
               remaining <= remaining - 4;
            end
            state <= CHECK_I;
         end

         CHECK_I: begin
            if (remaining >= 1) begin
               roman_chars[pos] = 8'h69;
               pos <= pos + 1;
               remaining <= remaining - 1;
            end
            state <= APPEND;
         end

         APPEND: begin
            state <= DONE;
         end

         DONE: begin
            done <= 1;
            state <= DONE;
         end

         default: state <= IDLE;
      endcase
   end
end
endmodule