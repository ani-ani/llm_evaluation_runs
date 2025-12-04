module club_fencing_cost(
  input clk,
  input rst_n,
  input start,
  input [3:0] B,
  input [2:0] H,
  input [2:0] R,
  input [2:0] C,
  input [15:0] grid,
  output reg [10:0] total_cost,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE = 3'd0,
    CALC_LIGHTS = 3'd1,
    FIND_DARK = 3'd2,
    CALC_FENCES = 3'd3,
    DONE_ST = 3'd4
  } state_t;

  reg [2:0] current_state, next_state;
  reg [1:0] i_reg, j_reg, r_reg, c_reg;
  reg [1:0] edge_i_reg, edge_j_reg;
  reg [1:0] R_reg, C_reg;
  reg [21:0] cycle_counter;
  reg [31:0] light_levels [3:0][3:0];
  reg dark [3:0][3:0];
  wire [3:0] grid_vals [3:0][3:0];
  
  function [31:0] get_reciprocal(input [7:0] denom);
    case(denom)
      1: get_reciprocal = 32'h10000;
      2: get_reciprocal = 32'h8000;
      3: get_reciprocal = 32'h5555;
      4: get_reciprocal = 32'h4000;
      5: get_reciprocal = 32'h3333;
      6: get_reciprocal = 32'h2AAA;
      7: get_reciprocal = 32'h2492;
      8: get_reciprocal = 32'h2000;
      9: get_reciprocal = 32'h1C71;
      10: get_reciprocal = 32'h1999;
      11: get_reciprocal = 32'h1745;
      12: get_reciprocal = 32'h1555;
      13: get_reciprocal = 32'h13B1;
      14: get_reciprocal = 32'h1249;
      15: get_reciprocal = 32'h1111;
      16: get_reciprocal = 32'h1000;
      17: get_reciprocal = 32'hF0F0;
      18: get_reciprocal = 32'hE38E;
      19: get_reciprocal = 32'hD794;
      20: get_reciprocal = 32'hCCCC;
      21: get_reciprocal = 32'hC30C;
      22: get_reciprocal = 32'hBA2E;
      23: get_reciprocal = 32'hB216;
      24: get_reciprocal = 32'hAAAA;
      25: get_reciprocal = 32'hA3D7;
      26: get_reciprocal = 32'h9D89;
      27: get_reciprocal = 32'h97B4;
      28: get_reciprocal = 32'h9249;
      29: get_reciprocal = 32'h8D3D;
      30: get_reciprocal = 32'h8888;
      31: get_reciprocal = 32'h8421;
      32: get_reciprocal = 32'h8000;
      33: get_reciprocal = 32'h7878;
      34: get_reciprocal = 32'h7507;
      35: get_reciprocal = 32'h71C7;
      36: get_reciprocal = 32'h6E45;
      37: get_reciprocal = 32'h6AE8;
      38: get_reciprocal = 32'h67B1;
      39: get_reciprocal = 32'h6496;
      40: get_reciprocal = 32'h6186;
      41: get_reciprocal = 32'h5E84;
      42: get_reciprocal = 32'h5B94;
      43: get_reciprocal = 32'h58D3;
      default: get_reciprocal = 32'h0;
    endcase
  endfunction

  generate
    genvar i, j;
    for (i = 0; i < 4; i=i+1) begin : grid_row
      for (j = 0; j < 4; j=j+1) begin : grid_col
        assign grid_vals[i][j] = grid[15 - ((i*4 + j)*4) : 15 - ((i*4 + j)*4) - 3];
      end
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      total_cost <= 11'b0;
    end else begin
      current_state <= next_state;
      case(current_state)
        IDLE: begin
          total_cost <= 11'b0;
          done <= 1'b0;
          if (start) begin
            R_reg <= R[1:0];
            C_reg <= C[1:0];
          end
        end

        CALC_LIGHTS: begin
          if (i_reg < R_reg) begin
            // Calculate dx, dy
            reg [1:0] dx, dy;
            reg [3:0] dx_sq, dy_sq, h_sq;
            reg [7:0] denom;
            reg [31:0] rec_val;
            dx = (r_reg > i_reg) ? (r_reg - i_reg) : (i_reg - r_reg);
            dy = (c_reg > j_reg) ? (c_reg - j_reg) : (j_reg - c_reg);
            dx_sq = dx * dx;
            dy_sq = dy * dy;
            h_sq = H * H;
            denom = dx_sq + dy_sq + h_sq;
            rec_val = get_reciprocal(denom);
            light_levels[i_reg][j_reg] <= light_levels[i_reg][j_reg] + (grid_vals[r_reg][c_reg] * rec_val);

            if (c_reg == C_reg-1) begin
              c_reg <= 2'b0;
              if (r_reg == R_reg-1) begin
                r_reg <= 2'b0;
                if (j_reg == C_reg-1) begin
                  j_reg <= 2'b0;
                  if (i_reg == R_reg-1) begin
                    i_reg <= 2'b0;
                  end else begin
                    i_reg <= i_reg + 1;
                  end
                end else begin
                  j_reg <= j_reg + 1;
                end
              end else begin
                r_reg <= r_reg + 1;
              end
            end else begin
              c_reg <= c_reg + 1;
            end
          end
        end

        FIND_DARK: begin
          reg [31:0] b_threshold;
          b_threshold = B << 16;
          if (i_reg < R_reg) begin
            dark[i_reg][j_reg] <= (light_levels[i_reg][j_reg] < b_threshold);
            if (j_reg == C_reg-1) begin
              j_reg <= 2'b0;
              if (i_reg == R_reg-1) begin
                i_reg <= 2'b0;
              end else begin
                i_reg <= i_reg + 1;
              end
            end else begin
              j_reg <= j_reg + 1;
            end
          end
        end

        CALC_FENCES: begin
          // Process vertical edges (left-right) then horizontal (top-bottom)
          if (edge_i_reg < R_reg && edge_j_reg < (C_reg-1)) begin
            if (dark[edge_i_reg][edge_j_reg] || dark[edge_i_reg][edge_j_reg+1]) begin
              if (dark[edge_i_reg][edge_j_reg] && dark[edge_i_reg][edge_j_reg+1]) begin
                total_cost <= total_cost + 11'd43;
              end else begin
                total_cost <= total_cost + 11'd11;
              end
            end
            if (edge_j_reg == C_reg-2) begin
              edge_j_reg <= 2'b0;
              edge_i_reg <= edge_i_reg + 1;
            end else begin
              edge_j_reg <= edge_j_reg + 1;
            end
          end else if (edge_i_reg < (R_reg-1) && edge_j_reg < C_reg) begin
            if (dark[edge_i_reg][edge_j_reg] || dark[edge_i_reg+1][edge_j_reg]) begin
              if (dark[edge_i_reg][edge_j_reg] && dark[edge_i_reg+1][edge_j_reg]) begin
                total_cost <= total_cost + 11'd43;
              end else begin
                total_cost <= total_cost + 11'd11;
              end
            end
            if (edge_j_reg == C_reg-1) begin
              edge_j_reg <= 2'b0;
              edge_i_reg <= edge_i_reg + 1;
            end else begin
              edge_j_reg <= edge_j_reg + 1;
            end
          end
        end

        DONE_ST: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case(current_state)
      IDLE: next_state = start ? CALC_LIGHTS : IDLE;
      CALC_LIGHTS: 
        if (i_reg == R_reg-1 && j_reg == C_reg-1 && r_reg == R_reg-1 && c_reg == C_reg-1) 
          next_state = FIND_DARK;
      FIND_DARK:
        if (i_reg == R_reg-1 && j_reg == C_reg-1)
          next_state = CALC_FENCES;
      CALC_FENCES:
        if (edge_i_reg == R_reg-1 && edge_j_reg == C_reg-1) 
          next_state = DONE_ST;
      DONE_ST:
        if (!start) next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_reg <= 2'b0;
      j_reg <= 2'b0;
      r_reg <= 2'b0;
      c_reg <= 2'b0;
      edge_i_reg <= 2'b0;
      edge_j_reg <= 2'b0;
      cycle_counter <= 22'd0;
      for (int i=0; i<4; i++) begin
        for (int j=0; j<4; j++) begin
          light_levels[i][j] <= 32'b0;
          dark[i][j] <= 1'b0;
        end
      end
    end else begin
      cycle_counter <= cycle_counter + 1;
      case(next_state)
        IDLE: begin
          i_reg <= 2'b0;
          j_reg <= 2'b0;
          r_reg <= 2'b0;
          c_reg <= 2'b0;
          edge_i_reg <= 2'b0;
          edge_j_reg <= 2'b0;
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              light_levels[i][j] <= 32'b0;
              dark[i][j] <= 1'b0;
            end
          end
        end
        FIND_DARK: begin
          i_reg <= 2'b0;
          j_reg <= 2'b0;
        end
        CALC_FENCES: begin
          edge_i_reg <= 2'b0;
          edge_j_reg <= 2'b0;
        end
      endcase
    end
  end
endmodule