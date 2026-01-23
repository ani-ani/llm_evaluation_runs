module find_min_sublist (
input clk,
input rst_n,
input start,
input [2:0] num_sublists,
input [2:0] sublist_lengths [3:0],
input [7:0] all_elements [31:0],
output reg [2:0] min_index,
output reg [2:0] min_length,
output reg done
);

// Registers
reg [1:0] state;
reg [2:0] min_index_reg;
reg [2:0] min_length_reg;
reg [1:0] find_min_counter;
reg [1:0] idle_counter;

// Initialize on reset
always @(negedge rst_n) begin
   if (!rst_n) begin
      state <= 0;
      min_index_reg <= 0;
      min_length_reg <= 8;
      find_min_counter <= 0;
      idle_counter <= 0;
   end
end

// Main logic
always @(posedge clk) begin
   if (!rst_n) begin
      min_index <= 0;
      min_length <= 0;
      done <= 0;
   end else begin
      case (state)
         0: // IDLE
            if (start) begin
               if (idle_counter == 0) begin
                  idle_counter <= 1;
               end else begin
                  idle_counter <= idle_counter - 1;
                  if (idle_counter == 0) begin
                     state <= 1;
                  end
               end
            end
         end
         1: // FIND_MIN
            if (find_min_counter < 4) begin
               if (find_min_counter < num_sublists) begin
                  if (sublist_lengths[find_min_counter] < min_length_reg) begin
                     min_length_reg <= sublist_lengths[find_min_counter];
                     min_index_reg <= find_min_counter;
                  end
               end
               if (find_min_counter < 3) begin
                  find_min_counter <= find_min_counter + 1;
               end else begin
                  state <= 2;
               end
            end
         end
         2: // DONE
            state <= 2;
      endcase
      min_index <= min_index_reg;
      min_length <= min_length_reg;
      done <= (state == 2);
   end
end
endmodule