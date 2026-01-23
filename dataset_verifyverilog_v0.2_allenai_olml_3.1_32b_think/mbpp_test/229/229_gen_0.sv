module array_partition (
   input clk,
   input rst_n,
   input start,
   input [2:0] n,
   input signed [7:0] arr [7:0],
   output reg signed [7:0] result [7:0],
   output reg done
); 
reg signed [7:0] internal_reg [7:0]; 
reg [2:0] i, j, state, next_i, next_j; 
reg temp; 
always @(posedge clk or negedge rst_n) begin 
   if (!rst_n) begin 
      state <= 0; 
      i <=0; 
      j <=0; 
      done <=0; 
      internal_reg[0] <=0; 
      internal_reg[1] <=0; 
      internal_reg[2] <=0; 
      internal_reg[3] <=0; 
      internal_reg[4] <=0; 
      internal_reg[5] <=0; 
      internal_reg[6] <=0; 
      internal_reg[7] <=0; 
   end else begin 
      if (state ==0) begin // IDLE 
         if (start) begin 
            state <=1; // move to LOAD 
         end 
      end else if (state ==1) begin // LOAD 
         internal_reg[0] <= arr[0]; 
         if (n >1) internal_reg[1] <= arr[1]; 
         if (n >2) internal_reg[2] <= arr[2]; 
         if (n >3) internal_reg[3] <= arr[3]; 
         if (n >4) internal_reg[4] <= arr[4]; 
         if (n >5) internal_reg[5] <= arr[5]; 
         if (n >6) internal_reg[6] <= arr[6]; 
         if (n >7) internal_reg[7] <= arr[7]; 
         if (n ==0 || n ==1) begin 
            state <=3; 
            done <=1; 
         end else begin 
            state <=2; 
            i <=0; 
            j <= i + 1; 
         end 
      end else if (state ==2) begin // PROCESSING 
         if (i < n && j < n) begin 
            if (internal_reg[i] >=0 && internal_reg[j] <0) begin 
               temp = internal_reg[i]; 
               internal_reg[i] = internal_reg[j]; 
               internal_reg[j] = temp; 
            end 
         end 
         if (i >= n-1) begin 
            state <=3; 
            done <=1; 
         end else begin 
            if (j == n-1) begin 
               next_i = i + 1; 
               if (next_i < n-1) begin 
                  next_j = next_i + 1; 
               end else begin 
                  next_j = n-1; 
               end 
            end else begin 
               next_i = i; 
               next_j = j + 1; 
            end 
            i <= next_i; 
            j <= next_j; 
         end 
      end else if (state ==3) begin // DONE 
         done <=1; 
         if (start) begin 
            state <=1; 
            done <=0; 
         end else begin 
            state <=0; 
            done <=0; 
         end 
      end 
   end 
end 
assign result = internal_reg; 
endmodule