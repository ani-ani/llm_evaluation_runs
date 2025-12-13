module palindromic_sequence_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [15:0] N, // sequence length (1 ≤ N ≤ 65535)
  input [15:0] K, // max element value (1 ≤ K ≤ 65535)
  output reg [31:0] result, // final answer
  output reg done // high when computation finished
);

  // Parameters
  localparam MOD = 32'd1000000007;
  localparam DIV_LIMIT = 6'd32;

  // FSM States
  localparam IDLE        = 3'd0;
  localparam FIND_DIVS   = 3'd1;
  localparam SORT_DIVS   = 3'd2;
  localparam PREP_DIV    = 3'd3;
  localparam POW_CALC    = 3'd4;
  localparam INCL_EXCL   = 3'd5;
  localparam COMPLETE    = 3'd6;

  reg [2:0] state, next_state;

  // Internal registers
  reg [15:0] n_reg, k_reg;

  reg [15:0] divs [0:DIV_LIMIT-1];
  reg [5:0]  div_count;      // number of divisors found

  reg [15:0] d_current;      // current divisor
  reg [5:0]  div_idx;        // index for current divisor processing
  reg [5:0]  sub_idx;        // index for inclusion-exclusion over previous divisors

  // Power calculation
  reg [31:0] pow_acc;        // accumulator for K^e mod MOD
  reg [15:0] pow_exp;        // exponent ( (d+1)//2 )

  // Inclusion-exclusion temporary
  reg [31:0] term_base;      // pow(K, (d+1)//2)
  reg [31:0] sub_sum;        // sum of previous terms for current divisor
  reg [31:0] term;           // final term after subtraction

  reg [31:0] ans;            // accumulated answer

  // Storage for terms corresponding to each divisor (aligned by sorted divs)
  reg [31:0] terms [0:DIV_LIMIT-1];

  // Control flags
  reg        start_d;        // edge-detected start
  reg        start_q;

  integer i;

  // Start edge detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_q <= 1'b0;
      start_d <= 1'b0;
    end else begin
      start_q <= start;
      start_d <= start & ~start_q;
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
    end else begin
      state   <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_d)
          next_state = FIND_DIVS;
      end

      FIND_DIVS: begin
        // When divisor enumeration complete, go to sort if more than 1, else directly to PREP_DIV
        if (div_idx > n_reg) begin
          if (div_count <= 6'd1)
            next_state = PREP_DIV;
          else
            next_state = SORT_DIVS;
        end
      end

      SORT_DIVS: begin
        // Simple bubble-sort like: we will terminate when no swaps in pass
        // Here we use div_idx as outer, sub_idx as inner; when finished, go PREP_DIV
        if (div_idx == div_count) begin
          next_state = PREP_DIV;
        end
      end

      PREP_DIV: begin
        // Move to pow calc for current divisor if any remaining, else COMPLETE
        if (div_idx < div_count)
          next_state = POW_CALC;
        else
          next_state = COMPLETE;
      end

      POW_CALC: begin
        // When exponent reduced to zero, continue with inclusion-exclusion
        if (pow_exp == 16'd0)
          next_state = INCL_EXCL;
      end

      INCL_EXCL: begin
        // After scanning all previous divisors, move to PREP_DIV for next divisor
        if (sub_idx == div_idx)
          next_state = PREP_DIV;
      end

      COMPLETE: begin
        // Stay until a new start pulse
        if (start_d)
          next_state = FIND_DIVS;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg    <= 16'd0;
      k_reg    <= 16'd0;
      div_count<= 6'd0;
      div_idx  <= 6'd0;
      sub_idx  <= 6'd0;
      d_current<= 16'd0;
      pow_acc  <= 32'd0;
      pow_exp  <= 16'd0;
      term_base<= 32'd0;
      sub_sum  <= 32'd0;
      term     <= 32'd0;
      ans      <= 32'd0;
      result   <= 32'd0;
      done     <= 1'b0;
      for (i=0; i<DIV_LIMIT; i=i+1) begin
        divs[i]  <= 16'd0;
        terms[i] <= 32'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_d) begin
            n_reg     <= N;
            k_reg     <= K;
            div_count <= 6'd0;
            div_idx   <= 6'd1; // start trial divisor from 1
            ans       <= 32'd0;
            for (i=0; i<DIV_LIMIT; i=i+1) begin
              divs[i]  <= 16'd0;
              terms[i] <= 32'd0;
            end
          end
        end

        FIND_DIVS: begin
          // Enumerate divisors of n_reg; basic linear search 1..N
          if (div_idx <= n_reg && div_count < DIV_LIMIT) begin
            if (n_reg % div_idx == 16'd0) begin
              // store divisor if space
              divs[div_count] <= div_idx;
              div_count <= div_count + 6'd1;
            end
            div_idx <= div_idx + 6'd1;
          end else begin
            // finished enumeration; prepare for sort or direct use
            div_idx <= 6'd0;
            sub_idx <= 6'd0;
          end
        end

        SORT_DIVS: begin
          // Simple incremental bubble sort pass across all elements
          // One compare-swap per cycle: use (div_idx, sub_idx) implicitly as single pass index
          if (div_count <= 6'd1) begin
            // nothing to sort
            div_idx <= div_count;
          end else begin
            if (div_idx < div_count-1) begin
              // compare divs[div_idx] and divs[div_idx+1]
              if (divs[div_idx] > divs[div_idx+1]) begin
                // swap
                d_current            <= divs[div_idx];
                divs[div_idx]        <= divs[div_idx+1];
                divs[div_idx+1]      <= d_current;
              end
              div_idx <= div_idx + 6'd1;
            end else begin
              // one pass complete; assume div_idx as count (acts as done)
              div_idx <= div_count;
            end
          end
        end

        PREP_DIV: begin
          done <= 1'b0;
          if (div_idx < div_count) begin
            d_current <= divs[div_idx];
            // exponent = (d + 1) // 2
            pow_exp <= (divs[div_idx] + 16'd1) >> 1;
            // initialize modular power accumulator: start from 1
            pow_acc <= 32'd1;
            term_base <= 32'd0;
            sub_sum   <= 32'd0;
            sub_idx   <= 6'd0;
          end
        end

        POW_CALC: begin
          if (pow_exp != 16'd0) begin
            // iterative multiplication: pow_acc = pow_acc * K mod MOD
            // Using 64-bit intermediate for safety
            pow_acc <= ( (pow_acc * k_reg) % MOD );
            pow_exp <= pow_exp - 16'd1;
          end else begin
            // latch result as base for this divisor
            term_base <= pow_acc % MOD;
          end
        end

        INCL_EXCL: begin
          // Compute term = term_base - sum(previous terms) modulo MOD
          // using one previous term per cycle
          if (sub_idx < div_idx) begin
            // inclusion-exclusion: subtract all previous stored terms
            sub_sum <= (sub_sum + terms[sub_idx]) % MOD;
            sub_idx <= sub_idx + 6'd1;
          end else begin
            // finalize term
            if (term_base >= sub_sum)
              term <= term_base - sub_sum;
            else
              term <= term_base + MOD - sub_sum;

            // store term, update ans and move to next divisor index
            // Use last-cycle values to update, so combinationally using term here
            // will require registered term; so updates happen next clock implicitly
          end
        end

        COMPLETE: begin
          done   <= 1'b1;
          result <= ans % MOD;
          if (start_d) begin
            // start a new computation
            done      <= 1'b0;
            n_reg     <= N;
            k_reg     <= K;
            div_count <= 6'd0;
            div_idx   <= 6'd1;
            ans       <= 32'd0;
            for (i=0; i<DIV_LIMIT; i=i+1) begin
              divs[i]  <= 16'd0;
              terms[i] <= 32'd0;
            end
          end
        end
      endcase

      // Side-effect style updates that depend on freshly computed 'term'
      if (state == INCL_EXCL && sub_idx == div_idx) begin
        // Store term
        terms[div_idx] <= term % MOD;
        // Accumulate into ans with multiplicity based on d_current parity
        if (d_current[0] == 1'b1) begin
          // odd: ans += d * term
          ans <= (ans + ((d_current * term) % MOD)) % MOD;
        end else begin
          // even: ans += (d/2) * term
          ans <= (ans + (((d_current >> 1) * term) % MOD)) % MOD;
        end
        // move to next divisor index
        div_idx <= div_idx + 6'd1;
      end
    end
  end

endmodule