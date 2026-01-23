module wheel_rotations_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] [1:0] wheel0,
  input [7:0] [1:0] wheel1,
  input [7:0] [1:0] wheel2,
  output reg [3:0] result,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PREP_OFFSET1,
    CHECK_OFFSET2,
    NEXT_OFFSET2,
    NEXT_OFFSET1,
    DONE
  } state_t;

  state_t state;
  reg [2:0] offset1;
  reg [2:0] offset2;
  reg [3:0] min_cost;
  reg [3:0] current_cost;
  reg valid_found;
  reg [2:0] column_check;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      offset1 <= 0;
      offset2 <= 0;
      min_cost <= 15;
      current_cost <= 0;
      valid_found <= 0;
      column_check <= 0;
      result <= 0;
      done <= 0;
      valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREP_OFFSET1;
            offset1 <= 0;
            offset2 <= 0;
            min_cost <= 15;
            valid_found <= 0;
            done <= 0;
            valid <= 0;
          end
        end
        PREP_OFFSET1: begin
          state <= CHECK_OFFSET2;
          offset2 <= 0;
        end
        CHECK_OFFSET2: begin
          // Check all columns for current offsets
          column_check <= 0;
          state <= NEXT_OFFSET2;
        end
        NEXT_OFFSET2: begin
          if (column_check == 7) begin
            // All columns checked
            if (valid_found == 0 && current_cost < min_cost) begin
              min_cost <= current_cost;
              valid_found <= 1;
            end
            if (offset2 == 7) begin
              state <= NEXT_OFFSET1;
            end else begin
              offset2 <= offset2 + 1;
              state <= CHECK_OFFSET2;
            end
          end else begin
            column_check <= column_check + 1;
            state <= CHECK_OFFSET2;
          end
        end
        NEXT_OFFSET1: begin
          if (offset1 == 7) begin
            state <= DONE;
          end else begin
            offset1 <= offset1 + 1;
            offset2 <= 0;
            state <= CHECK_OFFSET2;
          end
        end
        DONE: begin
          if (valid_found) begin
            result <= min_cost;
            valid <= 1;
          end else begin
            result <= 15;
            valid <= 0;
          end
          done <= 1;
        end
      endcase
    end
  end

  // Column checking logic
  always @(*) begin
    if (state == CHECK_OFFSET2) begin
      // Get current column indices
      integer i = column_check;
      integer idx1 = (i + offset1) % 8;
      integer idx2 = (i + offset2) % 8;

      // Check if all three letters are distinct
      reg [1:0] w0 = wheel0[i];
      reg [1:0] w1 = wheel1[idx1];
      reg [1:0] w2 = wheel2[idx2];

      // Check distinctness
      reg distinct = 1;
      if (w0 == w1 || w0 == w2 || w1 == w2) begin
        distinct = 0;
      end

      // Update current cost
      current_cost = offset1 + offset2;

      // If not distinct, set cost to max to invalidate
      if (!distinct) begin
        current_cost = 15;
      end
    end
  end

endmodule