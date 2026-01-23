module tram_explosion_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  output reg [7:0] char_addr,
  output reg [3:0] explosions,
  output reg done
);

parameter MAX_X = 8;
parameter MAX_L = 8;
parameter GRID_SIZE = 100;
parameter GRID_WIDTH = 10;

localparam IDLE = 3'd0;
localparam READ_GRID = 1;
localparam CALC_DISTANCES = 2;
localparam RESOLVE_CONFLICTS = 3;
localparam COUNT_EXPLOSIONS = 4;
localparam FINISHED = 5;

reg [2:0] state;
reg [3:0] x_row[MAX_X];
reg [3:0] x_col[MAX_X];
reg [3:0] l_row[MAX_L];
reg [3:0] l_col[MAX_L];
reg [3:0] x_target_L[MAX_X];
reg [7:0] x_dist_sq[MAX_X];
reg [7:0] x_count;
reg [7:0] l_count;
reg [7:0] char_addr;
reg [3:0] explosions_reg;
reg done_reg;
reg [3:0] explosions_temp;

assign explosions = explosions_reg;
assign done = done_reg;

always @(posedge clk) if (!rst_n) begin
  state <= IDLE;
  x_count <= 8'd0;
  l_count <= 8'd0;
  for (int i=0; i<MAX_X; i++) begin
    x_row[i] <= 4'd0;
    x_col[i] <= 4'd0;
    x_target_L[i] <= 4'd0;
    x_dist_sq[i] <= 8'd0;
  end
  for (int i=0; i<MAX_L; i++) begin
    l_row[i] <= 4'd0;
    l_col[i] <= 4'd0;
  end
  char_addr <= 8'd0;
  explosions_reg <= 8'd0;
  done_reg <= 1'b0;
  explosions_temp <= 8'd0;
end else begin
  case (state)
    IDLE: begin
      if (start) begin
        char_addr <= 8'd0;
        x_count <= 8'd0;
        l_count <= 8'd0;
        for (int i=0; i<MAX_X; i++) begin
          x_row[i] <= 4'd0;
          x_col[i] <= 4'd0;
          x_target_L[i] <= 4'd0;
          x_dist_sq[i] <= 8'd0;
        end
        for (int i=0; i<MAX_L; i++) begin
          l_row[i] <= 4'd0;
          l_col[i] <= 4'd0;
        end
        state <= READ_GRID;
      end
      done_reg <= 1'b0;
    end
    READ_GRID: begin
      if (char_addr < GRID_SIZE-1) char_addr <= char_addr + 1;
      else state <= CALC_DISTANCES;
      wire [3:0] row = char_addr / GRID_WIDTH;
      wire [3:0] col = char_addr - (row * GRID_WIDTH);
      if (char_in == 8'd88) begin
        if (x_count < MAX_X) begin
          x_row[x_count] <= row;
          x_col[x_count] <= col;
          x_count <= x_count + 1;
        end
      end else if (char_in == 8'd76) begin
        if (l_count < MAX_L) begin
          l_row[l_count] <= row;
          l_col[l_count] <= col;
          l_count <= l_count + 1;
        end
      end
    end
    CALC_DISTANCES: begin
      generate
        for (int X_idx=0; X_idx<MAX_X; X_idx++) begin: gen_x
          if (X_idx < x_count) begin
            reg [7:0] min_dist_X;
            reg [3:0] target_L_X;
            min_dist_X = 8'd255;
            target_L_X = 4'd0;
            for (int L_idx=0; L_idx<MAX_L; L_idx++) begin: gen_l
              if (L_idx < l_count) begin
                wire [3:0] dx = x_row[X_idx] - l_row[L_idx];
                wire [3:0] dy = x_col[X_idx] - l_col[L_idx];
                wire [3:0] dx_abs = (dx >= 4'd0) ? dx : (4'd16 - dx);
                wire [3:0] dy_abs = (dy >= 4'd0) ? dy : (4'd16 - dy);
                wire [7:0] dist_sq = dx_abs * dx_abs + dy_abs * dy_abs;
                if (dist_sq < min_dist_X) begin
                  min_dist_X = dist_sq;
                  target_L_X = L_idx;
                end
              end
            end
            x_target_L[X_idx] <= target_L_X;
            x_dist_sq[X_idx] <= min_dist_X;
          end
        end
      endgenerate
      state <= RESOLVE_CONFLICTS;
    end
    RESOLVE_CONFLICTS: begin
      explosions_temp <= 8'd0;
      generate
        for (int L_idx=0; L_idx<MAX_L; L_idx++) begin: gen_l
          if (L_idx < l_count) begin
            reg [3:0] count_L;
            reg [3:0] first_dist;
            reg [1:0] all_equal;
            count_L = 4'd0;
            first_dist = 4'd0;
            all_equal = 2'b11;
            for (int X_idx=0; X_idx<MAX_X; X_idx++) begin: gen_x
              if (X_idx < x_count) begin
                if (x_target_L[X_idx] == L_idx) begin
                  count_L++;
                  if (count_L == 1) first_dist = x_dist_sq[X_idx];
                  else if (x_dist_sq[X_idx] != first_dist) all_equal = 2'b10;
                end
              end
            end
            if (count_L > 1 && all_equal[0]) explosions_temp += 1;
          end
        end
      endgenerate
      state <= COUNT_EXPLOSIONS;
    end
    COUNT_EXPLOSIONS: begin
      state <= FINISHED;
      explosions_reg <= explosions_temp;
    end
    FINISHED: begin
      done_reg <= 1'b1;
    end
  endcase
  done_reg <= done_reg;
end
endmodule