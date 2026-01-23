module monotonic_check (
  input clk,
  input rst_n,
  input start,
  input [2:0] length,
  input [7:0] data [0:7],
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECKING,
    DONE
  } state_t;

  state_t state;
  reg [2:0] index;
  reg [1:0] direction; // 0=unknown, 1=increasing, 2=decreasing
  reg [3:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      direction <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECKING;
            index <= 0;
            direction <= 0;
            cycle_count <= 0;
            done <= 0;
            // Handle edge cases: length 0 or 1
            if (length <= 1) begin
              result <= 1;
              done <= 1;
              state <= DONE;
            end
          end
        end
        CHECKING: begin
          cycle_count <= cycle_count + 1;
          if (cycle_count >= 10) begin
            state <= DONE;
            done <= 1;
          end else if (index < length - 1) begin
            // Compare current pair
            if (data[index] > data[index + 1]) begin
              if (direction == 0) begin
                direction <= 2; // decreasing
              end else if (direction == 1) begin
                result <= 0; // violation
              end
            end else if (data[index] < data[index + 1]) begin
              if (direction == 0) begin
                direction <= 1; // increasing
              end else if (direction == 2) begin
                result <= 0; // violation
              end
            end
            // Move to next pair
            index <= index + 1;
          end else begin
            // All pairs checked without violation
            result <= 1;
            state <= DONE;
            done <= 1;
          end
        end
        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule