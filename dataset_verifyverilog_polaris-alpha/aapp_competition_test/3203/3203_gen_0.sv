module mission_assigner(
  input  clk,
  input  rst_n,
  input  start,
  input  [6:0] probabilities [0:3][0:3],
  output reg [31:0] max_prob,
  output reg done
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam CALCULATING = 2'b01;
  localparam DONE        = 2'b10;

  reg [1:0]  state, next_state;
  reg [5:0]  cycle_cnt;            // counts 0..31
  reg [4:0]  perm_idx;             // 0..23

  // Current permutation indices: agent row -> mission column
  reg [1:0] p0, p1, p2, p3;

  // Internal max tracking
  reg [31:0] max_prob_next;

  // Fixed base = 65536/100 = 655.36, but we use integer math.
  // For each probability p (0..100): q = (p * 65536) / 100
  // All multiplies are done in 32-bit; assume inputs small enough for this.

  // Combinational: get permutation columns from perm_idx
  always @(*) begin
    case (perm_idx)
      5'd0:  begin p0=0; p1=1; p2=2; p3=3; end
      5'd1:  begin p0=0; p1=1; p2=3; p3=2; end
      5'd2:  begin p0=0; p1=2; p2=1; p3=3; end
      5'd3:  begin p0=0; p1=2; p2=3; p3=1; end
      5'd4:  begin p0=0; p1=3; p2=1; p3=2; end
      5'd5:  begin p0=0; p1=3; p2=2; p3=1; end

      5'd6:  begin p0=1; p1=0; p2=2; p3=3; end
      5'd7:  begin p0=1; p1=0; p2=3; p3=2; end
      5'd8:  begin p0=1; p1=2; p2=0; p3=3; end
      5'd9:  begin p0=1; p1=2; p2=3; p3=0; end
      5'd10: begin p0=1; p1=3; p2=0; p3=2; end
      5'd11: begin p0=1; p1=3; p2=2; p3=0; end

      5'd12: begin p0=2; p1=0; p2=1; p3=3; end
      5'd13: begin p0=2; p1=0; p2=3; p3=1; end
      5'd14: begin p0=2; p1=1; p2=0; p3=3; end
      5'd15: begin p0=2; p1=1; p2=3; p3=0; end
      5'd16: begin p0=2; p1=3; p2=0; p3=1; end
      5'd17: begin p0=2; p1=3; p2=1; p3=0; end

      5'd18: begin p0=3; p1=0; p2=1; p3=2; end
      5'd19: begin p0=3; p1=0; p2=2; p3=1; end
      5'd20: begin p0=3; p1=1; p2=0; p3=2; end
      5'd21: begin p0=3; p1=1; p2=2; p3=0; end
      5'd22: begin p0=3; p1=2; p2=0; p3=1; end
      5'd23: begin p0=3; p1=2; p2=1; p3=0; end
      default: begin p0=0; p1=1; p2=2; p3=3; end
    endcase
  end

  // Combinational: FSM next state and control
  always @(*) begin
    next_state   = state;
    max_prob_next = max_prob;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATING;
        end
      end

      CALCULATING: begin
        // max_prob_next is updated in sequential block per cycle, here we only decide state
        if (cycle_cnt == 6'd31) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait here until start deasserted then reasserted (simple protocol)
        if (!start)
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
      state      <= IDLE;
      cycle_cnt  <= 6'd0;
      perm_idx   <= 5'd0;
      max_prob   <= 32'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 6'd0;
          perm_idx  <= 5'd0;
          max_prob  <= 32'd0;
          if (start) begin
            // Initialization for new run
            done      <= 1'b0;
            cycle_cnt <= 6'd0;
            perm_idx  <= 5'd0;
            max_prob  <= 32'd0;
          end
        end

        CALCULATING: begin
          // Compute one permutation product per cycle using fixed-point
          // Convert probabilities to Q16.16: (p * 65536) / 100
          // Use intermediate wider regs for calculation within this block
          reg [31:0] q0, q1, q2, q3;
          reg [63:0] t0, t1, t2;
          reg [31:0] prod;

          q0 = (probabilities[0][p0] * 32'd65536) / 32'd100;
          q1 = (probabilities[1][p1] * 32'd65536) / 32'd100;
          q2 = (probabilities[2][p2] * 32'd65536) / 32'd100;
          q3 = (probabilities[3][p3] * 32'd65536) / 32'd100;

          // Multiply four Q16.16 numbers; keep result in Q16.16 by truncating
          t0 = q0 * q1;          // Q32.32
          t1 = q2 * q3;          // Q32.32
          t2 = (t0 >> 16) * (t1 >> 16); // (Q16.16 * Q16.16) -> Q32.32
          prod = t2[47:16];      // Back to Q16.16 (take middle 32 bits)

          // Update max
          if (prod > max_prob)
            max_prob <= prod;

          // Advance permutation index (0..23) for next cycle (24 perms within first 24 cycles)
          if (perm_idx < 5'd23)
            perm_idx <= perm_idx + 5'd1;

          // Cycle counter for fixed 32-cycle latency
          if (cycle_cnt < 6'd31)
            cycle_cnt <= cycle_cnt + 6'd1;

          // done asserted only when state changes to DONE in next cycle
          done <= 1'b0;
        end

        DONE: begin
          done <= 1'b1;
          // Hold outputs stable in DONE
          cycle_cnt <= cycle_cnt;
          perm_idx  <= perm_idx;
          max_prob  <= max_prob;
        end

        default: begin
          state     <= IDLE;
          done      <= 1'b0;
          cycle_cnt <= 6'd0;
          perm_idx  <= 5'd0;
          max_prob  <= 32'd0;
        end
      endcase
    end
  end

endmodule