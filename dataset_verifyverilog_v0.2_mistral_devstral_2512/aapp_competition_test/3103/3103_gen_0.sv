module ship_routes (
  input clk,
  input rst_n,
  input start,
  input [3:0] grid_row_idx,
  input [7:0] grid_char,
  output reg [23:0] result,
  output reg valid,
  output reg done,
  output reg [3:0] load_row
);

  // Constants
  localparam IDLE = 3'b000;
  localparam LOAD_ROW = 3'b001;
  localparam CALCULATE = 3'b010;
  localparam DONE = 3'b100;
  localparam MODULUS = 24'd1000003;
  localparam GRID_SIZE = 4'd16;

  // State machine
  reg [2:0] state = IDLE;
  reg [3:0] current_row = 4'd15;
  reg [3:0] initial_col = 4'd0;
  reg [3:0] col_counter = 4'd0;

  // Grid storage and horizontal mapping
  reg [7:0] grid [0:15][0:15];
  reg [3:0] horizontal_map [0:15][0:15];

  // Reachability and count arrays
  reg [15:0] reachable_current = 16'b0;
  reg [15:0] reachable_next = 16'b0;
  reg [23:0] count_current [0:15];
  reg [23:0] count_next [0:15];

  // Control signals
  reg row_loaded = 1'b0;
  reg calculation_done = 1'b0;

  // Initialize arrays
  integer i, j;
  initial begin
    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 16; j = j + 1) begin
        grid[i][j] = 8'b0;
        horizontal_map[i][j] = 4'b0;
        count_current[j] = 24'b0;
        count_next[j] = 24'b0;
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_row <= 4'd15;
      initial_col <= 4'd0;
      col_counter <= 4'd0;
      row_loaded <= 1'b0;
      calculation_done <= 1'b0;
      reachable_current <= 16'b0;
      reachable_next <= 16'b0;
      for (i = 0; i < 16; i = i + 1) begin
        count_current[i] <= 24'b0;
        count_next[i] <= 24'b0;
      end
      result <= 24'b0;
      valid <= 1'b0;
      done <= 1'b0;
      load_row <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_ROW;
            current_row <= 4'd15;
            initial_col <= 4'd0;
            col_counter <= 4'd0;
            row_loaded <= 1'b0;
            calculation_done <= 1'b0;
            reachable_current <= 16'b0;
            reachable_next <= 16'b0;
            for (i = 0; i < 16; i = i + 1) begin
              count_current[i] <= 24'b0;
              count_next[i] <= 24'b0;
            end
            result <= 24'b0;
            valid <= 1'b0;
            done <= 1'b0;
            load_row <= 4'd15;
          end
        end

        LOAD_ROW: begin
          if (grid_row_idx == current_row) begin
            grid[current_row][col_counter] <= grid_char;
            // Calculate horizontal mapping
            if (grid_char == "<") begin
              if (col_counter > 0 && grid[current_row][col_counter - 1] != "#") begin
                horizontal_map[current_row][col_counter] <= col_counter - 1;
              end else begin
                horizontal_map[current_row][col_counter] <= 4'b1111; // Invalid
              end
            end else if (grid_char == ">") begin
              if (col_counter < 15 && grid[current_row][col_counter + 1] != "#") begin
                horizontal_map[current_row][col_counter] <= col_counter + 1;
              end else begin
                horizontal_map[current_row][col_counter] <= 4'b1111; // Invalid
              end
            end else begin
              horizontal_map[current_row][col_counter] <= 4'b1111; // No horizontal move
            end

            col_counter <= col_counter + 1;
            if (col_counter == 15) begin
              col_counter <= 4'd0;
              row_loaded <= 1'b1;
              state <= CALCULATE;
              load_row <= 4'b0;
            end
          end
        end

        CALCULATE: begin
          if (!calculation_done) begin
            // Initialize reachability for the starting row
            if (current_row == 4'd15) begin
              reachable_current <= 16'b0;
              reachable_current[initial_col] <= 1'b1;
              count_current[initial_col] <= 1;
            end

            // Process horizontal moves
            for (i = 0; i < 16; i = i + 1) begin
              if (reachable_current[i]) begin
                if (horizontal_map[current_row][i] != 4'b1111) begin
                  reachable_current[horizontal_map[current_row][i]] <= 1'b1;
                  count_current[horizontal_map[current_row][i]] <= (count_current[horizontal_map[current_row][i]] + count_current[i]) % MODULUS;
                end
              end
            end

            // Process vertical moves
            if (current_row > 0) begin
              for (i = 0; i < 16; i = i + 1) begin
                if (reachable_current[i] && grid[current_row - 1][i] != "#") begin
                  reachable_next[i] <= 1'b1;
                  count_next[i] <= (count_next[i] + count_current[i]) % MODULUS;
                end
              end
            end

            // Check for target
            if (current_row == 0) begin
              for (i = 0; i < 16; i = i + 1) begin
                if (reachable_current[i] && grid[0][i] == "@") begin
                  result <= count_current[i];
                  valid <= 1'b1;
                  done <= 1'b1;
                  state <= DONE;
                  calculation_done <= 1'b1;
                end
              end
            end

            // Move to next row
            if (current_row > 0 && !calculation_done) begin
              current_row <= current_row - 1;
              reachable_current <= reachable_next;
              for (i = 0; i < 16; i = i + 1) begin
                count_current[i] <= count_next[i];
                count_next[i] <= 24'b0;
              end
              reachable_next <= 16'b0;
              state <= LOAD_ROW;
              load_row <= current_row;
              row_loaded <= 1'b0;
            end else if (current_row == 0) begin
              calculation_done <= 1'b1;
              state <= DONE;
              done <= 1'b1;
            end
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule