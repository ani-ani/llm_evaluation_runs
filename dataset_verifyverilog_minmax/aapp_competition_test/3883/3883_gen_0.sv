module polyline_xfinder(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Pulse high to start computation
  input [23:0] a, // X-coordinate (24-bit unsigned integer)
  input [23:0] b, // Y-coordinate (24-bit unsigned integer)
  output reg [63:0] x, // Q32.32 fixed-point result (32 integer, 32 fractional bits)
  output reg valid // High when result is valid, low when no solution
);

  // Internal signals
  localparam S_IDLE  = 3'b000;
  localparam S_CHECK = 3'b001;
  localparam S_DIVX1 = 3'b010;
  localparam S_DIVX0 = 3'b011;
  localparam S_DONE  = 3'b100;

  reg [2:0] state, next_state;
  reg [5:0] cycle; // 0..63, covers 64 cycles after start

  // Iteration values
  reg [23:0] k0_r, k1_r;     // Floor values
  reg [63:0] denom0, denom1; // 2*k0 and 2*k1 (at most 2^25 - 2, fits 64-bit)
  reg [64:0] ac;             // AC register for restoring division (66 bits is enough; 65 bits used)
  reg [63:0] q_int;          // Integer part of quotient (32 bits used max)
  reg [63:0] div_res;        // Division result in Q32.32
  reg [63:0] x1, x0;         // Candidate results
  reg has_x0, has_x1;        // Validity flags for candidates

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cycle <= 6'd0;
      x     <= 64'h0;
      valid <= 1'b0;
    end else begin
      state <= next_state;
      if (state == S_IDLE) begin
        cycle <= 6'd0;
        x     <= 64'h0;
        valid <= 1'b0;
      end else if (state == S_CHECK) begin
        cycle <= 6'd0;
      end else begin
        cycle <= cycle + 1;
      end

      // Output result at the end of the 64-cycle window
      if (state == S_DONE) begin
        x     <= div_res;
        valid <= 1'b1;
      end else begin
        // valid is cleared/managed in other states where needed
      end
    end
  end

  // FSM combinatorial logic
  always @(*) begin
    // Defaults
    next_state = S_IDLE;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_CHECK;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_CHECK: begin
        // Compute k0, k1 and their denoms; results become available combinatorially in same cycle
        next_state = S_CHECK; // default stay
        // Compute k1 = floor((a+b)/(2*b))
        // Compute k0 = floor((a-b)/(2*b)) if a >= b
        if (b == 24'd0) begin
          next_state = S_DONE; // No solution (division by zero)
        end else begin
          // We know a >= b here for progress beyond CHECK
          k1_r = (a + b) / (2 * b);
          if (a >= b) begin
            k0_r = (a - b) / (2 * b);
          end else begin
            k0_r = 24'd0;
          end
          // Start division for the first candidate (x1)
          if (k1_r > 24'd0) begin
            next_state = S_DIVX1;
          end else begin
            // k1 invalid => no solution
            next_state = S_DONE;
          end
        end
      end

      S_DIVX1: begin
        if (cycle == 6'd63) begin
          // x1 ready, proceed to x0 if possible
          if (has_x0) begin
            next_state = S_DIVX0;
          end else begin
            next_state = S_DONE;
          end
        end else begin
          next_state = S_DIVX1;
        end
      end

      S_DIVX0: begin
        if (cycle == 6'd63) begin
          next_state = S_DONE;
        end else begin
          next_state = S_DIVX0;
        end
      end

      S_DONE: begin
        // Remain here until start deasserted, then return to IDLE
        if (start) begin
          next_state = S_DONE;
        end else begin
          next_state = S_IDLE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Compute k0/k1 and denoms in CHECK state
  assign denom1 = {40'b0, k1_r} << 1; // 2*k1
  assign denom0 = {40'b0, k0_r} << 1; // 2*k0

  // Divider state update (restoring division for 64-bit/64-bit -> Q32.32)
  // Using 65-bit signed AC: {sign, r[63:0]}
  // q holds integer part of the quotient (32 bits used); the remaining 32 bits are the fractional accumulator.
  always @(posedge clk) begin
    if (state == S_CHECK) begin
      // Determine k0/k1 in the same cycle, compute denoms
      if (b == 24'd0) begin
        // Degenerate case: no solution; force invalids
        k0_r   <= 24'd0;
        k1_r   <= 24'd0;
        has_x0 <= 1'b0;
        has_x1 <= 1'b0;
        x1     <= 64'd0;
        x0     <= 64'd0;
        ac     <= 65'd0;
        q_int  <= 64'd0;
        div_res <= 64'd0; // will be treated as invalid in DONE
      end else begin
        // Compute k values (already computed in wire assignments, register them)
        k1_r <= (a + b) / (2 * b);
        if (a >= b) begin
          k0_r <= (a - b) / (2 * b);
        end else begin
          k0_r <= 24'd0;
        end

        // Initialize division for x1
        if (((a + b) / (2 * b)) > 24'd0) begin
          // Start with dividend = (a+b) << 32
          ac    <= {1'b0, {32'b0, a} + {32'b0, b}}; // Partial remainder, high 64 bits
          q_int <= 64'd0;
          has_x1 <= 1'b1;
          has_x0 <= 1'b0; // will be determined after x1
          x1     <= 64'd0;
          x0     <= 64'd0;
          div_res <= 64'd0;
        end else begin
          // k1 invalid, no solution
          has_x1 <= 1'b0;
          has_x0 <= 1'b0;
          x1     <= 64'd0;
          x0     <= 64'd0;
          ac     <= 65'd0;
          q_int  <= 64'd0;
          div_res <= 64'd0;
        end
      end
    end else if (state == S_DIVX1) begin
      // 64 iterations of restoring division
      ac    <= {ac[63:0], 1'b0} - {1'b0, denom1}; // Shift left and subtract
      if (ac[64]) begin
        // Negative, restore
        ac    <= {ac[63:0], 1'b0} + {1'b0, denom1};
        q_int <= {q_int[62:0], 1'b0};
      end else begin
        q_int <= {q_int[62:0], 1'b0} + 1'b1;
      end

      // At the end of iteration 64, finalize x1 and possibly start x0
      if (cycle == 6'd63) begin
        // q_int[31:0] is the integer part; q_int[63:32] is the fractional accumulator
        x1 <= {q_int[31:0], q_int[63:32]};

        // Decide if x0 is possible (k0 > 0 and a >= b)
        if ((k0_r > 24'd0) && (a >= b)) begin
          has_x0 <= 1'b1;
          // Prepare for x0 division: dividend = (a - b) << 32
          ac    <= {1'b0, {32'b0, a} - {32'b0, b}};
          q_int <= 64'd0;
        end else begin
          has_x0 <= 1'b0;
          // No x0; prep div_res = x1 for DONE
          div_res <= {q_int[31:0], q_int[63:32]};
        end
      end
    end else if (state == S_DIVX0) begin
      // 64 iterations of restoring division for x0
      ac    <= {ac[63:0], 1'b0} - {1'b0, denom0};
      if (ac[64]) begin
        // Negative, restore
        ac    <= {ac[63:0], 1'b0} + {1'b0, denom0};
        q_int <= {q_int[62:0], 1'b0};
      end else begin
        q_int <= {q_int[62:0], 1'b0} + 1'b1;
      end

      if (cycle == 6'd63) begin
        x0 <= {q_int[31:0], q_int[63:32]};
        // Final result: min(x0, x1)
        if (has_x1) begin
          // choose min of x0 and x1
          if (has_x0) begin
            if (x0 < x1) div_res <= x0;
            else div_res <= x1;
          end else begin
            div_res <= x1;
          end
        end else begin
          // x0 must be valid here if we reached this state
          div_res <= x0;
        end
      end
    end
  end

  // Handle DONE immediately when no solution is possible in S_CHECK
  // This block clears valid and result to 0 on such cases.
  always @(posedge clk) begin
    if (state == S_DONE) begin
      // If we came to DONE because k1<=0 or b==0, ensure valid is 0 and result is 0
      if (!has_x1 && !has_x0) begin
        x     <= 64'd0;
        valid <= 1'b0;
      end else begin
        // div_res and valid will be set by the sequential output logic
        // but we keep them as-is.
      end
    end
  end

endmodule