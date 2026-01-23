module dog_walk_min_distance (
  input clk,
  input rst_n,
  input start,
  input [4:0] shadow_count,
  input [4:0] lydia_count,
  input [7:0] shadow_x [0:15],
  input [7:0] shadow_y [0:15],
  input [7:0] lydia_x [0:15],
  input [7:0] lydia_y [0:15],
  output reg done,
  output reg [15:0] min_dist_sq
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_PATHS,
    COMPUTE_SEGMENTS,
    FIND_MIN_DIST,
    DONE
  } state_t;

  state_t state;
  reg [3:0] shadow_idx;
  reg [3:0] lydia_idx;
  reg [3:0] segment_idx;
  reg [3:0] time_idx;

  // Segment storage (dx, dy, length_sq, cumulative_time)
  reg [7:0] shadow_dx [0:15];
  reg [7:0] shadow_dy [0:15];
  reg [15:0] shadow_length_sq [0:15];
  reg [15:0] shadow_cumulative_time [0:16];

  reg [7:0] lydia_dx [0:15];
  reg [7:0] lydia_dy [0:15];
  reg [15:0] lydia_length_sq [0:15];
  reg [15:0] lydia_cumulative_time [0:16];

  // Timeline storage
  reg [15:0] timeline [0:31];
  reg [15:0] current_min_dist_sq;

  // Temporary registers for calculations
  reg [15:0] temp_x1, temp_y1, temp_x2, temp_y2;
  reg [15:0] temp_dist_sq;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      shadow_idx <= 0;
      lydia_idx <= 0;
      segment_idx <= 0;
      time_idx <= 0;
      done <= 0;
      min_dist_sq <= 16'hFFFF;
      current_min_dist_sq <= 16'hFFFF;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_PATHS;
            shadow_idx <= 0;
            lydia_idx <= 0;
            segment_idx <= 0;
            time_idx <= 0;
            done <= 0;
            current_min_dist_sq <= 16'hFFFF;
          end
        end

        LOAD_PATHS: begin
          // Load all points (simplified - in real implementation would need to handle loading)
          state <= COMPUTE_SEGMENTS;
        end

        COMPUTE_SEGMENTS: begin
          // Compute segments for Shadow
          if (segment_idx < shadow_count - 1) begin
            shadow_dx[segment_idx] <= shadow_x[segment_idx+1] - shadow_x[segment_idx];
            shadow_dy[segment_idx] <= shadow_y[segment_idx+1] - shadow_y[segment_idx];
            shadow_length_sq[segment_idx] <= ($signed(shadow_dx[segment_idx]) * $signed(shadow_dx[segment_idx])) +
                                           ($signed(shadow_dy[segment_idx]) * $signed(shadow_dy[segment_idx]));
            segment_idx <= segment_idx + 1;
          end else if (segment_idx == shadow_count - 1) begin
            // Compute cumulative times for Shadow
            shadow_cumulative_time[0] <= 0;
            for (int i = 0; i < shadow_count - 1; i = i + 1) begin
              shadow_cumulative_time[i+1] <= shadow_cumulative_time[i] + shadow_length_sq[i];
            end
            segment_idx <= 0;
          end else if (segment_idx < lydia_count - 1) begin
            // Compute segments for Lydia
            lydia_dx[segment_idx] <= lydia_x[segment_idx+1] - lydia_x[segment_idx];
            lydia_dy[segment_idx] <= lydia_y[segment_idx+1] - lydia_y[segment_idx];
            lydia_length_sq[segment_idx] <= ($signed(lydia_dx[segment_idx]) * $signed(lydia_dx[segment_idx])) +
                                           ($signed(lydia_dy[segment_idx]) * $signed(lydia_dy[segment_idx]));
            segment_idx <= segment_idx + 1;
          end else if (segment_idx == lydia_count - 1) begin
            // Compute cumulative times for Lydia
            lydia_cumulative_time[0] <= 0;
            for (int i = 0; i < lydia_count - 1; i = i + 1) begin
              lydia_cumulative_time[i+1] <= lydia_cumulative_time[i] + lydia_length_sq[i];
            end
            segment_idx <= 0;
            state <= FIND_MIN_DIST;
          end
        end

        FIND_MIN_DIST: begin
          // Check all segment endpoints and midpoints
          if (time_idx < (shadow_count + lydia_count - 2)) begin
            // Calculate positions at current time point
            // Simplified: Check all combinations of segment endpoints
            // In real implementation, would need proper time interpolation
            temp_x1 <= shadow_x[segment_idx] << 8;
            temp_y1 <= shadow_y[segment_idx] << 8;
            temp_x2 <= lydia_x[segment_idx] << 8;
            temp_y2 <= lydia_y[segment_idx] << 8;

            temp_dist_sq <= ($signed(temp_x1 - temp_x2) * $signed(temp_x1 - temp_x2)) >> 8 +
                           ($signed(temp_y1 - temp_y2) * $signed(temp_y1 - temp_y2)) >> 8;

            if (temp_dist_sq < current_min_dist_sq) begin
              current_min_dist_sq <= temp_dist_sq;
            end

            time_idx <= time_idx + 1;
            segment_idx <= segment_idx + 1;
          end else begin
            min_dist_sq <= current_min_dist_sq;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule