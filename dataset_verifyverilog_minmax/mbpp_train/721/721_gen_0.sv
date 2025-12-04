module max_path_average (
  input clk,
  input rst_n,
  input start,
  input [7:0] cost_0_0, cost_0_1, cost_0_2, cost_0_3,
  input [7:0] cost_1_0, cost_1_1, cost_1_2, cost_1_3,
  input [7:0] cost_2_0, cost_2_1, cost_2_2, cost_2_3,
  input [7:0] cost_3_0, cost_3_1, cost_3_2, cost_3_3,
  output reg [15:0] max_avg,
  output reg done
);

  // Internal state machine
  typedef enum logic [1:0] { IDLE = 2'b00, COMPUTE_SUM = 2'b01, COMPUTE_AVG = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Pipelined DP registers (Q16.8, to preserve precision through additions)
  reg [23:0] s00, s01, s02, s03;
  reg [23:0] s10, s11, s12, s13;
  reg [23:0] s20, s21, s22, s23;
  reg [23:0] s30, s31, s32, s33;

  reg [23:0] s00_next, s01_next, s02_next, s03_next;
  reg [23:0] s10_next, s11_next, s12_next, s13_next;
  reg [23:0] s20_next, s21_next, s22_next, s23_next;
  reg [23:0] s30_next, s31_next, s32_next, s33_next;

  // Latched inputs as Q16.8
  reg [15:0] c00, c01, c02, c03;
  reg [15:0] c10, c11, c12, c13;
  reg [15:0] c20, c21, c22, c23;
  reg [15:0] c30, c31, c32, c33;

  // Division (by 7) state in Q16.8
  reg [23:0] numer;        // 24-bit numerator (Q16.8)
  reg [15:0] quotient;     // 16-bit quotient (Q16.8)
  reg [23:0] rema;         // 24-bit remainder
  reg [2:0] div_cnt;
  reg div_en;

  // Edge-detect for start
  reg start_d1;
  wire start_pulse = start && !start_d1;

  // One-cycle done pulse
  reg done_r;
  assign done = done_r;

  // Sync for start_pulse and done_r
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d1 <= 1'b0;
      done_r   <= 1'b0;
    end else begin
      start_d1 <= start;
      done_r   <= (state == DONE) ? 1'b1 : 1'b0;
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Combinational next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse) next_state = COMPUTE_SUM;
      end
      COMPUTE_SUM: begin
        if (div_en) next_state = COMPUTE_AVG;
      end
      COMPUTE_AVG: begin
        if (div_cnt == 3'd0) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Compute SUM stage transitions and DP updates
  always @(*) begin
    // Default: keep current values
    s00_next = s00; s01_next = s01; s02_next = s02; s03_next = s03;
    s10_next = s10; s11 = s11; s12 = s12; s13 = s13;
    s20_next = s20; s21 = s21; s22 = s22; s23 = s23;
    s30_next = s30; s31 = s31; s32 = s32; s33 = s33;

    // Division control defaults
    div_en = 1'b0;

    case (state)
      IDLE: begin
        // Hold at zero until started (explicit reset also zero-initializes)
      end

      COMPUTE_SUM: begin
        // Stage 0: initialize first row/col from latched costs
        s00_next = c00;
        s01_next = s00 + c01;
        s02_next = s01 + c02;
        s03_next = s02 + c03;
        s10_next = s00 + c10;
        s20_next = s10 + c20;
        s30_next = s20 + c30;

        // Stage 1: update (1,1) and (1,2) and (1,3)
        s11_next = (s10 > s01) ? (s10 + c11) : (s01 + c11);
        s12_next = (s11 > s02) ? (s11 + c12) : (s02 + c12);
        s13_next = (s12 > s03) ? (s12 + c13) : (s03 + c13);

        // Stage 2: update (2,1) and (2,2) and (2,3)
        s21_next = (s20 > s11) ? (s20 + c21) : (s11 + c21);
        s22_next = (s21 > s12) ? (s21 + c22) : (s12 + c22);
        s23_next = (s22 > s13) ? (s22 + c23) : (s13 + c23);

        // Stage 3: update (3,1), (3,2), (3,3)
        s31_next = (s30 > s21) ? (s30 + c31) : (s21 + c31);
        s32_next = (s31 > s22) ? (s31 + c32) : (s22 + c32);
        // Only finalize s33 on the last stage; otherwise keep previous
        s33_next = (s32 > s23) ? (s32 + c33) : (s23 + c33);

        // When the last stage completes, kick off division
        div_en = (s32 != 24'b0) || (s23 != 24'b0); // active when prior stage has advanced
      end

      COMPUTE_AVG, DONE: begin
        // Hold sums constant during averaging/done
      end

      default: begin
        // No change
      end
    endcase
  end

  // Registers update (non-blocking)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s00 <= 24'b0; s01 <= 24'b0; s02 <= 24'b0; s03 <= 24'b0;
      s10 <= 24'b0; s11 <= 24'b0; s12 <= 24'b0; s13 <= 24'b0;
      s20 <= 24'b0; s21 <= 24'b0; s22 <= 24'b0; s23 <= 24'b0;
      s30 <= 24'b0; s31 <= 24'b0; s32 <= 24'b0; s33 <= 24'b0;

      c00 <= 16'b0; c01 <= 16'b0; c02 <= 16'b0; c03 <= 16'b0;
      c10 <= 16'b0; c11 <= 16'b0; c12 <= 16'b0; c13 <= 16'b0;
      c20 <= 16'b0; c21 <= 16'b0; c22 <= 16'b0; c23 <= 16'b0;
      c30 <= 16'b0; c31 <= 16'b0; c32 <= 16'b0; c33 <= 16'b0;

      numer   <= 24'b0;
      quotient<= 16'b0;
      rema    <= 24'b0;
      div_cnt <= 3'b0;
    end else begin
      // Latch inputs on start_pulse in IDLE
      if (state == IDLE && start_pulse) begin
        c00 <= {cost_0_0, 8'b0};
        c01 <= {cost_0_1, 8'b0};
        c02 <= {cost_0_2, 8'b0};
        c03 <= {cost_0_3, 8'b0};
        c10 <= {cost_1_0, 8'b0};
        c11 <= {cost_1_1, 8'b0};
        c12 <= {cost_1_2, 8'b0};
        c13 <= {cost_1_3, 8'b0};
        c20 <= {cost_2_0, 8'b0};
        c21 <= {cost_2_1, 8'b0};
        c22 <= {cost_2_2, 8'b0};
        c23 <= {cost_2_3, 8'b0};
        c30 <= {cost_3_0, 8'b0};
        c31 <= {cost_3_1, 8'b0};
        c32 <= {cost_3_2, 8'b0};
        c33 <= {cost_3_3, 8'b0};
      end

      // Update DP pipeline
      s00 <= s00_next; s01 <= s01_next; s02 <= s02_next; s03 <= s03_next;
      s10 <= s10_next; s11 <= s11_next; s12 <= s12_next; s13 <= s13_next;
      s20 <= s20_next; s21 <= s21_next; s22 <= s22_next; s23 <= s23_next;
      s30 <= s30_next; s31 <= s31_next; s32 <= s32_next; s33 <= s33_next;

      // Division: start and iterate for 7 cycles (Q16.8 / 7 -> Q16.8)
      if (state == IDLE) begin
        numer   <= 24'b0;
        quotient<= 16'b0;
        rema    <= 24'b0;
        div_cnt <= 3'b0;
      end else if (state == COMPUTE_SUM && div_en) begin
        numer   <= s33_next;   // feed current s33 (after last stage) into divider
        quotient<= 16'b0;
        rema    <= 24'b0;
        div_cnt <= 3'd6;       // 7 iterations, so start at 6 down to 0
      end else if (state == COMPUTE_AVG) begin
        if (div_cnt == 3'd6) begin
          // Initialize on first divide cycle
          rema <= {4'b0, numer[23:4]}; // dividend = numer << 4  (to get extra 4 fractional bits)
        end else begin
          // Shift and subtract 7 * 2^(fractional_bits_done)
          rema <= {rema[22:0], 1'b0} - {3'b0, 7'b0000111, 14'b0};
          if ({rema[22:0], 1'b0} >= {3'b0, 7'b0000111, 14'b0}) begin
            quotient <= {quotient[14:0], 1'b1};
          end else begin
            quotient <= {quotient[14:0], 1'b0};
            rema     <= rema; // unchanged as we already subtracted above
          end
        end
        if (div_cnt != 3'd0) div_cnt <= div_cnt - 1;
      end else begin
        // HOLD during DONE and IDLE
      end

      // Final result capture (one cycle)
      if (state == DONE) begin
        max_avg <= quotient; // Q16.8 result
      end
    end
  end

endmodule
