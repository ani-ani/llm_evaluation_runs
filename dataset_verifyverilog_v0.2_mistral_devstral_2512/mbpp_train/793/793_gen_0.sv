module last_position_search (
  input clk,
  input rst_n,
  input start,
  input [7:0] target,
  input [7:0] arr0,
  input [7:0] arr1,
  input [7:0] arr2,
  input [7:0] arr3,
  input [7:0] arr4,
  input [7:0] arr5,
  input [7:0] arr6,
  input [7:0] arr7,
  output reg [2:0] result,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE,
    COMPARE,
    UPDATE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] low, high, mid;
  reg [2:0] res;
  reg [7:0] arr_mid;
  reg [1:0] cmp_result; // 0: equal, 1: greater, 2: less

  // Array selection
  always_comb begin
    case (mid)
      3'd0: arr_mid = arr0;
      3'd1: arr_mid = arr1;
      3'd2: arr_mid = arr2;
      3'd3: arr_mid = arr3;
      3'd4: arr_mid = arr4;
      3'd5: arr_mid = arr5;
      3'd6: arr_mid = arr6;
      3'd7: arr_mid = arr7;
      default: arr_mid = 8'b0;
    endcase
  end

  // Comparison logic
  always_comb begin
    if (arr_mid > target) cmp_result = 2'b01; // greater
    else if (arr_mid < target) cmp_result = 2'b10; // less
    else cmp_result = 2'b00; // equal
  end

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      low <= 3'b000;
      high <= 3'b111;
      mid <= 3'b000;
      res <= 3'b111;
      result <= 3'b111;
      done <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            low <= 3'b000;
            high <= 3'b111;
            res <= 3'b111;
            next_state <= COMPARE;
          end
        end

        COMPARE: begin
          mid <= (low + high) >> 1;
          next_state <= UPDATE;
        end

        UPDATE: begin
          case (cmp_result)
            2'b01: high <= mid - 1; // arr[mid] > target
            2'b10: low <= mid + 1;  // arr[mid] < target
            2'b00: begin           // arr[mid] == target
              res <= mid;
              low <= mid + 1;
            end
          endcase

          if (low > high) begin
            result <= res;
            next_state <= DONE;
          end else begin
            next_state <= COMPARE;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            next_state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule