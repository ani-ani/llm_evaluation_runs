module fence_painting(
  input        clk,
  input        rst_n,
  input        start,
  input  [2:0] n,
  input  [1:0] k,
  output reg [15:0] result,
  output reg       done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam CALCULATE = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0]  state, next_state;

  // Internal registers
  reg [2:0]  n_reg;          // latched n
  reg [1:0]  k_reg;          // latched k
  reg [2:0]  idx;            // current post index (1..8)
  reg [15:0] dp_prev;        // dp[i-2]
  reg [15:0] dp_curr;        // dp[i-1]
  reg [15:0] dp_next;        // dp[i]
  reg        start_d;        // delayed start for edge detect
  wire       start_pulse;

  // Start pulse detection (rising edge)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = CALCULATE;
      end
      CALCULATE: begin
        // Transition to DONE when we've computed up to n_reg
        if (idx >= n_reg)
          next_state = DONE;
      end
      DONE: begin
        // Wait for next start pulse to restart
        if (start_pulse)
          next_state = CALCULATE;
        else if (!start) begin
          // Optionally return to IDLE when not actively started
          // but remain in DONE until new start_pulse
          next_state = DONE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic for datapath and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg   <= 3'd0;
      k_reg   <= 2'd0;
      idx     <= 3'd0;
      dp_prev <= 16'd0;
      dp_curr <= 16'd0;
      dp_next <= 16'd0;
      result  <= 16'd0;
      done    <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Latch inputs
            n_reg <= n;
            k_reg <= k;

            // Handle small n directly and initialize for calculation
            if (n == 3'd0) begin
              // Undefined per spec, treat as 0 ways
              result  <= 16'd0;
              idx     <= 3'd0;
              dp_prev <= 16'd0;
              dp_curr <= 16'd0;
            end else if (n == 3'd1) begin
              // dp[1] = k
              result  <= {14'd0, k};
              idx     <= 3'd1;
              dp_prev <= 16'd0;
              dp_curr <= {14'd0, k};
            end else begin
              // n >= 2
              // dp[1] = k, dp[2] = k*k
              dp_prev <= {14'd0, k};
              dp_curr <= k * k;
              idx     <= 3'd2;
              result  <= k * k;
            end
          end
        end

        CALCULATE: begin
          done <= 1'b0;

          if (n_reg == 3'd0) begin
            // No valid posts
            result <= 16'd0;
            idx    <= 3'd0;
          end else if (n_reg == 3'd1) begin
            // Already have result from IDLE
            idx <= 3'd1;
          end else begin
            // n_reg >= 2
            if (idx < n_reg) begin
              // Compute next dp: dp[i] = (k-1) * (dp[i-1] + dp[i-2])
              dp_next <= ( (k_reg - 2'd1) * (dp_curr + dp_prev) );

              // Update registers for next iteration
              dp_prev <= dp_curr;
              dp_curr <= ( (k_reg - 2'd1) * (dp_curr + dp_prev) );
              idx     <= idx + 3'd1;

              // If this new index reaches n_reg, update result
              if ((idx + 3'd1) == n_reg)
                result <= ( (k_reg - 2'd1) * (dp_curr + dp_prev) );
            end
          end
        end

        DONE: begin
          // Result is held stable
          done <= 1'b1;

          // On a new start pulse, reinitialize similar to IDLE handling
          if (start_pulse) begin
            done   <= 1'b0;
            n_reg  <= n;
            k_reg  <= k;

            if (n == 3'd0) begin
              result  <= 16'd0;
              idx     <= 3'd0;
              dp_prev <= 16'd0;
              dp_curr <= 16'd0;
            end else if (n == 3'd1) begin
              result  <= {14'd0, k};
              idx     <= 3'd1;
              dp_prev <= 16'd0;
              dp_curr <= {14'd0, k};
            end else begin
              dp_prev <= {14'd0, k};
              dp_curr <= k * k;
              idx     <= 3'd2;
              result  <= k * k;
            end
          end
        end

        default: begin
          done   <= 1'b0;
          result <= 16'd0;
        end
      endcase
    end
  end

endmodule