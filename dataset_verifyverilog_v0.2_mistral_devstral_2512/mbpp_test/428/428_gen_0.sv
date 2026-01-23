module shell_sort_8 (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:7],
  output reg [7:0] result [0:7],
  output reg done
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    GAP4,
    GAP2,
    GAP1,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] array [0:7];
  reg [2:0] i_reg, j_reg;
  reg [7:0] current_item;
  reg [1:0] gap_reg;
  reg [3:0] cycle_count;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      cycle_count <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = GAP4;
      end
      GAP4: begin
        if (cycle_count == 3) next_state = GAP2;
      end
      GAP2: begin
        if (cycle_count == 7) next_state = GAP1;
      end
      GAP1: begin
        if (cycle_count == 11) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Data processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      for (int k = 0; k < 8; k++) begin
        array[k] <= 0;
        result[k] <= 0;
      end
      i_reg <= 0;
      j_reg <= 0;
      current_item <= 0;
      gap_reg <= 0;
      cycle_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Capture input data
            for (int k = 0; k < 8; k++) begin
              array[k] <= data_in[k];
            end
            i_reg <= 0;
            j_reg <= 0;
            current_item <= 0;
            gap_reg <= 4;
            cycle_count <= 0;
          end
        end
        GAP4: begin
          if (cycle_count < 4) begin
            // Process elements for gap=4
            if (cycle_count == 0) begin
              i_reg <= 4;
              current_item <= array[4];
              j_reg <= 0;
            end else if (cycle_count == 1) begin
              i_reg <= 5;
              current_item <= array[5];
              j_reg <= 1;
            end else if (cycle_count == 2) begin
              i_reg <= 6;
              current_item <= array[6];
              j_reg <= 2;
            end else if (cycle_count == 3) begin
              i_reg <= 7;
              current_item <= array[7];
              j_reg <= 3;
            end
            
            // Insertion sort logic for gap=4
            if (j_reg >= 0 && array[j_reg] > current_item) begin
              array[j_reg + 4] <= array[j_reg];
              j_reg <= j_reg - 1;
            end else begin
              array[j_reg + 4] <= current_item;
            end
            
            cycle_count <= cycle_count + 1;
          end
        end
        GAP2: begin
          if (cycle_count < 11) begin
            // Process elements for gap=2
            if (cycle_count == 4) begin
              i_reg <= 2;
              current_item <= array[2];
              j_reg <= 0;
            end else if (cycle_count == 5) begin
              i_reg <= 3;
              current_item <= array[3];
              j_reg <= 1;
            end else if (cycle_count == 6) begin
              i_reg <= 4;
              current_item <= array[4];
              j_reg <= 2;
            end else if (cycle_count == 7) begin
              i_reg <= 5;
              current_item <= array[5];
              j_reg <= 3;
            end else if (cycle_count == 8) begin
              i_reg <= 6;
              current_item <= array[6];
              j_reg <= 4;
            end else if (cycle_count == 9) begin
              i_reg <= 7;
              current_item <= array[7];
              j_reg <= 5;
            end else if (cycle_count == 10) begin
              // Additional cycle for final placement
              i_reg <= 7;
              current_item <= array[7];
              j_reg <= 5;
            end
            
            // Insertion sort logic for gap=2
            if (j_reg >= 0 && array[j_reg] > current_item) begin
              array[j_reg + 2] <= array[j_reg];
              j_reg <= j_reg - 1;
            end else begin
              array[j_reg + 2] <= current_item;
            end
            
            cycle_count <= cycle_count + 1;
          end
        end
        GAP1: begin
          if (cycle_count < 12) begin
            // Process elements for gap=1
            if (cycle_count == 11) begin
              i_reg <= 1;
              current_item <= array[1];
              j_reg <= 0;
            end
            
            // Insertion sort logic for gap=1
            if (j_reg >= 0 && array[j_reg] > current_item) begin
              array[j_reg + 1] <= array[j_reg];
              j_reg <= j_reg - 1;
            end else begin
              array[j_reg + 1] <= current_item;
            end
            
            cycle_count <= cycle_count + 1;
          end
        end
        DONE: begin
          done <= 1;
          // Output the sorted array
          for (int k = 0; k < 8; k++) begin
            result[k] <= array[k];
          end
        end
      endcase
    end
  end

endmodule