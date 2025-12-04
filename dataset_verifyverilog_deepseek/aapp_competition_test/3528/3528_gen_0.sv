module convex_hull_area(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nails,
  input [7:0][15:0] nail_x,
  input [7:0][15:0] nail_y,
  input [5:0][1:0] remove_seq,
  output reg [35:0] area,
  output reg valid,
  output reg done
);
  typedef enum {IDLE, INIT, FIND_REMOVE, HULL_START, BUILD_HULL, CALC_AREA, FINISH} state_t;
  reg [2:0] state;
  reg [7:0] active_nails;
  reg [15:0] curr_x[0:7];
  reg [15:0] curr_y[0:7];
  reg [15:0] hull_x[0:7];
  reg [15:0] hull_y[0:7];
  reg [2:0] num_active;
  reg [2:0] remove_step;
  reg [3:0] hull_cnt;
  reg [3:0] hull_top;
  reg [35:0] sum;
  reg [1:0] dir;
  wire [2:0] max_pos, min_pos;
  wire [15:0] max_val, min_val;
  wire [15:0] x_vals[0:7];
  wire [15:0] y_vals[0:7];
  
  assign x_vals = curr_x;
  assign y_vals = curr_y;
  
  find_max #(8) find_max_u(.vals(y_vals), .active(active_nails), .max_val(max_val), .max_pos(max_pos));
  find_min #(8) find_min_u(.vals(y_vals), .active(active_nails), .min_val(min_val), .min_pos(min_pos));
  
  generate
    genvar i;
    for (i=0; i<8; i=i+1) begin : point_init
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          curr_x[i] <= 0;
          curr_y[i] <= 0;
        end else if (state == INIT) begin
          curr_x[i] <= (i < num_nails) ? nail_x[i] : 0;
          curr_y[i] <= (i < num_nails) ? nail_y[i] : 0;
        end
      end
    end
  endgenerate
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      active_nails <= 0;
      num_active <= 0;
      remove_step <= 0;
      hull_cnt <= 0;
      hull_top <= 0;
      sum <= 0;
      area <= 0;
      valid <= 0;
      done <= 0;
      dir <= 0;
      hull_x <= '{default:0};
      hull_y <= '{default:0};
    end else begin
      valid <= 0;
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          active_nails <= (8'b11111111 >> (8 - num_nails));
          num_active <= num_nails;
          remove_step <= 0;
          state <= FIND_REMOVE;
        end
        FIND_REMOVE: begin
          dir <= remove_seq[remove_step];
          state <= HULL_START;
          for (int i=0; i<8; i++) begin
            if (active_nails[i]) begin
              case (dir)
                2'b00: if (curr_x[i] == min_val) active_nails[i] <= 0;
                2'b01: if (curr_x[i] == max_val) active_nails[i] <= 0;
                2'b10: if (curr_y[i] == max_val) active_nails[i] <= 0;
                2'b11: if (curr_y[i] == min_val) active_nails[i] <= 0;
              endcase
            end
          end
          num_active <= num_active - 1;
        end
        HULL_START: begin
          hull_cnt <= 0;
          hull_top <= 0;
          hull_x <= '{default:0};
          hull_y <= '{default:0};
          state <= BUILD_HULL;
        end
        BUILD_HULL: begin
          hull_x[hull_top] <= curr_x[hull_cnt];
          hull_y[hull_top] <= curr_y[hull_cnt];
          hull_top <= hull_top + 1;
          hull_cnt <= hull_cnt + 1;
          if (hull_cnt == 7) begin
            state <= CALC_AREA;
          end
        end
        CALC_AREA: begin
          sum <= 0;
          for (int i=0; i<hull_top; i++) begin
            int next = (i == hull_top-1) ? 0 : i+1;
            sum <= sum + (hull_x[i] * hull_y[next] - hull_x[next] * hull_y[i]);
          end
          area <= (sum[35:1]) * 5;
          valid <= 1;
          if (remove_step == 5) begin
            state <= FINISH;
          end else begin
            remove_step <= remove_step + 1;
            state <= FIND_REMOVE;
          end
        end
        FINISH: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule

module find_max #(parameter N=8) (
  input [N-1:0][15:0] vals,
  input [N-1:0] active,
  output [15:0] max_val,
  output [$clog2(N)-1:0] max_pos
);
  reg [15:0] temp_val;
  reg [$clog2(N)-1:0] temp_pos;
  
  always_comb begin
    temp_val = 16'h8000;
    temp_pos = 0;
    for (int i=0; i<N; i++) begin
      if (active[i] && vals[i] > temp_val) begin
        temp_val = vals[i];
        temp_pos = i;
      end
    end
  end
  
  assign max_val = temp_val;
  assign max_pos = temp_pos;
endmodule

module find_min #(parameter N=8) (
  input [N-1:0][15:0] vals,
  input [N-1:0] active,
  output [15:0] min_val,
  output [$clog2(N)-1:0] min_pos
);
  reg [15:0] temp_val;
  reg [$clog2(N)-1:0] temp_pos;
  
  always_comb begin
    temp_val = 16'h7FFF;
    temp_pos = 0;
    for (int i=0; i<N; i++) begin
      if (active[i] && vals[i] < temp_val) begin
        temp_val = vals[i];
        temp_pos = i;
      end
    end
  end
  
  assign min_val = temp_val;
  assign min_pos = temp_pos;
endmodule