module ip_zero_remover (
  input  clk,
  input  rst_n,
  input  start,
  input  [95:0] ip_bytes,
  output reg [95:0] clean_bytes,
  output reg done
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    PROC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Latched input
  reg [95:0] ip_reg;

  // Cycle counter: 0..15 for 16 cycles
  reg [3:0] cycle_cnt;

  // Working copy of clean bytes
  reg [95:0] clean_reg;

  // Per-segment output bytes
  reg [7:0] s0_b0, s0_b1, s0_b2;
  reg [7:0] s1_b0, s1_b1, s1_b2;
  reg [7:0] s2_b0, s2_b1, s2_b2;
  reg [7:0] s3_b0, s3_b1, s3_b2;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        next_state = PROC;
      end
      PROC: begin
        if (cycle_cnt == 4'd15) next_state = DONE;
      end
      DONE: begin
        // stay done until next start goes high
        if (start) next_state = LOAD;
        else next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      ip_reg      <= 96'd0;
      clean_reg   <= 96'd0;
      clean_bytes <= 96'd0;
      done        <= 1'b0;
      cycle_cnt   <= 4'd0;
      s0_b0 <= 8'd0; s0_b1 <= 8'd0; s0_b2 <= 8'd0;
      s1_b0 <= 8'd0; s1_b1 <= 8'd0; s1_b2 <= 8'd0;
      s2_b0 <= 8'd0; s2_b1 <= 8'd0; s2_b2 <= 8'd0;
      s3_b0 <= 8'd0; s3_b1 <= 8'd0; s3_b2 <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 4'd0;
          if (start) begin
            // Latch input on start; actual processing begins in LOAD/PROC
            ip_reg <= ip_bytes;
          end
        end

        LOAD: begin
          // Initialize outputs and counters prior to processing
          done        <= 1'b0;
          cycle_cnt   <= 4'd0;
          clean_reg   <= 96'd0;
          s0_b0 <= 8'd0; s0_b1 <= 8'd0; s0_b2 <= 8'd0;
          s1_b0 <= 8'd0; s1_b1 <= 8'd0; s1_b2 <= 8'd0;
          s2_b0 <= 8'd0; s2_b1 <= 8'd0; s2_b2 <= 8'd0;
          s3_b0 <= 8'd0; s3_b1 <= 8'd0; s3_b2 <= 8'd0;
        end

        PROC: begin
          done <= 1'b0;

          // Compute which segment to process based on cycle counter
          // 4 cycles per segment: seg_id = cycle_cnt[3:2]
          case (cycle_cnt[3:2])
            2'd0: begin : SEG0
              // Segment 0: bits [95:72]
              reg [7:0] c0, c1, c2;
              c0 = ip_reg[95:88];
              c1 = ip_reg[87:80];
              c2 = ip_reg[79:72];

              // Remove leading '0' (ASCII 8'h30); if all zeros, keep one '0'
              if (c0 == 8'h30) begin
                if (c1 == 8'h30) begin
                  if (c2 == 8'h30) begin
                    // All zeros -> keep one '0'
                    s0_b0 <= 8'h30;
                    s0_b1 <= 8'h00;
                    s0_b2 <= 8'h00;
                  end else begin
                    // "00x" -> "x"
                    s0_b0 <= c2;
                    s0_b1 <= 8'h00;
                    s0_b2 <= 8'h00;
                  end
                end else begin
                  if (c2 == 8'h30) begin
                    // "0x0" -> "x0"
                    s0_b0 <= c1;
                    s0_b1 <= c2;
                    s0_b2 <= 8'h00;
                  end else begin
                    // "0xy" -> "xy"
                    s0_b0 <= c1;
                    s0_b1 <= c2;
                    s0_b2 <= 8'h00;
                  end
                end
              end else begin
                // First char non-zero, keep all
                s0_b0 <= c0;
                s0_b1 <= c1;
                s0_b2 <= c2;
              end

              // Write cleaned segment 0 into clean_reg
              clean_reg[95:88] <= s0_b0;
              clean_reg[87:80] <= s0_b1;
              clean_reg[79:72] <= s0_b2;
            end

            2'd1: begin : SEG1
              // Segment 1: bits [71:48]
              reg [7:0] c0, c1, c2;
              c0 = ip_reg[71:64];
              c1 = ip_reg[63:56];
              c2 = ip_reg[55:48];

              if (c0 == 8'h30) begin
                if (c1 == 8'h30) begin
                  if (c2 == 8'h30) begin
                    s1_b0 <= 8'h30;
                    s1_b1 <= 8'h00;
                    s1_b2 <= 8'h00;
                  end else begin
                    s1_b0 <= c2;
                    s1_b1 <= 8'h00;
                    s1_b2 <= 8'h00;
                  end
                end else begin
                  if (c2 == 8'h30) begin
                    s1_b0 <= c1;
                    s1_b1 <= c2;
                    s1_b2 <= 8'h00;
                  end else begin
                    s1_b0 <= c1;
                    s1_b1 <= c2;
                    s1_b2 <= 8'h00;
                  end
                end
              end else begin
                s1_b0 <= c0;
                s1_b1 <= c1;
                s1_b2 <= c2;
              end

              clean_reg[71:64] <= s1_b0;
              clean_reg[63:56] <= s1_b1;
              clean_reg[55:48] <= s1_b2;
            end

            2'd2: begin : SEG2
              // Segment 2: bits [47:24]
              reg [7:0] c0, c1, c2;
              c0 = ip_reg[47:40];
              c1 = ip_reg[39:32];
              c2 = ip_reg[31:24];

              if (c0 == 8'h30) begin
                if (c1 == 8'h30) begin
                  if (c2 == 8'h30) begin
                    s2_b0 <= 8'h30;
                    s2_b1 <= 8'h00;
                    s2_b2 <= 8'h00;
                  end else begin
                    s2_b0 <= c2;
                    s2_b1 <= 8'h00;
                    s2_b2 <= 8'h00;
                  end
                end else begin
                  if (c2 == 8'h30) begin
                    s2_b0 <= c1;
                    s2_b1 <= c2;
                    s2_b2 <= 8'h00;
                  end else begin
                    s2_b0 <= c1;
                    s2_b1 <= c2;
                    s2_b2 <= 8'h00;
                  end
                end
              end else begin
                s2_b0 <= c0;
                s2_b1 <= c1;
                s2_b2 <= c2;
              end

              clean_reg[47:40] <= s2_b0;
              clean_reg[39:32] <= s2_b1;
              clean_reg[31:24] <= s2_b2;
            end

            2'd3: begin : SEG3
              // Segment 3: bits [23:0]
              reg [7:0] c0, c1, c2;
              c0 = ip_reg[23:16];
              c1 = ip_reg[15:8];
              c2 = ip_reg[7:0];

              if (c0 == 8'h30) begin
                if (c1 == 8'h30) begin
                  if (c2 == 8'h30) begin
                    s3_b0 <= 8'h30;
                    s3_b1 <= 8'h00;
                    s3_b2 <= 8'h00;
                  end else begin
                    s3_b0 <= c2;
                    s3_b1 <= 8'h00;
                    s3_b2 <= 8'h00;
                  end
                end else begin
                  if (c2 == 8'h30) begin
                    s3_b0 <= c1;
                    s3_b1 <= c2;
                    s3_b2 <= 8'h00;
                  end else begin
                    s3_b0 <= c1;
                    s3_b1 <= c2;
                    s3_b2 <= 8'h00;
                  end
                end
              end else begin
                s3_b0 <= c0;
                s3_b1 <= c1;
                s3_b2 <= c2;
              end

              clean_reg[23:16] <= s3_b0;
              clean_reg[15:8]  <= s3_b1;
              clean_reg[7:0]   <= s3_b2;
            end

            default: ;
          endcase

          // Increment cycle counter
          cycle_cnt <= cycle_cnt + 4'd1;
        end

        DONE: begin
          // Assert done and present final output
          done        <= 1'b1;
          clean_bytes <= clean_reg;
          cycle_cnt   <= 4'd0;
        end

        default: begin
          done      <= 1'b0;
          cycle_cnt <= 4'd0;
        end
      endcase
    end
  end

endmodule