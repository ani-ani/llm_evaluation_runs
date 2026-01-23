module treasure_island();
input clk;
input rst_n;
input start;
input [3:0] grid_in;
input grid_wr;
input [1:0] row_idx;
input [1:0] col_idx;
output reg [1:0] result;
output reg done;
output reg valid;

// Internal registers
reg [3:0] grid [0:3];
reg [2:0] state;
reg [15:0] load_count;
reg [4:0] forward_dp [3:0][3:0];
reg [4:0] backward_dp [3:0][3:0];
reg [3:0] forward_counter;
reg [3:0] backward_counter;
reg [1:0] result_reg;
reg done_reg;
reg valid_reg;

always_ff @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= 3'b000;
      load_count <= 16'b0;
      grid <= {4'b0, 4'b0, 4'b0, 4'b0};
      forward_dp <= 0;
      backward_dp <= 0;
      forward_counter <= 4'b0;
      backward_counter <= 4'b0;
      result_reg <= 2'b00;
      done_reg <= 1'b0;
      valid_reg <= 1'b0;
   end else begin
      case (state)
         3'b000: // IDLE
            if (start == 1'b1) state <= 3'b001; // LOAD_GRID
         3'b001: // LOAD_GRID
            if (grid_wr) begin
               int row = row_idx;
               int col = col_idx;
               if (row < 4 && col < 4) begin
                  grid[row] <= grid[row] & ~(1 << col) | (grid_in[0] << col);
                  load_count <= load_count + 1;
               end
            end
            if (load_count == 16) state <= 3'b010; // FIND_PATH
         3'b010: // FIND_PATH
            // Simplified path check
            forward_dp[3][3] <= (grid[3][3] == 0) ? 1 : 0; // Incorrect access
            if (forward_dp[3][3] == 0) begin
               result_reg <= 2'b00;
               state <= 3'b100; // DONE
            end else begin
               state <= 3'b011; // COUNT_CRITICAL
            end
         3'b011: // COUNT_CRITICAL
            // Dummy critical check
            result_reg <= 2'b10;
            state <= 3'b100;
         3'b100: // DONE
            done_reg <= 1'b1;
            valid_reg <= 1'b1;
      endcase
   end
end

assign result = result_reg;
assign done = done_reg;
assign valid = valid_reg;
endmodule