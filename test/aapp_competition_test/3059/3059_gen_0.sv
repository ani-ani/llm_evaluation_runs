module speedrun_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] r,
  input [15:0] trick_t [0:3],
  input [31:0] trick_p [0:3],
  input [15:0] trick_d [0:3],
  input [1:0] m,
  output reg [31:0] result,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam INIT    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE_ST = 2'b11;

  reg [1:0] state, next_state;

  // Internal registers
  reg [31:0] best_time_q;     // best-case time in Q16.16
  reg [31:0] record_time_q;   // record time in Q16.16

  reg [2:0]  init_cnt;        // counts 0..3 for 4-cycle init

  reg [2:0]  trick_idx;       // index for tricks (0..4)
  reg [2:0]  tricks_to_process; // latched m; range 0..4

  reg [31:0] dp_curr;         // current dp value (Q16.16)
  reg [31:0] dp_next;         // next dp value (Q16.16) registered

  // Latched per-trick parameters for current index
  reg [31:0] p_reg;           // trick_p
  reg [31:0] t_q_reg;         // trick_t << 16
  reg [31:0] d_q_reg;         // trick_d << 16

  // Intermediate registers for two-cycle per-trick computation
  reg [31:0] one_minus_p;     // (1 - p) in Q16.16
  reg [63:0] term_p_dp;       // p * dp_next
  reg [63:0] term_1mp;        // (1-p)
  reg [63:0] term_1mp_dp_d;   // (1-p) * (dp_next + d_q)
  reg [31:0] partial_sum;     // t_q + (term_p_dp>>16)

  reg       trick_phase;      // 0 = phase A, 1 = phase B for 2-cycle per trick

  // Sequential state and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= IDLE;
      done              <= 1'b0;
      result            <= 32'd0;
      best_time_q       <= 32'd0;
      record_time_q     <= 32'd0;
      init_cnt          <= 3'd0;
      trick_idx         <= 3'd0;
      tricks_to_process <= 3'd0;
      dp_curr           <= 32'd0;
      dp_next           <= 32'd0;
      p_reg             <= 32'd0;
      t_q_reg           <= 32'd0;
      d_q_reg           <= 32'd0;
      one_minus_p       <= 32'd0;
      term_p_dp         <= 64'd0;
      term_1mp          <= 64'd0;
      term_1mp_dp_d     <= 64'd0;
      partial_sum       <= 32'd0;
      trick_phase       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Start sequence; clear counters
            init_cnt          <= 3'd0;
            tricks_to_process <= {1'b0, m} + 3'd0; // zero-extend
            trick_phase       <= 1'b0;
          end
        end

        INIT: begin
          // 4-cycle initialization sequence
          init_cnt <= init_cnt + 3'd1;

          case (init_cnt)
            3'd0: begin
              // Cycle 1: convert best-case and record to Q16.16
              best_time_q   <= {n, 16'd0};
              record_time_q <= {r, 16'd0};
            end
            3'd1: begin
              // Cycle 2: latch tricks_to_process (0..4) & initial dp_next
              // dp_next is the base value when no more tricks are left
              // For this implementation, use best-case time as base
              dp_next <= {n, 16'd0};
            end
            3'd2: begin
              // Cycle 3: prepare for trick processing
              // Set starting trick_idx based on m (0..4)
              trick_idx   <= tricks_to_process; // points one past last trick
              trick_phase <= 1'b0;
            end
            3'd3: begin
              // Cycle 4: finalize init; dp_curr = dp_next as start
              dp_curr <= dp_next;
            end
            default: ;
          endcase
        end

        PROCESS: begin
          if (tricks_to_process == 3'd0) begin
            // No tricks to process, dp_curr already holds final value
          end else begin
            if (!trick_phase) begin
              // Phase A: load trick parameters and start multiplies
              // trick index to use: trick_idx-1
              if (trick_idx != 3'd0) begin
                p_reg   <= trick_p[trick_idx-1];
                t_q_reg <= {trick_t[trick_idx-1], 16'd0};
                d_q_reg <= {trick_d[trick_idx-1], 16'd0};

                one_minus_p   <= 32'h00010000 - trick_p[trick_idx-1];
                term_p_dp     <= trick_p[trick_idx-1] * dp_next;
                term_1mp      <= (32'h00010000 - trick_p[trick_idx-1]);
                term_1mp_dp_d <= 64'd0; // will be computed in next phase

                partial_sum   <= 32'd0;
                trick_phase   <= 1'b1;
              end
            end else begin
              // Phase B: finish computation
              term_1mp_dp_d <= term_1mp * (dp_next + d_q_reg);
              partial_sum   <= t_q_reg + (term_p_dp[47:16]);

              // Expected time for this trick:
              // dp_curr = t_q + (p * dp_next) + (1-p) * (dp_next + d_q)
              dp_curr <= partial_sum + (term_1mp_dp_d[47:16]);

              // Prepare for next trick in next iterations
              dp_next           <= dp_curr + (term_1mp_dp_d[47:16]); // hold last; corrected next cycle

              // Decrement counts and indices
              if (trick_idx != 3'd0)
                trick_idx <= trick_idx - 3'd1;
              if (tricks_to_process != 3'd0)
                tricks_to_process <= tricks_to_process - 3'd1;

              trick_phase <= 1'b0;
            end
          end
        end

        DONE_ST: begin
          done   <= 1'b1;
          result <= dp_curr;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        if (init_cnt == 3'd3)
          next_state = PROCESS;
      end

      PROCESS: begin
        if (tricks_to_process == 3'd0 && (!trick_phase))
          next_state = DONE_ST;
        else
          next_state = PROCESS;
      end

      DONE_ST: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule