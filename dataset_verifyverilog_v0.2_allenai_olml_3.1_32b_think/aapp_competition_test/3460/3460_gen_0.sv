module worm_cans (
   input clk,
   input rst_n, // active low
   input start,
   input [5:0] n,
   input [63:0] x [0:63],
   input [63:0] r [0:63],
   output reg [63:0] result [0:63],
   output reg done
);

// Internal registers
reg [5:0] n_reg;
reg [63:0] x_reg [0:63];
reg [63:0] r_reg [0:63];
reg [63:0] total_mask;
reg [6:0] i;
reg [2:0] state;
reg done_reg;

// Function to compute popcount (unrolled)
function automatic int popcount;
   input [63:0] value;
   popcount = (value[0]?1:0) + (value[1]?1:0) + (value[2]?1:0) + (value[3]?1:0) + (value[4]?1:0) + (value[5]?1:0) + (value[6]?1:0) + (value[7]?1:0) + (value[8]?1:0) + (value[9]?1:0) + (value[10]?1:0) + (value[11]?1:0) + (value[12]?1:0) + (value[13]?1:0) + (value[14]?1:0) + (value[15]?1:0) + (value[16]?1:0) + (value[17]?1:0) + (value[18]?1:0) + (value[19]?1:0) + (value[20]?1:0) + (value[21]?1:0) + (value[22]?1:0) + (value[23]?1:0) + (value[24]?1:0) + (value[25]?1:0) + (value[26]?1:0) + (value[27]?1:0) + (value[28]?1:0) + (value[29]?1:0) + (value[30]?1:0) + (value[31]?1:0) + (value[32]?1:0) + (value[33]?1:0) + (value[34]?1:0) + (value[35]?1:0) + (value[36]?1:0) + (value[37]?1:0) + (value[38]?1:0) + (value[39]?1:0) + (value[40]?1:0) + (value[41]?1:0) + (value[42]?1:0) + (value[43]?1:0) + (value[44]?1:0) + (value[45]?1:0) + (value[46]?1:0) + (value[47]?1:0) + (value[48]?1:0) + (value[49]?1:0) + (value[50]?1:0) + (value[51]?1:0) + (value[52]?1:0) + (value[53]?1:0) + (value[54]?1:0) + (value[55]?1:0) + (value[56]?1:0) + (value[57]?1:0) + (value[58]?1:0) + (value[59]?1:0) + (value[60]?1:0) + (value[61]?1:0) + (value[62]?1:0) + (value[63]?1:0);
endfunction

// Combinational logic for next_mask_comb
wire [63:0] next_mask_comb;
always @(*) begin
   next_mask_comb = 0;
   for (int k=0; k<64; k++) begin
      if (k >= n_reg) continue;
      if ((total_mask & (1<<k)) !=0) continue;
      for (int j=0; j<64; j++) begin
         if (j >=n_reg) continue;
         if ((total_mask & (1<<j)) ==0) continue;
         if (x_reg[j] >= x_reg[k]) begin
            if (x_reg[j] - x_reg[k] <= r_reg[j]) begin
               next_mask_comb |= (1<<k);
               break;
            end
         end else begin
            if (x_reg[k] - x_reg[j] <= r_reg[j]) begin
               next_mask_comb |= (1<<k);
               break;
            end
         end
      end
   end
end

// State machine
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      n_reg <= 0;
      x_reg <= 0;
      r_reg <= 0;
      total_mask <= 0;
      i <= 0;
      state <= 3'd0;
      done_reg <=0;
   end else begin
      case (state)
         3'd0: // IDLE
            if (start) state <= 3'd1;
         3'd1: // SETUP
            n_reg <= n;
            x_reg <= x;
            r_reg <= r;
            state <= 3'd2;
         3'd2: // PROCESS_CAN
            if (i < n_reg) state <= 3'd3;
            else if (i == n_reg) begin
               state <= 3'd7;
               done_reg <=1;
            end
         3'd3: // PROPAGATE_INIT
            total_mask <= (1 << i);
            state <= 3'd4;
         3'd4: // PROPAGATE_CHECK
            if (next_mask_comb ==0) state <= 3'd5;
            else total_mask <= total_mask | next_mask_comb;
         3'd5: // COUNT
            result[i] <= popcount(total_mask);
            state <= 3'd6;
         3'd6: // NEXT_CAN
            i <= i +1;
            if (i < n_reg) state <= 3'd2;
            else begin
               state <= 3'd7;
               done_reg <=1;
            end
         3'd7: // FINISHED
            state <= 3'd7;
            done_reg <=1;
      endcase
   end
end

// Assign done output
assign done = done_reg;

endmodule