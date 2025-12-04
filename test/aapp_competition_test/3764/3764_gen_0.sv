module jon_snow_rangers(
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [9:0] x,
  input [9:0] a0, a1, a2, a3, a4, a5, a6, a7,
  output reg [9:0] max_strength,
  output reg [9:0] min_strength,
  output reg done
);

  // FSM state encoding
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01,
    FINAL_CALC  = 2'b10,
    DONE_STATE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal storage for strengths
  reg [9:0] s0, s1, s2, s3, s4, s5, s6, s7;
  reg [9:0] next_s0, next_s1, next_s2, next_s3, next_s4, next_s5, next_s6, next_s7;

  // Operation counter
  reg [3:0] op_cnt, next_op_cnt;

  // Latched k and x
  reg [3:0] k_reg, next_k_reg;
  reg [9:0] x_reg, next_x_reg;

  // Sorting network wires (combinational)
  reg [9:0] st0, st1, st2, st3, st4, st5, st6, st7;
  reg [9:0] w0, w1, w2, w3, w4, w5, w6, w7;

  // Compare-and-swap function
  function automatic void cas(input [9:0] a, input [9:0] b, output [9:0] lo, output [9:0] hi);
    begin
      if (a <= b) begin
        lo = a;
        hi = b;
      end else begin
        lo = b;
        hi = a;
      end
    end
  endfunction

  // Combinational: next state and next registers
  always @* begin
    // Default assignments (hold values)
    next_state   = state;
    next_op_cnt  = op_cnt;
    next_k_reg   = k_reg;
    next_x_reg   = x_reg;

    next_s0 = s0;
    next_s1 = s1;
    next_s2 = s2;
    next_s3 = s3;
    next_s4 = s4;
    next_s5 = s5;
    next_s6 = s6;
    next_s7 = s7;

    // Default outputs (registered in seq block)
    // max_strength, min_strength, done handled in sequential block

    case (state)
      IDLE: begin
        // Load inputs when start is asserted
        if (start) begin
          next_k_reg  = k;
          next_x_reg  = x;
          next_s0     = a0;
          next_s1     = a1;
          next_s2     = a2;
          next_s3     = a3;
          next_s4     = a4;
          next_s5     = a5;
          next_s6     = a6;
          next_s7     = a7;
          next_op_cnt = 4'd0;
          next_state  = (k == 4'd0) ? FINAL_CALC : PROCESSING;
        end
      end

      PROCESSING: begin
        // Sorting network on current strengths -> st0..st7
        st0 = s0; st1 = s1; st2 = s2; st3 = s3;
        st4 = s4; st5 = s5; st6 = s6; st7 = s7;

        // Stage 1
        cas(st0, st1, w0, w1);
        cas(st2, st3, w2, w3);
        cas(st4, st5, w4, w5);
        cas(st6, st7, w6, w7);

        st0 = w0; st1 = w1; st2 = w2; st3 = w3;
        st4 = w4; st5 = w5; st6 = w6; st7 = w7;

        // Stage 2
        cas(st0, st2, w0, w2);
        cas(st1, st3, w1, w3);
        cas(st4, st6, w4, w6);
        cas(st5, st7, w5, w7);

        st0 = w0; st1 = w1; st2 = w2; st3 = w3;
        st4 = w4; st5 = w5; st6 = w6; st7 = w7;

        // Stage 3
        cas(st1, st2, w1, w2);
        cas(st5, st6, w5, w6);

        st1 = w1; st2 = w2; st5 = w5; st6 = w6;

        // Stage 4
        cas(st0, st4, w0, w4);
        cas(st1, st5, w1, w5);
        cas(st2, st6, w2, w6);
        cas(st3, st7, w3, w7);

        st0 = w0; st1 = w1; st2 = w2; st3 = w3;
        st4 = w4; st5 = w5; st6 = w6; st7 = w7;

        // Stage 5
        cas(st2, st4, w2, w4);
        cas(st3, st5, w3, w5);

        st2 = w2; st4 = w4; st3 = w3; st5 = w5;

        // Stage 6
        cas(st1, st2, w1, w2);
        cas(st3, st4, w3, w4);
        cas(st5, st6, w5, w6);

        st1 = w1; st2 = w2;
        st3 = w3; st4 = w4;
        st5 = w5; st6 = w6;

        // Apply XOR with x_reg to indices 0,2,4,6
        next_s0 = st0 ^ x_reg;
        next_s1 = st1;
        next_s2 = st2 ^ x_reg;
        next_s3 = st3;
        next_s4 = st4 ^ x_reg;
        next_s5 = st5;
        next_s6 = st6 ^ x_reg;
        next_s7 = st7;

        // Increment operation count and decide next state
        if (op_cnt + 1 >= k_reg) begin
          next_op_cnt = op_cnt + 1;
          next_state  = FINAL_CALC;
        end else begin
          next_op_cnt = op_cnt + 1;
          next_state  = PROCESSING;
        end
      end

      FINAL_CALC: begin
        // Compute min and max from current strengths in next sequential cycle
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        // Stay one cycle with done=1, then go to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      op_cnt       <= 4'd0;
      k_reg        <= 4'd0;
      x_reg        <= 10'd0;
      s0           <= 10'd0;
      s1           <= 10'd0;
      s2           <= 10'd0;
      s3           <= 10'd0;
      s4           <= 10'd0;
      s5           <= 10'd0;
      s6           <= 10'd0;
      s7           <= 10'd0;
      max_strength <= 10'd0;
      min_strength <= 10'd0;
      done         <= 1'b0;
    end else begin
      state   <= next_state;
      op_cnt  <= next_op_cnt;
      k_reg   <= next_k_reg;
      x_reg   <= next_x_reg;

      s0 <= next_s0;
      s1 <= next_s1;
      s2 <= next_s2;
      s3 <= next_s3;
      s4 <= next_s4;
      s5 <= next_s5;
      s6 <= next_s6;
      s7 <= next_s7;

      done <= 1'b0;

      case (next_state)
        FINAL_CALC: begin
          // Calculate min and max from current strengths
          // Unrolled reductions for synthesis friendliness
          reg [9:0] min_tmp0, min_tmp1, min_tmp2, min_tmp3;
          reg [9:0] max_tmp0, max_tmp1, max_tmp2, max_tmp3;

          min_tmp0 = (s0 < s1) ? s0 : s1;
          min_tmp1 = (s2 < s3) ? s2 : s3;
          min_tmp2 = (s4 < s5) ? s4 : s5;
          min_tmp3 = (s6 < s7) ? s6 : s7;

          min_tmp0 = (min_tmp0 < min_tmp1) ? min_tmp0 : min_tmp1;
          min_tmp2 = (min_tmp2 < min_tmp3) ? min_tmp2 : min_tmp3;
          min_tmp0 = (min_tmp0 < min_tmp2) ? min_tmp0 : min_tmp2;

          max_tmp0 = (s0 > s1) ? s0 : s1;
          max_tmp1 = (s2 > s3) ? s2 : s3;
          max_tmp2 = (s4 > s5) ? s4 : s5;
          max_tmp3 = (s6 > s7) ? s6 : s7;

          max_tmp0 = (max_tmp0 > max_tmp1) ? max_tmp0 : max_tmp1;
          max_tmp2 = (max_tmp2 > max_tmp3) ? max_tmp2 : max_tmp3;
          max_tmp0 = (max_tmp0 > max_tmp2) ? max_tmp0 : max_tmp2;

          min_strength <= min_tmp0;
          max_strength <= max_tmp0;
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
          // no additional actions
        end
      endcase
    end
  end

endmodule