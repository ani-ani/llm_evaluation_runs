module largest_subset(input clk, input rst_n, input start, input [2:0] count, input [7:0] data_in, input [2:0] addr, input write_en, output reg [3:0] result, output reg done, output reg valid); 
 reg [7:0] arr [0:7]; 
 reg [3:0] dp [0:7]; 
 reg [2:0] i, j; 
 reg [2:0] state; 
 localparam IDLE = 3'd0; 
 localparam LOAD = 3'd1; 
 localparam OUTER = 3'd2; 
 localparam INNER = 3'd3; 
 localparam COMPARE = 3'd4; 
 localparam FIND_MAX = 3'd5; 
 localparam DONE = 3'd6; 
 
 function automatic bit is_divisible; 
   input [7:0] a, b; 
   if (b == 0) return a == 0; 
   return (a % b) == 0; 
 endfunction 
 
 always @(*) begin 
   result = 4'd0; 
   done = 0; 
   valid = 0; 
   case (state) 
      IDLE: if (start && !rst_n) state = LOAD; 
      LOAD: begin 
         arr <= 8'b0; 
         for (int k=0; k<8; k++) dp[k] = 4'd1; 
         i <= count -1; 
         state = OUTER; 
      end 
      OUTER: begin 
         if (i >=0) begin 
            j <= i +1; 
            state = INNER; 
         end else begin 
            state = FIND_MAX; 
         end 
      end 
      INNER: begin 
         if (j < count) begin 
            state = COMPARE; 
         end else begin 
            i <= i -1; 
            if (i >=0) begin 
               j <= i +1; 
               state = INNER; 
            end else begin 
               state = FIND_MAX; 
            end 
         end 
      end 
      COMPARE: begin 
         if (is_divisible(arr[i], arr[j]) || is_divisible(arr[j], arr[i])) begin 
            if (dp[j] +1 > dp[i]) dp[i] = dp[j] +1; 
         end 
         j <= j +1; 
         if (j < count) state = COMPARE; 
         else begin 
            i <= i -1; 
            if (i >=0) begin 
               j <= i +1; 
               state = INNER; 
            end else state = FIND_MAX; 
         end 
      end 
      FIND_MAX: begin 
         result = 0; 
         for (int k=0; k<count; k++) if (dp[k] > result) result = dp[k]; 
         done = 1; 
         valid = 1; 
         state = DONE; 
      end 
      DONE: state = DONE; 
      default: state = IDLE; 
   endcase 
 end 
 
 always @(posedge clk) begin 
   if (write_en) begin 
      arr[addr] <= data_in; 
   end 
 end 
 
 always @(posedge clk) begin 
   if (state == FIND_MAX || state == DONE) begin 
      result_reg <= result; 
      done_reg <= done; 
      valid_reg <= valid; 
   end 
 end 
 
 reg [3:0] result_reg, done_reg, valid_reg; 
 assign result = result_reg; 
 assign done = done_reg; 
 assign valid = valid_reg; 
 endmodule