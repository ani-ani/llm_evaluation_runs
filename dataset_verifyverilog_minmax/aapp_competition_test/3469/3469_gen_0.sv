module gon_win_prob (
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Starts computation when high
  input [3:0] g, // Gon's pattern (0=H,1=T per bit)
  input [3:0] k, // Killua's pattern (0=H,1=T per bit)
  input [7:0] p, // Head probability Q8.8 fixed-point (0.5 -> 0x0080)
  output reg [23:0] prob_out, // Gon's win probability in Q16.8 format
  output reg done // High when computation completes
);

  // Fixed-point constants
  localparam Q = 8;                 // Fraction bits for Q8.8 input
  localparam OUT_Q = 8;             // Fraction bits for Q16.8 output
  localparam ACC_W = 24;            // 16.8 accumulator width
  localparam ACC_INT_W = ACC_W - OUT_Q; // Integer bits in accumulator (16)

  // State machine
  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
  state_t state, next_state;

  // Per-cycle state
  reg [ACC_W-1:0] prob_acc;     // Accumulator for Gon win prob (Q16.8)
  reg [2:0] match_g;            // Current match length for Gon (0..4)
  reg [2:0] match_k;            // Current match length for Killua (0..4)
  reg [3:0] step_cnt;           // Flip counter (0..15), we finish at step_cnt == 15

  // Next-cycle variables
  reg [ACC_W-1:0] prob_acc_next;
  reg [2:0] match_g_next, match_k_next;
  reg [3:0] step_cnt_next;
  reg done_next;

  // Start edge detector to qualify DONE->RUN transitions
  reg start_d1;
  wire start_edge = start && !start_d1;

  // Arithmetic: compute (p_head * state_prob) with Q16.8 precision
  function [ACC_W-1:0] mul_q8_8_to_q16_8;
    input [7:0] a; // Q8.8
    input [23:0] b; // Q16.8
    // Multiply: 8 + 24 = 32 bits; take upper 24 bits to normalize to Q16.8
    mul_q8_8_to_q16_8 = $signed({1'b0, a}) * $signed(b) >> Q;
  endfunction

  always_comb begin
    // Defaults (prevent latches)
    prob_acc_next = prob_acc;
    match_g_next  = match_g;
    match_k_next  = match_k;
    step_cnt_next = step_cnt;
    done_next     = 1'b0;
    next_state    = state;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for 16-cycle simulation
          prob_acc_next = '0;
          match_g_next  = '0;
          match_k_next  = '0;
          step_cnt_next = '0;
          next_state    = RUN;
        end
      end

      RUN: begin
        // Multiply current path probability by p_head and p_tail (Q16.8)
        prob_acc_next = prob_acc;
        match_g_next  = match_g;
        match_k_next  = match_k;
        step_cnt_next = step_cnt + 1;

        // Heads branch
        begin
          reg [2:0] ng, nk;
          reg [ACC_W-1:0] inc;
          ng = (match_g == 3'b100) ? 3'b100 : ((g[match_g] == 1'b0) ? (match_g + 1) : 3'b1);
          nk = (match_k == 3'b100) ? 3'b100 : ((k[match_k] == 1'b0) ? (match_k + 1) : 3'b1);
          inc = mul_q8_8_to_q16_8(p, 24'h1_0000); // p_head * 1.0 in Q16.8
          if (ng == 3'b100 && nk != 3'b100) begin
            // Gon completes first on heads
            prob_acc_next = prob_acc + mul_q8_8_to_q16_8(p, 24'h1_0000);
          end else if (ng == 3'b100 && nk == 3'b100) begin
            // Draw on heads; no accumulation for Gon
            prob_acc_next = prob_acc + mul_q8_8_to_q16_8(p, 24'h1_0000);
          end
          // Update match state for heads (even if already complete, clamp to 4)
          match_g_next  = ng;
          match_k_next  = nk;
        end

        // Tails branch (continuation only if not terminal on heads)
        if (!(match_g == 3'b100 && match_k != 3'b100)) begin
          reg [2:0] ng_t, nk_t;
          ng_t = (match_g == 3'b100) ? 3'b100 : ((g[match_g] == 1'b1) ? (match_g + 1) : 3'b1);
          nk_t = (match_k == 3'b100) ? 3'b100 : ((k[match_k] == 1'b1) ? (match_k + 1) : 3'b1);
          if (ng_t == 3'b100 && nk_t != 3'b100) begin
            // Gon completes first on tails
            prob_acc_next = prob_acc_next + mul_q8_8_to_q16_8({8{~p[7]}} ^ 8'hFF, 24'h1_0000); // p_tail = ~p + 1 (mod 256)
          end else if (ng_t == 3'b100 && nk_t == 3'b100) begin
            // Draw on tails; no accumulation for Gon
            prob_acc_next = prob_acc_next + mul_q8_8_to_q16_8({8{~p[7]}} ^ 8'hFF, 24'h1_0000);
          end
          // Update match state for tails
          match_g_next  = ng_t;
          match_k_next  = nk_t;
        end

        // After 16 flips (step 15 -> step 16), assert done for 1 cycle
        if (step_cnt == 4'd15) begin
          next_state = DONE;
          done_next  = 1'b1;
        end
      end

      DONE: begin
        // Keep result stable and done high for exactly 1 cycle after RUN
        next_state = IDLE;
        done_next  = 1'b0;
      end
    endcase
  end

  // Clock and reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      prob_acc  <= '0;
      match_g   <= '0;
      match_k   <= '0;
      step_cnt  <= '0;
      done      <= 1'b0;
      start_d1  <= 1'b0;
    end else begin
      state     <= next_state;
      prob_acc  <= prob_acc_next;
      match_g   <= match_g_next;
      match_k   <= match_k_next;
      step_cnt  <= step_cnt_next;
      done      <= done_next;
      start_d1  <= start;
    end
  end

  // Output assignment
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prob_out <= '0;
    end else begin
      prob_out <= (state == RUN) ? prob_acc_next : prob_out;
    end
  end

endmodule