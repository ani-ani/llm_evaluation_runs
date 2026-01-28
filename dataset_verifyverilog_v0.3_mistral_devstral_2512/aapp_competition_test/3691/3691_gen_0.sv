module data_collection(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [63:0] x0, y0, ax, ay, bx, by, xs, ys, t,
  output reg [63:0] result,
  output reg done
);

  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] GENERATE = 3'd1;
  localparam [2:0] COMPUTE_DIST = 3'd2;
  localparam [2:0] DOUBLE_LOOP = 3'd3;
  localparam [2:0] DONE_STATE = 3'd4;

  reg [2:0] state, next_state;
  reg [6:0] node_idx;
  reg [6:0] i, j;
  reg [63:0] x [0:99];
  reg [63:0] y [0:99];
  reg [63:0] dist_prefix [0:99];
  reg [63:0] max_count;
  reg [63:0] abs_x_i, abs_y_i, dist_i;
  reg [63:0] abs_x_j, abs_y_j, dist_j;
  reg [63:0] travel, total1, total2;
  reg condition;
  reg [63:0] count;

  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 64'd0;
      node_idx <= 7'd0;
      i <= 7'd0;
      j <= 7'd0;
      max_count <= 64'd0;
      for (k = 0; k < 100; k = k + 1) begin
        x[k] <= 64'd0;
        y[k] <= 64'd0;
        dist_prefix[k] <= 64'd0;
      end
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        done = 1'b0;
        if (start) begin
          x[0] = x0;
          y[0] = y0;
          dist_prefix[0] = 64'd0;
          node_idx = 7'd1;
          next_state = GENERATE;
        end
      end

      GENERATE: begin
        if (node_idx < 100) begin
          x[node_idx] = ax * x[node_idx - 1] + bx;
          y[node_idx] = ay * y[node_idx - 1] + by;
          next_state = COMPUTE_DIST;
        end else begin
          i = 7'd0;
          j = 7'd0;
          max_count = 64'd0;
          next_state = DOUBLE_LOOP;
        end
      end

      COMPUTE_DIST: begin
        if (x[node_idx] >= x[node_idx - 1]) begin
          abs_x_i = x[node_idx] - x[node_idx - 1];
        end else begin
          abs_x_i = x[node_idx - 1] - x[node_idx];
        end

        if (y[node_idx] >= y[node_idx - 1]) begin
          abs_y_i = y[node_idx] - y[node_idx - 1];
        end else begin
          abs_y_i = y[node_idx - 1] - y[node_idx];
        end

        dist_prefix[node_idx] = dist_prefix[node_idx - 1] + abs_x_i + abs_y_i;
        node_idx = node_idx + 7'd1;
        next_state = GENERATE;
      end

      DOUBLE_LOOP: begin
        if (xs >= x[i]) begin
          abs_x_i = xs - x[i];
        end else begin
          abs_x_i = x[i] - xs;
        end

        if (ys >= y[i]) begin
          abs_y_i = ys - y[i];
        end else begin
          abs_y_i = y[i] - ys;
        end

        dist_i = abs_x_i + abs_y_i;

        if (xs >= x[j]) begin
          abs_x_j = xs - x[j];
        end else begin
          abs_x_j = x[j] - xs;
        end

        if (ys >= y[j]) begin
          abs_y_j = ys - y[j];
        end else begin
          abs_y_j = y[j] - ys;
        end

        dist_j = abs_x_j + abs_y_j;
        travel = dist_prefix[j] - dist_prefix[i];
        total1 = dist_i + travel;
        total2 = dist_j + travel;
        condition = (total1 <= t) || (total2 <= t);
        count = j - i + 7'd1;

        if (condition) begin
          if (count > max_count) begin
            max_count = count;
          end
        end

        if (j < 99) begin
          j = j + 7'd1;
        end else begin
          j = i + 7'd1;
          if (i < 99) begin
            i = i + 7'd1;
          end else begin
            next_state = DONE_STATE;
          end
        end
      end

      DONE_STATE: begin
        result = max_count;
        done = 1'b1;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule