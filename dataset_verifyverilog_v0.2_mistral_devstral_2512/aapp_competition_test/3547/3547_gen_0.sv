module rect_area_calculator (
  input clk,
  input rst_n,
  input start,
  input [31:0] x1,
  input [31:0] y1,
  input [31:0] x2,
  input [31:0] y2,
  input [1:0] rect_idx,
  input rect_valid,
  output reg [31:0] total_area,
  output reg done,
  output reg [1:0] state_out
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] LOADING = 2'b01;
  localparam [1:0] COMPUTING = 2'b10;
  localparam [1:0] DONE = 2'b11;

  // Rectangle storage (4 rectangles max)
  reg [31:0] rect_x1 [0:3];
  reg [31:0] rect_y1 [0:3];
  reg [31:0] rect_x2 [0:3];
  reg [31:0] rect_y2 [0:3];
  reg [3:0] rect_count = 0;

  // Coordinate storage (max 8 unique points)
  reg [31:0] x_coords [0:7];
  reg [31:0] y_coords [0:7];
  reg [3:0] x_count = 0;
  reg [3:0] y_count = 0;

  // Sorting variables
  reg [3:0] sort_idx = 0;
  reg [3:0] sort_jdx = 0;
  reg [31:0] sort_temp;
  reg sort_x_done = 0;
  reg sort_y_done = 0;

  // Computing variables
  reg [3:0] strip_idx = 0;
  reg [3:0] y_idx = 0;
  reg [31:0] current_x, next_x;
  reg [31:0] strip_width;
  reg [31:0] y_segments [0:7];
  reg [31:0] y_coverage;
  reg [31:0] area_accum = 0;
  reg [5:0] compute_cycle = 0;

  // State register
  reg [1:0] state = IDLE;

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      total_area <= 0;
      rect_count <= 0;
      x_count <= 0;
      y_count <= 0;
      sort_idx <= 0;
      sort_jdx <= 0;
      sort_x_done <= 0;
      sort_y_done <= 0;
      strip_idx <= 0;
      y_idx <= 0;
      area_accum <= 0;
      compute_cycle <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOADING;
            rect_count <= 0;
            x_count <= 0;
            y_count <= 0;
            done <= 0;
          end
        end

        LOADING: begin
          if (rect_valid) begin
            // Store rectangle
            rect_x1[rect_idx] <= x1;
            rect_y1[rect_idx] <= y1;
            rect_x2[rect_idx] <= x2;
            rect_y2[rect_idx] <= y2;
            rect_count <= rect_count + 1;

            // Add coordinates to lists
            if (x_count < 8) begin
              x_coords[x_count] <= x1;
              x_count <= x_count + 1;
            end
            if (x_count < 8) begin
              x_coords[x_count] <= x2;
              x_count <= x_count + 1;
            end
            if (y_count < 8) begin
              y_coords[y_count] <= y1;
              y_count <= y_count + 1;
            end
            if (y_count < 8) begin
              y_coords[y_count] <= y2;
              y_count <= y_count + 1;
            end

            // Check if all rectangles loaded
            if (rect_count == 3) begin
              state <= COMPUTING;
              sort_idx <= 0;
              sort_jdx <= 0;
              sort_x_done <= 0;
              sort_y_done <= 0;
              strip_idx <= 0;
              y_idx <= 0;
              area_accum <= 0;
              compute_cycle <= 0;
            end
          end
        end

        COMPUTING: begin
          if (compute_cycle < 64) begin
            compute_cycle <= compute_cycle + 1;

            // Sorting phase
            if (!sort_x_done) begin
              if (sort_idx < x_count - 1) begin
                if (sort_jdx < x_count - sort_idx - 1) begin
                  if (x_coords[sort_jdx] > x_coords[sort_jdx + 1]) begin
                    sort_temp <= x_coords[sort_jdx];
                    x_coords[sort_jdx] <= x_coords[sort_jdx + 1];
                    x_coords[sort_jdx + 1] <= sort_temp;
                  end
                  sort_jdx <= sort_jdx + 1;
                end else begin
                  sort_jdx <= 0;
                  sort_idx <= sort_idx + 1;
                end
              end else begin
                sort_x_done <= 1;
                sort_idx <= 0;
                sort_jdx <= 0;
              end
            end else if (!sort_y_done) begin
              if (sort_idx < y_count - 1) begin
                if (sort_jdx < y_count - sort_idx - 1) begin
                  if (y_coords[sort_jdx] > y_coords[sort_jdx + 1]) begin
                    sort_temp <= y_coords[sort_jdx];
                    y_coords[sort_jdx] <= y_coords[sort_jdx + 1];
                    y_coords[sort_jdx + 1] <= sort_temp;
                  end
                  sort_jdx <= sort_jdx + 1;
                end else begin
                  sort_jdx <= 0;
                  sort_idx <= sort_idx + 1;
                end
              end else begin
                sort_y_done <= 1;
                strip_idx <= 0;
              end
            end
            // Area calculation phase
            else begin
              if (strip_idx < x_count - 1) begin
                current_x <= x_coords[strip_idx];
                next_x <= x_coords[strip_idx + 1];
                strip_width <= next_x - current_x;

                // Calculate vertical coverage
                y_coverage <= 0;
                for (y_idx = 0; y_idx < y_count - 1; y_idx = y_idx + 1) begin
                  // Check if this y-segment is covered by any rectangle
                  reg covered = 0;
                  for (integer r = 0; r < rect_count; r = r + 1) begin
                    if ((y_coords[y_idx] >= rect_y1[r]) && 
                        (y_coords[y_idx + 1] <= rect_y2[r]) &&
                        (current_x >= rect_x1[r]) &&
                        (next_x <= rect_x2[r])) begin
                      covered = 1;
                    end
                  end

                  if (covered) begin
                    y_coverage <= y_coverage + (y_coords[y_idx + 1] - y_coords[y_idx]);
                  end
                end

                // Accumulate area
                area_accum <= area_accum + (strip_width * y_coverage);
                strip_idx <= strip_idx + 1;
              end else if (compute_cycle == 63) begin
                state <= DONE;
                total_area <= area_accum;
                done <= 1;
              end
            end
          end
        end

        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // State output
  always @(posedge clk) begin
    state_out <= state;
  end

endmodule