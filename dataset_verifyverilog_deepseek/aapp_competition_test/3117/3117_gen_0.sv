module longest_repeating_substring(
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] str,
  input [3:0] length,
  output reg [3:0] max_len,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, CHECK_LEN, NEXT_LEN, DONE} state_t;
  state_t state, next_state;
  reg [3:0] current_len;
  reg [8:0] counter;
  wire [3:0] K = (current_len <= length) ? (length - current_len + 1) : 4'd0;
  wire any_match;
  wire [119:0] pairwise_match;

  // Generate pairwise_match array
  generate
    genvar i, j;
    integer idx = 0;
    for (i = 0; i < 16; i = i + 1) begin : gen_i
      for (j = i + 1; j < 16; j = j + 1) begin : gen_j
        wire [14:0] eq_bytes;
        for (genvar k = 0; k < 15; k = k + 1) begin : gen_k
          assign eq_bytes[k] = (k < current_len) ? (str[i + k] == str[j + k]) : 1'b1;
        end
        localparam integer cur_idx = idx;
        assign pairwise_match[cur_idx] = (i < K && j < K) ? &eq_bytes : 1'b0;
        idx = idx + 1;
      end
    end
  endgenerate

  assign any_match = |pairwise_match;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 9'd0;
      max_len <= 4'd0;
      done <= 1'b0;
      current_len <= 4'd0;
    end else begin
      state <= next_state;
      counter <= (state != IDLE && state != DONE) ? counter + 1'd1 :
                 (next_state == INIT) ? 9'd0 : counter;

      case (state)
        INIT: current_len <= (length > 4'd1) ? (length - 4'd1) : 4'd0;
        NEXT_LEN: current_len <= current_len - 4'd1;
        default: current_len <= current_len;
      endcase

      case (state)
        CHECK_LEN:
          if (counter == 9'd255 || (K >= 4'd2 && any_match))
            {max_len, done} <= (K >= 4'd2 && any_match) ? {current_len, 1'b1} : {4'd0, 1'b1};
        NEXT_LEN:
          if (current_len == 4'd1) {max_len, done} <= {4'd0, 1'b1};
        INIT:
          if (length <= 4'd1) {max_len, done} <= {4'd0, 1'b1};
        DONE: done <= !start;
        default: {max_len, done} <= {4'd0, 1'b0};
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = (length <= 4'd1) ? DONE : CHECK_LEN;
      CHECK_LEN: next_state = (counter == 9'd255 || (K >=4'd2 && any_match)) ? DONE : NEXT_LEN;
      NEXT_LEN: next_state = (current_len > 4'd1) ? CHECK_LEN : DONE;
      DONE: next_state = start ? INIT : DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule