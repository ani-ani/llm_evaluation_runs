module building_detector (
  input clk,
  input rst_n,
  input start,
  input [15:0] grid_row_0, grid_row_1, grid_row_2, grid_row_3, grid_row_4, grid_row_5, grid_row_6, grid_row_7,
  input [15:0] grid_row_8, grid_row_9, grid_row_10, grid_row_11, grid_row_12, grid_row_13, grid_row_14, grid_row_15,
  output reg [3:0] building1_row, building1_col, building1_size,
  output reg [3:0] building2_row, building2_col, building2_size,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCAN,
    VERIFY,
    OUTPUT
  } state_t;

  state_t current_state, next_state;

  // Internal registers for scanning
  reg [3:0] row_counter;
  reg [3:0] col_counter;
  reg [3:0] size_counter;
  reg [3:0] building_counter;

  // Temporary storage for potential buildings
  reg [3:0] temp_row, temp_col, temp_size;

  // Grid access helper
  wire [15:0] grid [0:15];
  assign grid[0] = grid_row_0;
  assign grid[1] = grid_row_1;
  assign grid[2] = grid_row_2;
  assign grid[3] = grid_row_3;
  assign grid[4] = grid_row_4;
  assign grid[5] = grid_row_5;
  assign grid[6] = grid_row_6;
  assign grid[7] = grid_row_7;
  assign grid[8] = grid_row_8;
  assign grid[9] = grid_row_9;
  assign grid[10] = grid_row_10;
  assign grid[11] = grid_row_11;
  assign grid[12] = grid_row_12;
  assign grid[13] = grid_row_13;
  assign grid[14] = grid_row_14;
  assign grid[15] = grid_row_15;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      row_counter <= 0;
      col_counter <= 0;
      size_counter <= 0;
      building_counter <= 0;
      temp_row <= 0;
      temp_col <= 0;
      temp_size <= 0;
      building1_row <= 0;
      building1_col <= 0;
      building1_size <= 0;
      building2_row <= 0;
      building2_col <= 0;
      building2_size <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SCAN;
      end
      SCAN: begin
        if (building_counter == 2) begin
          next_state = OUTPUT;
        end else if (row_counter == 15 && col_counter == 15 && size_counter == 15) begin
          next_state = OUTPUT;
        end
      end
      VERIFY: begin
        if (building_counter == 2) begin
          next_state = OUTPUT;
        end else if (row_counter == 15 && col_counter == 15 && size_counter == 15) begin
          next_state = OUTPUT;
        end else begin
          next_state = SCAN;
        end
      end
      OUTPUT: begin
        next_state = IDLE;
      end
    endcase
  end

  // State actions
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        IDLE: begin
          // Wait for start
        end
        SCAN: begin
          // Scan for potential buildings
          if (grid[row_counter][col_counter]) begin
            temp_row = row_counter;
            temp_col = col_counter;
            temp_size = 1;
            next_state = VERIFY;
          end else begin
            // Move to next cell
            if (col_counter == 15) begin
              col_counter <= 0;
              if (row_counter == 15) begin
                row_counter <= 0;
              end else begin
                row_counter <= row_counter + 1;
              end
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        VERIFY: begin
          // Verify square
          reg [3:0] i, j;
          reg valid;
          valid = 1'b1;

          for (i = 0; i < temp_size; i = i + 1) begin
            for (j = 0; j < temp_size; j = j + 1) begin
              if (temp_row + i > 15 || temp_col + j > 15 || !grid[temp_row + i][temp_col + j]) begin
                valid = 1'b0;
              end
            end
          end

          if (valid) begin
            // Store building
            if (building_counter == 0) begin
              building1_row <= temp_row;
              building1_col <= temp_col;
              building1_size <= temp_size;
              building_counter <= building_counter + 1;
            end else if (building_counter == 1) begin
              // Check if this building overlaps with the first one
              reg overlap;
              overlap = 1'b0;

              // Simple overlap check (could be more sophisticated)
              if ((temp_row < building1_row + building1_size) &&
                  (temp_row + temp_size > building1_row) &&
                  (temp_col < building1_col + building1_size) &&
                  (temp_col + temp_size > building1_col)) begin
                overlap = 1'b1;
              end

              if (!overlap) begin
                building2_row <= temp_row;
                building2_col <= temp_col;
                building2_size <= temp_size;
                building_counter <= building_counter + 1;
              end
            end
          end

          // Move to next cell
          if (col_counter == 15) begin
            col_counter <= 0;
            if (row_counter == 15) begin
              row_counter <= 0;
            end else begin
              row_counter <= row_counter + 1;
            end
          end else begin
            col_counter <= col_counter + 1;
          end

          next_state = SCAN;
        end
        OUTPUT: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule