module substring_counter (
   input clk,
   input rst_n, // active low
   input start,
   input [15:0][7:0] main_string,
   input [7:0] substring_length,
   input [7:0][7:0] substring,
   output reg [7:0] count,
   output reg done
);

reg [2:0] state_reg;
reg [3:0] position_reg;
reg [7:0] count_reg;
reg [2:0] char_index_reg;
reg [15:0][7:0] main_string_reg;
reg [7:0][7:0] substring_reg;
reg [2:0] substring_length_reg;
reg computing;

assign done = (state_reg == 4);
assign count = count_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state_reg <= 0;
      position_reg <= 0;
      count_reg <= 0;
      char_index_reg <= 0;
      main_string_reg <= 0;
      substring_reg <= 0;
      substring_length_reg <= 0;
      computing <= 0;
   end else begin
      if (computing == 0 && start) begin
          main_string_reg <= main_string;
          substring_reg <= substring;
          substring_length_reg <= substring_length;
          position_reg <= 0;
          count_reg <= 0;
          char_index_reg <= 0;
          state_reg <= 1;
          computing <= 1;
      end else begin
          if (state_reg == 1) begin // COMPARE
              if (char_index_reg < substring_length_reg) begin
                  if (position_reg + char_index_reg < 16) begin
                      if (main_string_reg[position_reg + char_index_reg][7:0] == substring_reg[char_index_reg][7:0]) begin
                          char_index_reg <= char_index_reg +1;
                          state_reg <=1;
                      end else begin
                          char_index_reg <=0;
                          state_reg <=3;
                      end
                  end else begin
                      state_reg <=3;
                  end
              end else begin
                  count_reg <= count_reg +1;
                  state_reg <=3;
              end
          end else if (state_reg == 3) begin // NEXT_POS
              position_reg <= position_reg + 1;
              if (position_reg > (16 - substring_length_reg)) begin
                  state_reg <= 4;
              end else begin
                  char_index_reg <= 0;
                  state_reg <= 1;
              end
          end else if (state_reg == 4) begin // DONE
              computing <= 0;
              state_reg <= 4;
          end
      end
   end
end
endmodule