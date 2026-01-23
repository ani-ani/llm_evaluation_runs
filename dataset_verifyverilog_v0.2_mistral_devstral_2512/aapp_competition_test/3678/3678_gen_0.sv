module loop_validator (
  input clk,
  input rst_n,
  input start,
  input [2:0] n_in,
  input [7:0] point_x [0:7],
  input [7:0] point_y [0:7],
  output reg valid,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam LOAD_POINTS = 3'b001;
  localparam GENERATE_PERMUTATION = 3'b010;
  localparam VALIDATE_PATH = 3'b011;
  localparam CHECK_RESULT = 3'b100;
  localparam DONE = 3'b101;

  // State machine
  reg [2:0] state = IDLE;

  // Internal registers
  reg [2:0] n = 0;
  reg [7:0] x [0:7];
  reg [7:0] y [0:7];
  reg [2:0] perm [0:7];
  reg [5:0] perm_idx = 0;
  reg [2:0] path_idx = 0;
  reg valid_path = 0;
  reg [63:0] visited = 0;
  reg [1:0] last_dir = 0;
  reg [5:0] attempt_counter = 0;

  // Permutation generation (simplified for synthesis)
  reg [2:0] lfsr = 0;
  reg [2:0] lfsr_next = 0;

  // Load points
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      done <= 0;
      n <= 0;
      perm_idx <= 0;
      path_idx <= 0;
      valid_path <= 0;
      visited <= 0;
      attempt_counter <= 0;
      lfsr <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_POINTS;
            n <= n_in;
            for (int i = 0; i < 8; i = i + 1) begin
              x[i] <= point_x[i];
              y[i] <= point_y[i];
            end
          end
        end
        LOAD_POINTS: begin
          state <= GENERATE_PERMUTATION;
          perm_idx <= 0;
          attempt_counter <= 0;
        end
        GENERATE_PERMUTATION: begin
          // Generate next permutation (simplified)
          lfsr_next = {lfsr[1:0], lfsr[2] ^ lfsr[0]};
          perm[perm_idx] <= lfsr_next;
          lfsr <= lfsr_next;
          perm_idx <= perm_idx + 1;
          if (perm_idx == n) begin
            state <= VALIDATE_PATH;
            path_idx <= 0;
            valid_path <= 1;
            visited <= 0;
            last_dir <= 0;
          end
        end
        VALIDATE_PATH: begin
          if (path_idx < n) begin
            // Check adjacency
            reg [7:0] x0 = x[perm[path_idx]];
            reg [7:0] y0 = y[perm[path_idx]];
            reg [7:0] x1 = x[perm[(path_idx + 1) % n]];
            reg [7:0] y1 = y[perm[(path_idx + 1) % n]];
            reg same_x = (x0 == x1);
            reg same_y = (y0 == y1);
            reg axis_aligned = same_x || same_y;

            // Check perpendicularity
            reg [1:0] curr_dir = same_x ? 1 : 2;
            reg dir_change = (curr_dir != last_dir) && (last_dir != 0);

            // Check segment integrity
            reg segment_ok = 1;
            if (same_x) begin
              for (int i = 0; i < 8; i = i + 1) begin
                if (i != perm[path_idx] && i != perm[(path_idx + 1) % n]) begin
                  if (x[i] == x0 && y[i] > y0 && y[i] < y1) segment_ok = 0;
                  if (x[i] == x0 && y[i] < y0 && y[i] > y1) segment_ok = 0;
                end
              end
            end else begin
              for (int i = 0; i < 8; i = i + 1) begin
                if (i != perm[path_idx] && i != perm[(path_idx + 1) % n]) begin
                  if (y[i] == y0 && x[i] > x0 && x[i] < x1) segment_ok = 0;
                  if (y[i] == y0 && x[i] < x0 && x[i] > x1) segment_ok = 0;
                end
              end
            end

            // Check intersection
            reg [5:0] cell = x0[2:0] + y0[2:0] * 8;
            reg cell_visited = visited[cell];

            // Update state
            if (!axis_aligned || !segment_ok || (cell_visited && path_idx != n - 1)) begin
              valid_path <= 0;
            end
            visited[cell] <= 1;
            last_dir <= curr_dir;
            path_idx <= path_idx + 1;
          end else begin
            state <= CHECK_RESULT;
          end
        end
        CHECK_RESULT: begin
          if (valid_path && (x[perm[0]] == x[perm[n-1]]) && (y[perm[0]] == y[perm[n-1]])) begin
            valid <= 1;
          end
          attempt_counter <= attempt_counter + 1;
          if (attempt_counter == 100) begin // Limit attempts for synthesis
            state <= DONE;
          end else begin
            state <= GENERATE_PERMUTATION;
            perm_idx <= 0;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule