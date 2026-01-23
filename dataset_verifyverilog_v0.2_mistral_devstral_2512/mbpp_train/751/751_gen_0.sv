module check_min_heap (
  input clk,
  input rst_n,
  input start,
  input [7:0][15:0] arr,
  output reg is_heap,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    CHECK_0,
    CHECK_1,
    CHECK_2,
    CHECK_3,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] check_index;
  reg [15:0] parent, left_child, right_child;
  reg check_passed;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      is_heap <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_0;
          is_heap = 1'b1;
          done = 1'b0;
        end
      end
      CHECK_0: begin
        parent = arr[0];
        left_child = arr[1];
        right_child = arr[2];
        check_passed = (parent <= left_child) && (parent <= right_child);
        is_heap = is_heap && check_passed;
        next_state = CHECK_1;
      end
      CHECK_1: begin
        parent = arr[1];
        left_child = arr[3];
        right_child = arr[4];
        check_passed = (parent <= left_child) && (parent <= right_child);
        is_heap = is_heap && check_passed;
        next_state = CHECK_2;
      end
      CHECK_2: begin
        parent = arr[2];
        left_child = arr[5];
        right_child = arr[6];
        check_passed = (parent <= left_child) && (parent <= right_child);
        is_heap = is_heap && check_passed;
        next_state = CHECK_3;
      end
      CHECK_3: begin
        parent = arr[3];
        left_child = arr[7];
        check_passed = (parent <= left_child);
        is_heap = is_heap && check_passed;
        next_state = DONE;
      end
      DONE: begin
        done = 1'b1;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule