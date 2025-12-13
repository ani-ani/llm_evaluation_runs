module max_subarray_sum_repeat(
  input  clk,
  input  rst_n,
  input  start,
  input  [1:0] n,
  input  [1:0] k,
  input  [7:0] a0,
  input  [7:0] a1,
  input  [7:0] a2,
  input  [7:0] a3,
  output reg [15:0] max_sum,
  output reg done
);

  // State encoding
  localparam [1:0]
    IDLE    = 2'b00,
    INIT    = 2'b01,
    PROCESS = 2'b10,
    FINAL   = 2'b11;

  reg [1:0] state, next_state;

  // Latched inputs
  reg [1:0] n_reg;
  reg [1:0] k_reg;
  reg [7:0] a0_reg, a1_reg, a2_reg, a3_reg;

  // Counters and control
  reg [3:0] total_len;        // max n*k = 12, fits in 4 bits
  reg [3:0] idx;              // element index 0..(total_len-1)
  reg [1:0] pos;              // idx % n_reg (0..3)

  // Kadane's algorithm registers (signed 16-bit)
  reg  signed [15:0] max_ending_here;
  reg  signed [15:0] max_so_far;
  wire signed [15:0] curr_val;

  // Current element selection based on circular indexing
  assign curr_val = (pos == 2'd0) ? {{8{a0_reg[7]}}, a0_reg} :
                    (pos == 2'd1) ? {{8{a1_reg[7]}}, a1_reg} :
                    (pos == 2'd2) ? {{8{a2_reg[7]}}, a2_reg} :
                                     {{8{a3_reg[7]}}, a3_reg};

  // State register and async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      n_reg            <= 2'd0;
      k_reg            <= 2'd0;
      a0_reg           <= 8'd0;
      a1_reg           <= 8'd0;
      a2_reg           <= 8'd0;
      a3_reg           <= 8'd0;
      total_len        <= 4'd0;
      idx              <= 4'd0;
      pos              <= 2'd0;
      max_ending_here  <= 16'sd0;
      max_so_far       <= 16'sd0;
      max_sum          <= 16'sd0;
      done             <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs on start
            n_reg  <= (n == 2'd0) ? 2'd1 : n;  // safety: enforce n>=1
            k_reg  <= (k == 2'd0) ? 2'd1 : k;  // safety: enforce k>=1
            a0_reg <= a0;
            a1_reg <= a1;
            a2_reg <= a2;
            a3_reg <= a3;
          end
        end

        INIT: begin
          // Compute total_len = n_reg * k_reg
          total_len <= n_reg * k_reg;
          // Initialize for Kadane
          idx             <= 4'd0;
          pos             <= 2'd0;
          max_ending_here <= 16'sd0;
          // Initialize max_so_far with first element (at PROCESS cycle 0)
          // Here we pre-set to most negative to ensure first update wins
          max_so_far      <= -16'sd32768;
          done            <= 1'b0;
        end

        PROCESS: begin
          // Kadane's step for current element
          // sum = max_ending_here + curr_val
          // if sum < curr_val: max_ending_here = curr_val; else sum
          // if max_ending_here > max_so_far: update max_so_far
          begin : kadane_block
            reg signed [15:0] sum;
            sum = max_ending_here + curr_val;
            if (sum < curr_val)
              max_ending_here <= curr_val;
            else
              max_ending_here <= sum;

            if ( (sum < curr_val ? curr_val : sum) > max_so_far )
              max_so_far <= (sum < curr_val ? curr_val : sum);
          end

          // Update index and position for next cycle
          if (idx + 1 < total_len) begin
            idx <= idx + 1'b1;
            // pos = (idx + 1) % n_reg; n_reg in [1..4]
            case (n_reg)
              2'd1: pos <= 2'd0;
              2'd2: pos <= (pos == 2'd0) ? 2'd1 : 2'd0;
              2'd3: pos <= (pos == 2'd0) ? 2'd1 :
                           (pos == 2'd1) ? 2'd2 : 2'd0;
              default: pos <= (pos == 2'd0) ? 2'd1 :
                               (pos == 2'd1) ? 2'd2 :
                               (pos == 2'd2) ? 2'd3 : 2'd0;
            endcase
          end
        end

        FINAL: begin
          // Latch result and assert done
          max_sum <= max_so_far;
          done    <= 1'b1;
        end
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
        // Move to PROCESS next cycle; total_len valid after this cycle
        next_state = PROCESS;
      end

      PROCESS: begin
        // When last element (idx == total_len-1) has just been processed,
        // move to FINAL in next cycle
        if (idx + 1 == total_len)
          next_state = FINAL;
        else
          next_state = PROCESS;
      end

      FINAL: begin
        // Stay in FINAL until start deasserted and reasserted (through IDLE)
        if (!start)
          next_state = IDLE;
        else
          next_state = FINAL;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule