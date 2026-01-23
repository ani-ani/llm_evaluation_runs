module shortest_path_calculator (
    input clk,
    input rst_n, // active low
    input start,
    input [15:0] poly_x [0:7],
    input [15:0] poly_y [0:7],
    input [2:0] vertex_count,
    output reg [31:0] min_distance,
    output reg done
);

// Parameters
localparam IDLE = 3'd0;
localparam LOAD_VERTICES = 3'd1;
localparam CALC_VERTEX_DIST = 3'd2;
localparam CALC_EDGE_DIST = 3'd3;
localparam DONE_STATE = 3'd4;

// Registers
reg [31:0] min_distance_reg;
reg [3:0] state;
reg [7:0] stored_poly_x [0:7];
reg [7:0] stored_poly_y [0:7];
reg [3:0] stored_vertex_count;
reg [7:0] vertex_idx;
reg [7:0] edge_idx;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    min_distance_reg <= 32'hFFFFFFFF; // Initialize to max
    stored_vertex_count <= 8'd0; // Will be updated in LOAD_VERTICES
    vertex_idx <= 8'd0;
    edge_idx <= 8'd0;
    min_distance <= 32'h0;
    done <= 1'b0;
  end else begin
    if (state == IDLE && start) begin
      state <= LOAD_VERTICES;
    end
    if (state == LOAD_VERTICES) begin
      stored_poly_x <= poly_x;
      stored_poly_y <= poly_y;
      stored_vertex_count <= vertex_count;
      state <= CALC_VERTEX_DIST;
      vertex_idx <= 8'd0;
    end
    if (state == CALC_VERTEX_DIST) begin
      if (vertex_idx < stored_vertex_count) begin
        [15:0] x = stored_poly_x[vertex_idx];
        [15:0] y = stored_poly_y[vertex_idx];
        [31:0] sum_sq;
        if (x == 0 && y == 0) begin
          sum_sq = 0;
        end else begin
          sum_sq = x*x + y*y;
        end
        [31:0] guess;
        if (sum_sq == 0) begin
          guess = 0;
        end else begin
          guess = sum_sq;
          guess = (guess + sum_sq / guess) >> 1;
          guess = (guess + sum_sq / guess) >> 1;
          guess = (guess + sum_sq / guess) >> 1;
        end
        [31:0] dist = guess << 12;
        if (dist < min_distance_reg) begin
          min_distance_reg <= dist;
        end
        vertex_idx <= vertex_idx + 1;
      end else begin
        state <= CALC_EDGE_DIST;
        vertex_idx <= 8'd0;
        edge_idx <= 8'd0;
      end
    end
    if (state == CALC_EDGE_DIST) begin
      if (edge_idx < stored_vertex_count) begin
        [15:0] ax = stored_poly_x[edge_idx];
        [15:0] ay = stored_poly_y[edge_idx];
        [15:0] bx, by;
        if (edge_idx +1 < stored_vertex_count) begin
          bx = stored_poly_x[edge_idx +1];
          by = stored_poly_y[edge_idx +1];
        end else begin
          bx = stored_poly_x[0];
          by = stored_poly_y[0];
        end
        [31:0] dax = ax*ax + ay*ay;
        [31:0] dbx = bx*bx + by*by;
        [31:0] dist;
        if (dax < dbx) begin
          [31:0] sum_sq_ax = ax*ax + ay*ay;
          [31:0] guess_ax;
          if (sum_sq_ax == 0) begin
            guess_ax = 0;
          end else begin
            guess_ax = sum_sq_ax;
            guess_ax = (guess_ax + sum_sq_ax / guess_ax) >>1;
            guess_ax = (guess_ax + sum_sq_ax / guess_ax) >>1;
            guess_ax = (guess_ax + sum_sq_ax / guess_ax) >>1;
          end
          dist = guess_ax <<12;
        } else begin
          [31:0] sum_sq_bx = bx*bx + by*by;
          [31:0] guess_bx;
          if (sum_sq_bx == 0) begin
            guess_bx = 0;
          end else begin
            guess_bx = sum_sq_bx;
            guess_bx = (guess_bx + sum_sq_bx / guess_bx) >>1;
            guess_bx = (guess_bx + sum_sq_bx / guess_bx) >>1;
            guess_bx = (guess_bx + sum_sq_bx / guess_bx) >>1;
          end
          dist = guess_bx <<12;
        end
        if (dist < min_distance_reg) begin
          min_distance_reg <= dist;
        end
        edge_idx <= edge_idx +1;
      end else begin
        state <= DONE_STATE;
        min_distance <= min_distance_reg;
        done <= 1'b1;
      end
    end
    if (state == DONE_STATE) begin
      if (!start) begin
        // Stay in DONE
      end else begin
        // If start is high again, maybe restart? But spec says latency after start, so probably not.
        // For simplicity, stay in DONE until reset.
      end
      min_distance <= min_distance_reg;
      done <= 1'b1;
    end
  end
end

endmodule