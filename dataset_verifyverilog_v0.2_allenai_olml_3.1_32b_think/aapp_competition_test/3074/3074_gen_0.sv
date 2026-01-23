module byteconn_solver (
input clk,
input rst_n, // active-low
input start,
input [7:0] digit,
output reg [31:0] result,
output reg done
);

parameter IDLE =2'd0, COMPUTE=2'd1, FINALIZE=2'd2;
reg [7:0] digit_reg;
reg [3:0] digit_num [7:0];
reg [31:0] result;
reg [7:0] mask_counter;
reg [2:0] state;
reg prev_start;

// Combinatorial logic for validity
wire is_valid;
always_comb begin
   is_valid =1'b0;
   integer sum=0, all_zero=1, popcount=0;
   if (mask_counter & 1) begin
      sum += digit_num[0];
      if (digit_num[0] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 2) begin
      sum += digit_num[1];
      if (digit_num[1] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 4) begin
      sum += digit_num[2];
      if (digit_num[2] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 8) begin
      sum += digit_num[3];
      if (digit_num[3] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 16) begin
      sum += digit_num[4];
      if (digit_num[4] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 32) begin
      sum += digit_num[5];
      if (digit_num[5] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 64) begin
      sum += digit_num[6];
      if (digit_num[6] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter & 128) begin
      sum += digit_num[7];
      if (digit_num[7] !=0) all_zero =0;
      popcount++;
   end
   if (mask_counter ==0) begin
      all_zero =0;
   end
   if (sum %3 ==0) begin
      if (all_zero ==0) is_valid =1'b1;
      else if (popcount ==1) is_valid =1'b1;
   end
end

// State machine
always_ff @(posedge clk)
begin
   if (!rst_n) begin
      digit_reg <=8'b0;
      result <=32'b0;
      mask_counter <=8'b0;
      state <= IDLE;
      prev_start <=1'b0;
      digit_num[0] <=4'd0;
      digit_num[1] <=4'd0;
      digit_num[2] <=4'd0;
      digit_num[3] <=4'd0;
      digit_num[4] <=4'd0;
      digit_num[5] <=4'd0;
      digit_num[6] <=4'd0;
      digit_num[7] <=4'd0;
   end else begin
      case (state)
         IDLE: begin
             if (start ==1) begin
                 if (prev_start ==1'b0) begin // rising edge
                     digit_reg <= digit;
                     digit_num[0] <= digit_reg[0] - '0';
                     digit_num[1] <= digit_reg[1] - '0';
                     digit_num[2] <= digit_reg[2] - '0';
                     digit_num[3] <= digit_reg[3] - '0';
                     digit_num[4] <= digit_reg[4] - '0';
                     digit_num[5] <= digit_reg[5] - '0';
                     digit_num[6] <= digit_reg[6] - '0';
                     digit_num[7] <= digit_reg[7] - '0';
                     result <=32'b0;
                     mask_counter <=8'b0;
                     state <= COMPUTE;
                 end
             end
             prev_start <= start;
         end
         COMPUTE: begin
             if (mask_counter <256) begin
                 if (is_valid) begin
                     result <= result +1;
                 end
                 mask_counter <= mask_counter +1;
             end else begin
                 state <= FINALIZE;
             end
         end
         FINALIZE: begin
             done <=1'b1;
         end
      endcase
   end
end
endmodule