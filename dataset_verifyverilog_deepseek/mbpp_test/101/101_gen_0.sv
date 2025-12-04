module kth_element (
  input clk,
  input rst_n,
  input start,
  input [7:0] k,
  input [7:0][7:0] arr,
  output reg [7:0] result,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  LOAD_DATA,
  OUTER_LOOP,
  INNER_LOOP,
  COMPARE,
  SWAP,
  DONE
} state_t;

state_t state, next_state;
reg [7:0] sorted_arr [0:7];
reg [2:0] i, next_i;
reg [2:0] j, next_j;

always_comb begin
  next_state = state;
  next_i = i;
  next_j = j;
  done = (state == IDLE) || (state == DONE);

  case (state)
    IDLE: next_state = start ? LOAD_DATA : IDLE;
    LOAD_DATA: begin
      next_state = OUTER_LOOP;
      next_i = 0;
      next_j = 0;
    end
    OUTER_LOOP: begin
      if (i < 7) begin
        next_state = INNER_LOOP;
        next_j = 0;
      end else begin
        next_state = DONE;
      end
    end
    INNER_LOOP: begin
      if (j < (7 - i)) begin
        next_state = COMPARE;
      end else begin
        next_i = i + 1;
        next_state = OUTER_LOOP;
      end
    end
    COMPARE: begin
      if (sorted_arr[j] > sorted_arr[j+1]) begin
        next_state = SWAP;
      end else begin
        next_j = j + 1;
        next_state = INNER_LOOP;
      end
    end
    SWAP: begin
      next_j = j + 1;
      next_state = INNER_LOOP;
    end
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b1;
    i <= 0;
    j <= 0;
    sorted_arr <= '{default:0};
    result <= 0;
  end else begin
    state <= next_state;
    i <= next_i;
    j <= next_j;

    case (state)
      LOAD_DATA: sorted_arr <= arr;
      SWAP: begin
        sorted_arr[j] <= sorted_arr[j+1];
        sorted_arr[j+1] <= sorted_arr[j];
      end
      DONE: result <= sorted_arr[k-1];
      default: ;
    endcase
  end
end

endmodule