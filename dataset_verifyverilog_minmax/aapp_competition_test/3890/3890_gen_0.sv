module penguin_plaque_counter (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,       // 5-bit; value up to 31 (design assumes <=16)
  input [3:0] k,       // 4-bit; value up to 15 (design assumes <=8)
  output reg [31:0] result,
  output reg done
);
  parameter M = 32'd1000000007;

  // FSM states
  typedef enum logic [2:0] { IDLE = 3'b000, CALC_A = 3'b001, CALC_B = 3'b010, MULTIPLY = 3'b011, DONE = 3'b100 } fsm_state_t;
  fsm_state_t state, next_state;

  // Compute registers (sequential multiplier)
  reg [31:0] base_reg;      // base for exponentiation
  reg [31:0] mult_reg;      // multiplicand (M)
  reg [31:0] acc_reg;       // accumulator
  reg [31:0] mod_out;       // reduced partial result
  reg [5:0] bit_cnt;        // 6-bit to support count up to 31

  // Global counters
  reg [4:0] cycles;         // track total cycles (<= 25)
  reg [4:0] a_bits;         // bit count for exponent k
  reg [4:0] b_bits;         // bit count for exponent n-k

  // Next-state logic for FSM
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:  next_state = start ? CALC_A : IDLE;
      CALC_A: begin
        // Switch after processing all exponent bits (LSB-first)
        next_state = (bit_cnt >= a_bits) ? CALC_B : CALC_A;
      end
      CALC_B: begin
        next_state = (bit_cnt >= b_bits) ? MULTIPLY : CALC_B;
      end
      MULTIPLY: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State and datapath update
  always @(posedge clk) begin
    if (!rst_n) begin
      state       <= IDLE;
      result      <= 32'd0;
      done        <= 1'b0;
      base_reg    <= 32'd0;
      mult_reg    <= 32'd0;
      acc_reg     <= 32'd0;
      mod_out     <= 32'd0;
      bit_cnt     <= 6'd0;
      cycles      <= 5'd0;
      a_bits      <= 5'd0;
      b_bits      <= 5'd0;
    end else begin
      // Default: keep result/done until next transaction or reset
      result <= result;
      done   <= 1'b0;

      case (state)
        IDLE: begin
          cycles  <= 5'd0;
          bit_cnt <= 6'd0;
          if (start) begin
            // Edge case: k=0 -> invalid (result=0)
            if (k == 5'd0) begin
              result  <= 32'd0;
              done    <= 1'b1;
              state   <= IDLE; // immediately done without further work
            end else begin
              // Initialize for A = k^(k-1) mod M
              base_reg  <= k;
              mult_reg  <= k;
              acc_reg   <= 32'd1;
              bit_cnt   <= 6'd0;
              a_bits    <= 5'd0;
              b_bits    <= 5'd0;
              cycles    <= 5'd1;  // spent this cycle transitioning
              state     <= CALC_A;
            end
          end else begin
            state <= IDLE;
          end
        end

        CALC_A: begin
          // Sequential modular exponentiation (LSB-first, 2-bit window using one pre-scout LSB)
          if (bit_cnt == 6'd0) begin
            // First, process the LSB (k) before starting the 2-bit window
            if (k[0]) begin
              acc_reg <= (acc_reg * k) % M;
            end
            base_reg <= k;
            mult_reg <= k;
            bit_cnt  <= 6'd1;
            a_bits    <= (k > 0) ? 5'd1 : 5'd0;  // k bits counted (1)
            cycles    <= cycles + 1;
          end else begin
            // For remaining bits, handle a 2-bit window per cycle
            // Shift right by 1 to expose new LSB for next window
            base_reg  <= base_reg >> 1;
            mult_reg  <= {1'b0, mult_reg[31:1]}; // multiplier = floor(k/2) with zero-fill MSB
            bit_cnt   <= bit_cnt + 1;
            a_bits    <= a_bits + 1;
            cycles    <= cycles + 1;

            if (mult_reg[0]) begin
              acc_reg <= (acc_reg * base_reg) % M;
            end
            // Early termination check (all remaining high bits are zero)
            if (mult_reg >> 1 == 32'd0) begin
              bit_cnt <= 6'd255; // force a_bits condition to true next cycle
            end
          end
        end

        CALC_B: begin
          // Compute B = (n-k)^(n-k) mod M, treating 0^0 as 1.
          if (bit_cnt == 6'd0) begin
            if (n == k) begin
              // B = 1 due to 0^0
              acc_reg   <= 32'd1;
              bit_cnt   <= 6'd255; // make condition true immediately
              cycles    <= cycles + 1;
            end else begin
              // Initialize with base^(LSB) then start 2-bit loop
              base_reg  <= n - k;
              mult_reg  <= n - k;
              if ((n - k)[0]) begin
                acc_reg <= (n - k) % M; // 1 * base^1 = base
              end else begin
                acc_reg <= 32'd1;
              end
              bit_cnt   <= 6'd1;
              a_bits    <= 5'd1;
              cycles    <= cycles + 1;
            end
          end else begin
            base_reg  <= base_reg >> 1;
            mult_reg  <= {1'b0, mult_reg[31:1]}; // floor(exp/2)
            bit_cnt   <= bit_cnt + 1;
            a_bits    <= a_bits + 1;
            cycles    <= cycles + 1;

            if (mult_reg[0]) begin
              acc_reg <= (acc_reg * base_reg) % M;
            end
            if (mult_reg >> 1 == 32'd0) begin
              bit_cnt <= 6'd255;
            end
          end
        end

        MULTIPLY: begin
          // Multiply A and B modulo M using sequential multiplier (2-bit window)
          // A is in acc_reg from CALC_A; B is in base_reg from CALC_B
          mult_reg  <= acc_reg;          // multiplier
          base_reg  <= acc_reg;          // will hold 'b' (B) as multiplicand initially
          acc_reg   <= 32'd1;            // accumulator for multiplication
          mod_out   <= 32'd0;
          bit_cnt   <= 6'd0;
          a_bits    <= 5'd0;
          b_bits    <= 5'd0;
          cycles    <= cycles + 1;
          state     <= MULTIPLY;         // stay for next cycle

          // If result A is zero, we can finish immediately
          if (acc_reg == 32'd0) begin
            result  <= 32'd0;
            done    <= 1'b1;
            state   <= IDLE;
          end
        end

        // Continue MULTIPLY from this point by falling through after 1 cycle
        default: begin
          if (state == MULTIPLY) begin
            // First iteration: process LSB of B
            if (bit_cnt == 6'd0) begin
              if (acc_reg[0]) begin
                mod_out <= (acc_reg + base_reg) % M; // A * 1 (LSB is 1)
              end else begin
                mod_out <= acc_reg;
              end
              // Prepare for the 2-bit window loop
              mult_reg  <= {1'b0, acc_reg[31:1]}; // floor(B/2)
              base_reg  <= base_reg;
              bit_cnt   <= 6'd1;
              b_bits    <= 5'd1;
              cycles    <= cycles + 1;
              acc_reg   <= mod_out;
              state     <= MULTIPLY;
            end else begin
              // Loop for remaining bits (2 bits per cycle via LSB pre-scout)
              // 1) Inspect new LSB after right-shift by 1
              if (mult_reg[0]) begin
                acc_reg <= (acc_reg * base_reg) % M; // A * b (for this step)
              end

              // 2) Update for next window (right shift both, keep multiplicand scaled)
              mult_reg  <= {1'b0, mult_reg[31:1]}; // floor(mult_reg/2)
              base_reg  <= base_reg >> 1;          // b = b >> 1 (same as multiply by 1/2 in GF(M))
              bit_cnt   <= bit_cnt + 1;
              b_bits    <= b_bits + 1;
              cycles    <= cycles + 1;

              if (mult_reg == 32'd0) begin
                result  <= acc_reg;
                done    <= 1'b1;
                state   <= IDLE;
              end else begin
                state   <= MULTIPLY;
              end
            end
          end else begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule
