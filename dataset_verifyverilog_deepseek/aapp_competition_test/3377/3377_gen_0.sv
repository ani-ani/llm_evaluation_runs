module peg_sequence_checker (
  input clk,
  input rst_n,
  input start,
  input op,
  input [3:0] point_id,
  output reg valid,
  output reg done
);

parameter [15:0] DEPENDENCY [0:15] = '{16'h0000, 16'h0000, 16'h0000, 16'h0000, 
                                    16'h0000, 16'h0000, 16'h0000, 16'h0000,
                                    16'h0000, 16'h0000, 16'h0000, 16'h0000,
                                    16'h0000, 16'h0000, 16'h0000, 16'h0000};
                              
reg [15:0] peg_mask;
reg [15:0] support_mask[0:15];
reg valid_reg;
reg done_reg;
reg prev_start;
reg set_done_next;

wire start_rising = start && !prev_start;
wire [15:0] bit_mask = 16'h1 << point_id;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      peg_mask <= 16'h0;
      foreach (support_mask[i]) begin
         support_mask[i] <= 16'h0;
      end
      valid_reg <= 1'b0;
      done_reg <= 1'b0;
      prev_start <= 1'b0;
      set_done_next <= 1'b0;
   end else begin
      prev_start <= start;
      set_done_next <= 1'b0;

      if (start_rising && !done_reg) begin
         valid_reg <= 1'b1;
         done_reg <= 1'b0;
      end

      if (start && valid_reg && !done_reg) begin
         if (op == 0) begin
            if ((DEPENDENCY[point_id] & peg_mask) == DEPENDENCY[point_id]) begin
               peg_mask <= peg_mask | bit_mask;
               support_mask[point_id] <= peg_mask | bit_mask;
            end else begin
               valid_reg <= 1'b0;
               set_done_next <= 1'b1;
            end
         end else begin
            if (peg_mask == support_mask[point_id]) begin
               peg_mask <= peg_mask & ~bit_mask;
            end else begin
               valid_reg <= 1'b0;
               set_done_next <= 1'b1;
            end
         end
      end

      if (!start && prev_start && valid_reg && !done_reg) begin
         set_done_next <= 1'b1;
      end

      done_reg <= set_done_next;
   end
end

assign valid = valid_reg;
assign done = done_reg;

endmodule