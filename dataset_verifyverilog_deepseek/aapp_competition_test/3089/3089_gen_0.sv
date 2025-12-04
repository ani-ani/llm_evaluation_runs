module taxi_distance_calculator(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_vertices,
  input signed [31:0] vertices_x [0:7],
  input signed [31:0] vertices_y [0:7],
  output reg signed [31:0] expected,
  output reg done
);

typedef enum {
  IDLE,
  SETUP,
  GENERATE,
  CHECK1,
  CHECK2,
  CALC,
  UPDATE,
  AVERAGE,
  DONE_ST
} state_t;

reg [7:0] lfsr;
reg [31:0] min_x, max_x, min_y, max_y;
reg signed [31:0] random_x1, random_y1, random_x2, random_y2;
reg signed [63:0] sum;
reg [9:0] sample_count;
reg [2:0] index;
reg got_ref_sign;
reg ref_sign;
state_t current_state;
wire point1_valid, point2_valid;

// Cross product checks
function automatic logic check_inside(input signed [31:0] px, py, input [2:0] n_verts);
  logic sign;
  logic match;
  integer i, j;
  if (n_verts < 3) return 0;
  j = n_verts - 1;
  for (i = 0; i < n_verts; i = i + 1) begin
    logic signed [63:0] cp;
    cp = (vertices_x[i] - vertices_x[j]) * (py - vertices_y[j]) -
         (vertices_y[i] - vertices_y[j]) * (px - vertices_x[j]);
    if (i == 0) sign = cp > 0;
    else if ((cp > 0) !== sign) return 0;
    j = i;
  end
  return 1;
endfunction

assign point1_valid = check_inside(random_x1, random_y1, num_vertices);
assign point2_valid = check_inside(random_x2, random_y2, num_vertices);

// LFSR next state
function automatic [7:0] lfsr_next(input [7:0] current);
  lfsr_next = {current[6:0], current[7] ^ current[5] ^ current[4] ^ current[3]};
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    sum <= 0;
    sample_count <= 0;
    current_state <= IDLE;
    expected <= 0;
    index <= 0;
    min_x <= 0;
    max_x <= 0;
    min_y <= 0;
    max_y <= 0;
    random_x1 <= 0;
    random_y1 <= 0;
    random_x2 <= 0;
    random_y2 <= 0;
    lfsr <= 8'hFF;
  end else begin
    done <= 0;
    lfsr <= lfsr_next(lfsr);
    case (current_state)
      IDLE: begin
        if (start) begin
          index <= 0;
          current_state <= SETUP;
          sum <= 0;
          sample_count <= 0;
        end
      end
      SETUP: begin
        if (index == 0) begin
          min_x <= vertices_x[0];
          max_x <= vertices_x[0];
          min_y <= vertices_y[0];
          max_y <= vertices_y[0];
          index <= 1;
        end else if (index < num_vertices) begin
          if (vertices_x[index] < min_x) min_x <= vertices_x[index];
          if (vertices_x[index] > max_x) max_x <= vertices_x[index];
          if (vertices_y[index] < min_y) min_y <= vertices_y[index];
          if (vertices_y[index] > max_y) max_y <= vertices_y[index];
          index <= index + 1;
        end else begin
          current_state <= GENERATE;
        end
      end
      GENERATE: begin
        random_x1 <= min_x + ((max_x - min_x) * {24'b0, lfsr});
        random_y1 <= min_y + ((max_y - min_y) * {24'b0, lfsr_next(lfsr)});
        random_x2 <= min_x + ((max_x - min_x) * {24'b0, lfsr_next(lfsr_next(lfsr))});
        random_y2 <= min_y + ((max_y - min_y) * {24'b0, lfsr_next(lfsr_next(lfsr_next(lfsr)))});
        current_state <= CHECK1;
      end
      CHECK1: begin
        if (point1_valid) current_state <= CHECK2;
        else current_state <= GENERATE;
      end
      CHECK2: begin
        if (point2_valid) current_state <= CALC;
        else current_state <= GENERATE;
      end
      CALC: begin
        automatic signed [31:0] dx, dy, dist;
        dx = random_x1 - random_x2;
        dy = random_y1 - random_y2;
        dist = (dx >= 0) ? dx : -dx;
        dist += (dy >= 0) ? dy : -dy;
        sum <= sum + dist;
        current_state <= UPDATE;
      end
      UPDATE: begin
        sample_count <= sample_count + 1;
        if (sample_count == 1023) current_state <= AVERAGE;
        else current_state <= GENERATE;
      end
      AVERAGE: begin
        expected <= sum >>> 10; // Divide by 1024 (Q16.16)
        current_state <= DONE_ST;
      end
      DONE_ST: begin
        done <= 1;
        current_state <= IDLE;
      end
    endcase
  end
end
endmodule