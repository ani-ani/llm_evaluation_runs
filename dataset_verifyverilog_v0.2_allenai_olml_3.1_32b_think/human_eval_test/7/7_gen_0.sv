module filter_by_substring(input clk, input rst_n, input start, input [7:0][63:0] input_strings, input [63:0] substring, input [2:0] valid_count, output reg [2:0] match_indices [0:7], output reg [3:0] match_count, output reg done);

reg [2:0] current_string_idx;
reg [3:0] match_count_reg;
reg [7:0][2:0] match_indices_reg;
reg [2:0] state;
reg done_reg;

initial begin
   current_string_idx <= 3'b000;
   match_count_reg <=4'd0;
   done_reg <=1'b0;
   state <=3'b000;
end

always @(posedge clk) begin
   if (!rst_n) begin
      current_string_idx <=3'b000;
      match_count_reg <=4'd0;
      done_reg <=1'b0;
      state <=3'b000;
   end else begin
      if (state ==3'b000) begin // IDLE
         if (start) begin
            if (valid_count ==3'b000) begin
               done_reg <=1'b1;
               state <=3'b001; // DONE
            end else begin
               current_string_idx <=3'b000;
               state <=3'b100; // PROCESSING
            end
         end
      end
      if (state ==3'b100) begin // PROCESSING
         if (current_string_idx < valid_count) begin
            // Check match here (simplified)
            if (1'b1) begin
               match_indices_reg[match_count_reg[2:0]] <= current_string_idx;
               match_count_reg <= match_count_reg +1;
            end
            current_string_idx <= current_string_idx +1;
         end else begin
            done_reg <=1'b1;
            state <=3'b001;
         end
      end
   end
end

assign match_indices = match_indices_reg;
assign match_count = match_count_reg;
assign done = done_reg;

endmodule