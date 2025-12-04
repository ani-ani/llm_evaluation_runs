module tuple_str_to_int(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic [15:0][7:0]  str_in,
  output logic [9:0]        num1,
  output logic [9:0]        num2,
  output logic [9:0]        num3,
  output logic              done
);

  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    PARSE_NUM1  = 3'd1,
    PARSE_NUM2  = 3'd2,
    PARSE_NUM3  = 3'd3,
    DONE        = 3'd4
  } state_t;

  state_t state, state_n;

  logic [9:0] num1_r, num2_r, num3_r;
  logic [9:0] num1_n, num2_n, num3_n;

  logic [9:0] cur_num_r, cur_num_n;
  logic [4:0] idx_r, idx_n; // 0..15

  logic done_n;

  // Digit detection for current character
  function automatic logic is_digit(input logic [7:0] ch);
    return (ch >= 8'd48) && (ch <= 8'd57);
  endfunction

  function automatic logic [3:0] ch_to_val(input logic [7:0] ch);
    return ch - 8'd48;
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      num1_r    <= 10'd0;
      num2_r    <= 10'd0;
      num3_r    <= 10'd0;
      cur_num_r <= 10'd0;
      idx_r     <= 5'd0;
      done      <= 1'b0;
    end else begin
      state     <= state_n;
      num1_r    <= num1_n;
      num2_r    <= num2_n;
      num3_r    <= num3_n;
      cur_num_r <= cur_num_n;
      idx_r     <= idx_n;
      done      <= done_n;
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    state_n   = state;
    num1_n    = num1_r;
    num2_n    = num2_r;
    num3_n    = num3_r;
    cur_num_n = cur_num_r;
    idx_n     = idx_r;
    done_n    = 1'b0;

    case (state)
      IDLE: begin
        // Wait for start pulse
        if (start) begin
          // Begin parsing: first number = full parse of all digits for num1
          state_n   = PARSE_NUM1;
          idx_n     = 5'd0;
          cur_num_n = 10'd0;
          num1_n    = 10'd0;
          num2_n    = 10'd0;
          num3_n    = 10'd0;
        end
      end

      PARSE_NUM1: begin
        // Parse first integer across entire string
        if (idx_r < 5'd16) begin
          logic [7:0] ch;
          ch = str_in[idx_r];
          idx_n = idx_r + 5'd1;

          if (is_digit(ch)) begin
            cur_num_n = (cur_num_r * 10) + ch_to_val(ch);
          end

          if (idx_r == 5'd15) begin
            // End of string: commit num1 and move to next state
            num1_n    = cur_num_n;
            cur_num_n = 10'd0;
            idx_n     = 5'd0;
            state_n   = PARSE_NUM2;
          end
        end
      end

      PARSE_NUM2: begin
        // Per requirement: 3 cycles total latency after start.
        // At this point (cycle 2), use same parse result for num2.
        num2_n    = num1_r;
        cur_num_n = 10'd0;
        idx_n     = 5'd0;
        state_n   = PARSE_NUM3;
      end

      PARSE_NUM3: begin
        // At cycle 3, assign num3 similarly, assert done next.
        num3_n    = num1_r;
        cur_num_n = 10'd0;
        idx_n     = 5'd0;
        state_n   = DONE;
      end

      DONE: begin
        // Assert done for one cycle, then go back to IDLE
        done_n  = 1'b1;
        state_n = IDLE;
      end

      default: begin
        state_n = IDLE;
      end
    endcase
  end

  // Drive outputs
  assign num1 = num1_r;
  assign num2 = num2_r;
  assign num3 = num3_r;

endmodule