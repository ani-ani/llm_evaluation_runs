module frog_jumps (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_plants,
  input [3:0] num_jumps,
  input [7:0] init_x, init_y,
  input [7:0] plant_x [0:7], plant_y [0:7],
  input [7:0] jump_dir,
  output reg [7:0] final_x, final_y,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    READ_DIR,
    SEARCH_PLANTS,
    UPDATE_POS,
    DONE
  } state_t;

  state_t state;
  reg [7:0] current_x, current_y;
  reg [7:0] active_plants; // 1=active, 0=inactive
  reg [3:0] jump_idx; // Current jump index (0-15)
  reg [2:0] plant_idx; // Current plant index (0-7)
  reg [7:0] min_p; // Minimum P found
  reg [2:0] min_plant_idx; // Plant index with min P
  reg found; // Found a valid plant

  // Direction decoding
  reg [1:0] dir; // Current direction (00=A, 01=B, 10=C, 11=D)
  reg [7:0] dx, dy; // Delta x and y
  reg [7:0] p; // P value

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_x <= 0;
      current_y <= 0;
      active_plants <= 0;
      jump_idx <= 0;
      plant_idx <= 0;
      min_p <= 0;
      min_plant_idx <= 0;
      found <= 0;
      dir <= 0;
      dx <= 0;
      dy <= 0;
      p <= 0;
      done <= 0;
      valid <= 0;
      final_x <= 0;
      final_y <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize active plants (all plants are active initially)
            active_plants <= (1 << num_plants) - 1;
            current_x <= init_x;
            current_y <= init_y;
            jump_idx <= 0;
            state <= READ_DIR;
          end
        end

        READ_DIR: begin
          // Extract current direction
          dir <= jump_dir[(jump_idx * 2) +: 2];
          min_p <= 8'hFF; // Initialize to max value
          found <= 0;
          plant_idx <= 0;
          state <= SEARCH_PLANTS;
        end

        SEARCH_PLANTS: begin
          if (plant_idx < num_plants) begin
            // Check if plant is active
            if (active_plants[plant_idx]) begin
              // Calculate dx and dy
              dx <= plant_x[plant_idx] - current_x;
              dy <= plant_y[plant_idx] - current_y;

              // Calculate P = max(|dx|, |dy|)
              p <= (dx[7] ? -dx : dx) > (dy[7] ? -dy : dy) ? (dx[7] ? -dx : dx) : (dy[7] ? -dy : dy);

              // Check direction validity
              case (dir)
                2'b00: begin // A: (x+P, y+P)
                  if (dx == dy && dx > 0 && p < min_p) begin
                    min_p <= p;
                    min_plant_idx <= plant_idx;
                    found <= 1;
                  end
                end
                2'b01: begin // B: (x+P, y-P)
                  if (dx == -dy && dx > 0 && p < min_p) begin
                    min_p <= p;
                    min_plant_idx <= plant_idx;
                    found <= 1;
                  end
                end
                2'b10: begin // C: (x-P, y+P)
                  if (dx == dy && dx < 0 && p < min_p) begin
                    min_p <= p;
                    min_plant_idx <= plant_idx;
                    found <= 1;
                  end
                end
                2'b11: begin // D: (x-P, y-P)
                  if (dx == -dy && dx < 0 && p < min_p) begin
                    min_p <= p;
                    min_plant_idx <= plant_idx;
                    found <= 1;
                  end
                end
              endcase
            end
            plant_idx <= plant_idx + 1;
          end else begin
            state <= UPDATE_POS;
          end
        end

        UPDATE_POS: begin
          if (found) begin
            // Move to the new plant and mark the old plant as inactive
            current_x <= plant_x[min_plant_idx];
            current_y <= plant_y[min_plant_idx];
            active_plants[min_plant_idx] <= 0;
          end

          // Move to next jump
          jump_idx <= jump_idx + 1;

          if (jump_idx == num_jumps) begin
            state <= DONE;
          end else begin
            state <= READ_DIR;
          end
        end

        DONE: begin
          final_x <= current_x;
          final_y <= current_y;
          done <= 1;
          valid <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule