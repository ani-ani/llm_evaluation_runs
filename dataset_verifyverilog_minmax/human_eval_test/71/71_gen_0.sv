module triangle_area (
  input clk,
  input rst_n,
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  input start,
  output reg [15:0] area,
  output reg valid,
  output reg error
);
  // State encoding
  localparam S_IDLE   = 3'b000;
  localparam S_VALID  = 3'b001;
  localparam S_MUL1   = 3'b010;
  localparam S_MUL2   = 3'b011;
  localparam S_SQRT   = 3'b100;

  reg [2:0] state, next_state;
  reg [7:0] s_int; // 9-bit s packed in 8 bits (0..255), valid only after S_VALID
  reg [8:0] s_raw; // 9-bit s (a+b+c)/2, unsigned

  // Multiplication stage 1: X = s*(s-a) as signed 17-bit, scaled by 2^-16
  reg signed [16:0] X_q17;

  // Multiplication stage 2: area_sq = X*(s-b)*(s-c) as signed 31-bit, scaled by 2^-32
  reg signed [30:0] area_sq_q31;

  // Sqrt (5 cycles) root/remainder/shift/carry/root_out
  reg [16:0] root;       // current root candidate
  reg [31:0] residue;    // current remainder
  reg [31:0] shifted_residue; // residue << 2 + next_bits
  reg carry;             // next_bits = 0 (0) or 3 (1) for x2.0 + 1.0 = 3.0
  reg [15:0] root_out;   // final Q8.8 area (unsigned), truncated to 8 frac bits

  // Sqrt cycle counter (0..4 over 5 cycles)
  reg [2:0] sqrt_cnt;
  reg doing_sqrt; // flag when in sqrt iteration (1..5)

  // Combinational validation
  wire tri_valid;
  assign tri_valid = (a + b > c) && (a + c > b) && (b + c > a);

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      doing_sqrt <= 1'b0;
      sqrt_cnt <= 3'd0;
    end else begin
      state <= next_state;

      // Sqrt iterator control
      if (next_state == S_SQRT) begin
        doing_sqrt <= 1'b1;
        sqrt_cnt <= 3'd0;
      end else if (doing_sqrt && state == S_SQRT) begin
        // remain in S_SQRT while iterating
        if (sqrt_cnt < 3'd4) begin
          doing_sqrt <= 1'b1;
          sqrt_cnt <= sqrt_cnt + 1'b1;
        end else begin
          doing_sqrt <= 1'b0;
          sqrt_cnt <= 3'd4;
        end
      end else begin
        doing_sqrt <= 1'b0;
        sqrt_cnt <= 3'd0;
      end
    end
  end

  // FSM next-state logic and datapath control
  always @(*) begin
    // Defaults
    next_state = S_IDLE;

    // Latches for multiplies and sqrt seeds (only updated at appropriate cycles)
    X_q17 = 17'sd0;
    area_sq_q31 = 31'sd0;
    root = 16'sd0;
    residue = 32'sd0;
    root_out = 16'sd0;

    // Compute s in idle when no overflow
    s_raw = {1'b0, a} + {1'b0, b} + {1'b0, c}; // 10-bit sum
    s_int = s_raw[8:1]; // (a+b+c)/2, 9-bit -> 8-bit trunc (0..255)

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_VALID;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_VALID: begin
        if (start) begin
          // start again in the same cycle: hold state
          next_state = S_VALID;
        end else begin
          if (tri_valid) begin
            // s is 9-bit; pack into 8-bit s_int (0..255)
            X_q17 = $signed({8'd0, s_int}) * $signed({8'd0, s_int} - {8'd0, a}); // s*(s-a)
            next_state = S_MUL1;
          end else begin
            next_state = S_IDLE; // invalid; will pulse error this cycle
          end
        end
      end

      S_MUL1: begin
        // second multiplication: area_sq = (s)*(s-a)*(s-b)*(s-c)
        // widen to signed 17-bit to avoid overflow (X max fits in 17 bits)
        area_sq_q31 = $signed(X_q17) * $signed({8'd0, s_int} - {8'd0, b});
        area_sq_q31 = area_sq_q31 * $signed({8'd0, s_int} - {8'd0, c});
        next_state = S_MUL2;
      end

      S_MUL2: begin
        // Feed sqrt with top 32 bits of area_sq and remainder lower 32 bits
        // We used signed arithmetic, but area_sq is non-negative for a triangle.
        residue = area_sq_q31[63:32]; // remainder from upper 32 bits (initialize)
        root = 16'sd0;               // seed sqrt
        root_out = 16'sd0;
        next_state = S_SQRT;
      end

      S_SQRT: begin
        // Carry out 5 iterations then return to IDLE
        if (doing_sqrt && (sqrt_cnt < 3'd4)) begin
          // Continue iterations
          next_state = S_SQRT;
        end else begin
          // Last iteration (sqrt_cnt == 4) or about to finish
          next_state = S_IDLE;
        end
        // Pass through values for sqrt iterations
        root = root; // keep; will be updated by sqrt iteration block below
        residue = residue;
        root_out = root_out;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sqrt iteration: fixed-point Newton-like (digit-by-digit) for Q8.8
  // Operates only in S_SQRT across 5 cycles; every cycle, two bits of result are determined
  // start bits: b15,b13,b11,b9 (top 2 bits) and then b7,b5,b3,b1
  always @(posedge clk) begin
    if (state == S_SQRT) begin
      if (sqrt_cnt == 3'd0) begin
        // Bit 15 (MSB of integer 8.8 result)
        shifted_residue = {residue, 31:30}; // append two zeros to left of residue
        carry = (($signed(shifted_residue) >= ($signed({1'b1, 16'd0} << 30)))) ? 1'b1 : 1'b0;
        if (carry) begin
          residue = shifted_residue - ($signed({1'b1, 16'd0} << 30));
          root[15] = 1'b1;
        end else begin
          residue = shifted_residue;
          root[15] = 1'b0;
        end
      end else if (sqrt_cnt == 3'd1) begin
        // Bit 13
        shifted_residue = {residue, 31:30};
        carry = (($signed(shifted_residue) >= ($signed({3'b111, 14'd0} << 28)))) ? 1'b1 : 1'b0;
        if (carry) begin
          residue = shifted_residue - ($signed({3'b111, 14'd0} << 28));
          root[13] = 1'b1;
        end else begin
          residue = shifted_residue;
          root[13] = 1'b0;
        end
      end else if (sqrt_cnt == 3'd2) begin
        // Bit 11
        shifted_residue = {residue, 31:30};
        carry = (($signed(shifted_residue) >= ($signed({5'b11111, 12'd0} << 26)))) ? 1'b1 : 1'b0;
        if (carry) begin
          residue = shifted_residue - ($signed({5'b11111, 12'd0} << 26));
          root[11] = 1'b1;
        end else begin
          residue = shifted_residue;
          root[11] = 1'b0;
        end
      end else if (sqrt_cnt == 3'd3) begin
        // Bit 9
        shifted_residue = {residue, 31:30};
        carry = (($signed(shifted_residue) >= ($signed({7'b1111111, 10'd0} << 24)))) ? 1'b1 : 1'b0;
        if (carry) begin
          residue = shifted_residue - ($signed({7'b1111111, 10'd0} << 24));
          root[9] = 1'b1;
        end else begin
          residue = shifted_residue;
          root[9] = 1'b0;
        end
      end else begin
        // sqrt_cnt == 4: finalize by snapping the remaining 8 fractional bits
        // Equivalent to root_out = (area_sq >> 16) truncated to 16 bits
        // Here we simply capture root with the fractional bits we solved.
        root_out <= {8'd0, 8'd0}; // placeholder, will be replaced next line
        root_out <= {8'd0, 8'd0}; // suppressed by next assign
      end
    end
  end

  // Capture final root (Q8.8, unsigned) at end of sqrt; also compute fractional bits from residue by fast finish
  always @(posedge clk) begin
    if (state == S_SQRT && sqrt_cnt == 3'd4) begin
      // Fast finish: take integer part from root, fractional from residue>>16
      // Integer part of sqrt is already in root[15:8]; fractional part is residue >> 16 (8 bits)
      root_out <= {root[15:8], residue[31:24]};
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      area  <= 16'd0;
      valid <= 1'b0;
      error <= 1'b0;
    end else begin
      error <= 1'b0; // default
      valid <= 1'b0; // default

      if (state == S_VALID) begin
        if (start) begin
          // Start pulse while in VALID: show error pulse if needed
          error <= ~tri_valid;
          area  <= 16'hFFFF; // present -1.0 in Q8.8 on invalid start pulse
          valid <= 1'b0;
        end else begin
          if (tri_valid) begin
            // Move to compute
            area  <= 16'd0;  // don't care during compute
            valid <= 1'b0;
            error <= 1'b0;
          end else begin
            // First cycle after a start that was invalid
            area  <= 16'hFFFF; // -1.0 in Q8.8
            valid <= 1'b0;
            error <= 1'b1;     // pulse error for 1 cycle
          end
        end
      end else if (state == S_MUL1) begin
        // During multiplies, keep area from changing (0)
        area  <= 16'd0;
        valid <= 1'b0;
        error <= 1'b0;
      end else if (state == S_MUL2) begin
        area  <= 16'd0;
        valid <= 1'b0;
        error <= 1'b0;
      end else if (state == S_SQRT) begin
        // During sqrt iterations, still not valid
        area  <= 16'd0;
        valid <= 1'b0;
        error <= 1'b0;
      end else if (state == S_IDLE) begin
        // If last state was sqrt, and we have a valid result, output it
        if (doing_sqrt && (sqrt_cnt == 3'd4)) begin
          area  <= root_out; // Q8.8 result, truncated to 8 fractional bits
          valid <= 1'b1;
          error <= 1'b0;
        end else begin
          // Idle otherwise
          area  <= 16'd0;
          valid <= 1'b0;
          error <= 1'b0;
        end
      end else begin
        area  <= 16'd0;
        valid <= 1'b0;
        error <= 1'b0;
      end
    end
  end
endmodule