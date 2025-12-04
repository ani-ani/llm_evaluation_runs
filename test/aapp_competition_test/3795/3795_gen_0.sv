module currency_exchange(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] n,
  input  [7:0]  d,
  input  [7:0]  e,
  output reg [15:0] min_rubles,
  output reg       done
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0]  state, next_state;

  // Stored inputs
  reg [15:0] n_reg;
  reg [7:0]  d_reg;
  reg [7:0]  e_reg;

  // Internal registers
  reg [7:0]   iter_cnt;        // up to 255, we allow 0..255 (256 iterations)
  reg [15:0]  current_n;       // n - i*5*e
  reg [15:0]  min_rubles_reg;  // internal minimal remainder
  reg [15:0]  best_remainder;
  reg [8:0]   e5;              // 5*e

  // Division related
  reg [15:0]  dividend;        // current_n
  reg [15:0]  divisor;         // d_reg
  reg [15:0]  quotient;
  reg [15:0]  remainder;
  reg [4:0]   div_bit;         // for 16-bit restoring division
  reg         div_active;

  // Helper wires
  wire [15:0] next_n_candidate;
  assign next_n_candidate = current_n - e5; // only use when current_n >= e5

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC;
      end
      CALC: begin
        // Transition to DONE when division for current iteration is complete
        // and we've met stopping criteria (handled in sequential block)
        if (!div_active) begin
          // Decision is made in seq block; placeholder here
          // next_state set there via state reg update
        end
      end
      DONE: begin
        // done is 1-cycle pulse; return to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      n_reg          <= 16'd0;
      d_reg          <= 8'd0;
      e_reg          <= 8'd0;
      e5             <= 9'd0;
      iter_cnt       <= 8'd0;
      current_n      <= 16'd0;
      min_rubles_reg <= 16'hFFFF;
      best_remainder <= 16'hFFFF;
      dividend       <= 16'd0;
      divisor        <= 16'd0;
      quotient       <= 16'd0;
      remainder      <= 16'd0;
      div_bit        <= 5'd0;
      div_active     <= 1'b0;
      min_rubles     <= 16'd0;
      done           <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start, capture inputs when start asserted
          if (start) begin
            n_reg          <= n;
            d_reg          <= d;
            e_reg          <= e;
            e5             <= {1'b0, e} + ({1'b0, e} << 2); // 5*e = e + 4e

            // Initialize for i = 0
            iter_cnt       <= 8'd0;
            current_n      <= n;
            min_rubles_reg <= 16'hFFFF;
            best_remainder <= 16'hFFFF;

            // Setup division for first iteration (i=0): remainder = n % d
            divisor    <= {8'd0, d};
            dividend   <= n;
            quotient   <= 16'd0;
            remainder  <= 16'd0;
            div_bit    <= 5'd15;
            div_active <= 1'b1;
          end else begin
            div_active <= 1'b0;
          end
        end

        CALC: begin
          // Iterative restoring division for current dividend/divisor
          if (div_active) begin
            // Shift left remainder and bring down next dividend bit
            remainder <= {remainder[14:0], dividend[div_bit]};

            // After shift, compare and subtract divisor if possible
            if ({remainder[14:0], dividend[div_bit]} >= divisor) begin
              remainder <= {remainder[14:0], dividend[div_bit]} - divisor;
              quotient  <= (quotient & ~(16'h1 << div_bit)) | (16'h1 << div_bit);
            end

            if (div_bit == 0) begin
              // Division complete this cycle
              div_active <= 1'b0;
            end else begin
              div_bit <= div_bit - 1'b1;
            end
          end else begin
            // Division just completed: 'remainder' holds current remainder
            if (remainder < best_remainder) begin
              best_remainder <= remainder;
            end

            // Early finish if remainder is zero
            if (remainder == 16'd0) begin
              min_rubles <= 16'd0;
              done       <= 1'b1;
              state      <= DONE;
            end else begin
              // Prepare next iteration if limits not reached
              if (iter_cnt == 8'd255) begin
                // Max iterations reached
                min_rubles <= best_remainder;
                done       <= 1'b1;
                state      <= DONE;
              end else if (current_n >= e5) begin
                // Move to next i: current_n = current_n - 5*e
                current_n <= next_n_candidate;
                iter_cnt  <= iter_cnt + 1'b1;

                // Start new division for updated current_n
                divisor    <= {8'd0, d_reg};
                dividend   <= next_n_candidate;
                quotient   <= 16'd0;
                remainder  <= 16'd0;
                div_bit    <= 5'd15;
                div_active <= 1'b1;
              end else begin
                // Cannot buy more euros; finalize
                min_rubles <= best_remainder;
                done       <= 1'b1;
                state      <= DONE;
              end
            end
          end
        end

        DONE: begin
          // One-cycle done pulse already asserted when entering DONE
          // Clear internal control
          div_active <= 1'b0;
        end

        default: begin
          // Safety fallback
          state <= IDLE;
        end
      endcase
    end
  end
endmodule