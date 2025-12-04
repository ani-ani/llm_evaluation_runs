module string_factoring_weight(
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [7:0] chars [15:0],
  output reg [4:0] weight,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE,
    INIT,
    CHECK_LEN,
    INIT_POS,
    CHECK_POS,
    LOAD_SUBSTR,
    COMPARE,
    UPDATE_MIN,
    NEXT_POS_LEN,
    FINAL_WEIGHT,
    DONE_STATE
  } state_t;

  state_t state, next_state;
  reg [3:0] current_len, next_len;
  reg [3:0] current_start, next_start;
  reg [3:0] j, next_j;
  reg [25:0] unique_set, next_unique_set;
  reg [4:0] min_weight, next_min_weight;
  reg [7:0] cycle_count, next_cycle_count;

  function automatic [4:0] popcount;
    input [25:0] vec;
    integer i;
    reg [4:0] count;
    begin
      count = 0;
      for (i=0; i<26; i=i+1)
        count = count + vec[i];
      popcount = count;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_len <= 0;
      current_start <= 0;
      j <= 0;
      unique_set <= 0;
      min_weight <= 16;
      cycle_count <= 0;
      done <= 0;
    end
    else begin
      state <= next_state;
      current_len <= next_len;
      current_start <= next_start;
      j <= next_j;
      unique_set <= next_unique_set;
      min_weight <= next_min_weight;
      cycle_count <= next_cycle_count;
    end
  end

  always @(*) begin
    next_state = state;
    next_len = current_len;
    next_start = current_start;
    next_j = j;
    next_unique_set = unique_set;
    next_min_weight = min_weight;
    next_cycle_count = cycle_count;
    done = 0;
    if (cycle_count <= 255) next_cycle_count = cycle_count + 1;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
          next_cycle_count = 0;
        end
      end

      INIT: begin
        next_len = 1;
        next_min_weight = 16;
        next_state = CHECK_LEN;
      end

      CHECK_LEN: begin
        if (cycle_count >= 255) next_state = FINAL_WEIGHT;
        else if (current_len <= (length >> 1)) next_state = INIT_POS;
        else next_state = FINAL_WEIGHT;
      end

      INIT_POS: begin
        next_start = 0;
        next_state = CHECK_POS;
      end

      CHECK_POS: begin
        if (cycle_count >= 255) next_state = FINAL_WEIGHT;
        else if (current_start <= (length - (current_len << 1))) next_state = LOAD_SUBSTR;
        else begin
          next_len = current_len + 1;
          if (next_len <= (length >> 1)) next_state = CHECK_LEN;
          else next_state = FINAL_WEIGHT;
        end
      end

      LOAD_SUBSTR: begin
        next_j = 0;
        next_unique_set = 0;
        next_state = COMPARE;
      end

      COMPARE: begin
        if (j < current_len) begin
          if ((current_start + j < length) && (current_start + current_len + j < length) &&
              (chars[current_start + j] == chars[current_start + current_len + j])) begin
            next_unique_set = unique_set | (26'b1 << (chars[current_start + j] - 8'h41));
            next_j = j + 1;
          end
          else next_state = NEXT_POS_LEN;
        end
        else next_state = UPDATE_MIN;
      end

      UPDATE_MIN: begin
        begin
          automatic logic [4:0] current_unique = popcount(unique_set);
          if (current_unique < min_weight) next_min_weight = current_unique;
        end
        next_state = NEXT_POS_LEN;
      end

      NEXT_POS_LEN: begin
        next_start = current_start + 1;
        next_state = CHECK_POS;
      end

      FINAL_WEIGHT: begin
        if (min_weight == 16) begin
          automatic reg [25:0] full_unique = 0;
          for (integer i = 0; i < length; i = i+1)
            full_unique = full_unique | (26'b1 << (chars[i] - 8'h41));
          next_min_weight = popcount(full_unique);
        end
        weight = min_weight;
        done = 1'b1;
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        done = 1'b1;
        if (!start) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule