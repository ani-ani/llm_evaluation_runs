module modp_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] n,
  input  [15:0] p,
  output reg [15:0] result,
  output reg done
);

  // Internal registers
  reg [15:0] base_reg;       // Holds base (2 mod p)
  reg [15:0] p_reg;          // Latched modulus
  reg [15:0] result_reg;     // Working result
  reg [15:0] n_reg;          // Latched exponent
  reg [4:0]  bit_index;      // 0..15
  reg        busy;           // Indicates active computation

  // Internal wires for arithmetic
  reg [31:0] sq_mult;        // result_reg^2
  reg [31:0] sq_mod;         // (result_reg^2) mod p_reg
  reg [31:0] mul_mult;       // (sq_mod * base_reg)
  reg [31:0] mul_mod;        // (sq_mod * base_reg) mod p_reg
  reg [15:0] next_result;    // Next result based on bit

  // Combinational modular arithmetic
  always @* begin
    // Square step: result_reg^2 mod p_reg
    sq_mult = result_reg * result_reg;
    if (p_reg != 16'd0)
      sq_mod = sq_mult % p_reg;
    else
      sq_mod = sq_mult[15:0];

    // Multiply-by-base (2 mod p) step when current bit is 1
    mul_mult = sq_mod[15:0] * base_reg;
    if (p_reg != 16'd0)
      mul_mod = mul_mult % p_reg;
    else
      mul_mod = mul_mult[15:0];

    // Select next_result based on current bit of exponent
    if (n_reg[15 - bit_index])
      next_result = mul_mod[15:0];
    else
      next_result = sq_mod[15:0];
  end

  // Sequential control and state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result      <= 16'd0;
      done        <= 1'b0;
      base_reg    <= 16'd0;
      p_reg       <= 16'd0;
      result_reg  <= 16'd0;
      n_reg       <= 16'd0;
      bit_index   <= 5'd0;
      busy        <= 1'b0;
    end else begin
      // Default done low each cycle
      done <= 1'b0;

      if (!busy) begin
        if (start) begin
          // Latch inputs and initialize
          p_reg      <= p;
          n_reg      <= n;
          result_reg <= 16'd1;                // result = 1
          // base = 2 mod p (with p >= 2 per spec)
          if (p != 16'd0)
            base_reg <= (16'd2 % p);
          else
            base_reg <= 16'd2;
          bit_index <= 5'd0;
          busy      <= 1'b1;
        end
      end else begin
        // Busy: perform one bit iteration per cycle
        result_reg <= next_result;

        if (bit_index == 5'd15) begin
          // Final cycle: produce output and finish
          result    <= next_result;
          done      <= 1'b1;
          busy      <= 1'b0;
        end

        // Increment bit index (wrap is irrelevant once busy deasserts)
        bit_index <= bit_index + 5'd1;
      end
    end
  end

endmodule