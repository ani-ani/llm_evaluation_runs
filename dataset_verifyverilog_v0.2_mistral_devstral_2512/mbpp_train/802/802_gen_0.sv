module rotation_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] arr [0:15],
  output reg [3:0] rotations,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPARE,
    UPDATE_LEFT,
    UPDATE_RIGHT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] left, right, mid;
  reg [3:0] counter;

  // Initialize state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      rotations <= 0;
      done <= 0;
      left <= 0;
      right <= 0;
      mid <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          if (n == 0) begin
            rotations = 0;
            next_state = DONE;
          end else if (arr[0] <= arr[n-1]) begin
            rotations = 0;
            next_state = DONE;
          end else begin
            left = 0;
            right = n - 1;
            counter = 0;
            next_state = COMPARE;
          end
        end
      end

      COMPARE: begin
        mid = (left + right) / 2;
        if (arr[mid] > arr[right]) begin
          next_state = UPDATE_LEFT;
        end else begin
          next_state = UPDATE_RIGHT;
        end
      end

      UPDATE_LEFT: begin
        left = mid + 1;
        counter = counter + 1;
        if (left > right) begin
          rotations = left;
          next_state = DONE;
        end else begin
          next_state = COMPARE;
        end
      end

      UPDATE_RIGHT: begin
        right = mid;
        counter = counter + 1;
        if (left > right) begin
          rotations = left;
          next_state = DONE;
        end else begin
          next_state = COMPARE;
        end
      end

      DONE: begin
        done = 1;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule