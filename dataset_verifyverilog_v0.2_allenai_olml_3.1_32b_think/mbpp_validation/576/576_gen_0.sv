module sublist_checker (
   input clk,
   input rst_n,
   input start,
   input [7:0] main_array [0:7],
   input [7:0] pattern [0:7],
   input [2:0] main_len,
   input [2:0] pattern_len,
   output reg result,
   output reg done
);

reg [7:0] main_arr_reg [0:7];
reg [7:0] pattern_reg [0:7];
reg [2:0] main_len_reg;
reg [2:0] pattern_len_reg;
reg [2:0] current_position;
reg [2:0] current_pattern_index;
reg [2:0] state;

parameter IDLE = 2'b00;
parameter PROCESSING = 2'b01;
parameter DONE = 2'b10;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      main_arr_reg <= 8'b0;
      pattern_reg <= 8'b0;
      main_len_reg <= 3'b0;
      pattern_len_reg <= 3'b0;
      current_position <= 3'b0;
      current_pattern_index <= 3'b0;
      result <= 0;
      done <= 0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            main_arr_reg <= main_array;
            pattern_reg <= pattern;
            main_len_reg <= main_len;
            pattern_len_reg <= pattern_len;
            if (pattern_len_reg > main_len_reg) begin
               result <= 0;
               done <= 1;
               state <= DONE;
            end else begin
               current_position <= 0;
               current_pattern_index <= 0;
               state <= PROCESSING;
            end
         end
      end else if (state == PROCESSING) begin
         localparam integer max_pos = main_len_reg - pattern_len_reg;
         if (current_pattern_index < pattern_len_reg) begin
            if (main_arr_reg[current_position + current_pattern_index] == pattern_reg[current_pattern_index]) begin
               if (current_pattern_index + 1 == pattern_len_reg) begin
                  result <= 1;
                  done <= 1;
                  state <= DONE;
               end else begin
                  current_pattern_index <= current_pattern_index + 1;
               end
            end else begin
               current_position <= current_position + 1;
               current_pattern_index <= 0;
               if (current_position > max_pos) begin
                  result <= 0;
                  done <= 1;
                  state <= DONE;
               end
            end
         end else begin
            if (current_position < max_pos) begin
               current_position <= current_position + 1;
               current_pattern_index <= 0;
            end else begin
               result <= 0;
               done <= 1;
               state <= DONE;
            end
         end
      end else if (state == DONE) begin
         // No action
      end
   end
endmodule