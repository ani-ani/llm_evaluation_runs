module cup_probability(
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [15:0] a [0:7],
  output reg [31:0] p,
  output reg [31:0] q,
  output reg done
);

  // Constants
  localparam MOD = 32'd1000000007;
  localparam INV2 = 32'd500000004;
  localparam INV3 = 32'd333333336;
  localparam MOD_MINUS_1 = 32'd1000000006;

  // State machine
  reg [3:0] state;
  reg [3:0] cnt; // counter for exponent processing
  reg [31:0] exponent_mod; // product of exponents modulo (MOD-1)
  reg any_even;
  reg [31:0] temp1, temp2; // temporary for modular step
  reg [31:0] beta, alpha; // results

  // State encoding
  localparam IDLE = 4'd0;
  localparam INIT = 4'd1;
  localparam EXP_PROCESS = 4'd2;
  localparam MOD_STEP = 4'd3;
  localparam OUTPUT = 4'd4;

  // Function for modular exponentiation (combinational)
  function [31:0] modpow;
    input [29:0] exp; // 30-bit exponent
    reg [31:0] result;
    reg [31:0] base;
    integer i;
    begin
      result = 1;
      base = 2;
      for (i = 0; i < 30; i++) begin
        if (exp[i])
          result = (result * base) % MOD;
        base = (base * base) % MOD;
      end
      modpow = result;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || !start) begin
      state <= IDLE;
      p <= 0;
      q <= 0;
      done <= 0;
      cnt <= 0;
      exponent_mod <= 0;
      any_even <= 0;
      beta <= 0;
      alpha <= 0;
    end else begin
      case (state)
        IDLE: begin
          p <= 0;
          q <= 0;
          done <= 0;
          if (start) begin
            state <= INIT;
            cnt <= 0;
            exponent_mod <= 1;
            any_even <= 0;
          end
        end
        
        INIT: begin
          state <= EXP_PROCESS;
        end
        
        EXP_PROCESS: begin
          if (cnt < k) begin
            // Check if a[cnt] is even
            if (a[cnt][0] == 0) // LSB 0 means even
              any_even <= 1;
            
            // Multiply and take modulo (MOD-1)
            reg [63:0] temp_mul = exponent_mod * a[cnt];
            exponent_mod <= temp_mul % MOD_MINUS_1;
            cnt <= cnt + 1;
            state <= EXP_PROCESS; // stay for next exponent
          end else begin
            state <= MOD_STEP;
          end
        end
        
        MOD_STEP: begin
          // Compute beta = (2^(exponent_mod) / 2) mod MOD
          temp1 <= modpow(exponent_mod[29:0]);
          beta <= (temp1 * INV2) % MOD;
          
          // Compute alpha = (beta + parity_flag) * inv3 mod MOD
          if (any_even)
            temp2 <= beta + 1; // parity_flag = 1
          else
            temp2 <= beta + MOD - 1; // parity_flag = -1 mod MOD
          
          alpha <= (temp2 * INV3) % MOD;
          state <= OUTPUT;
        end
        
        OUTPUT: begin
          p <= alpha;
          q <= beta;
          done <= 1;
          if (!start)
            state <= IDLE;
          // else stay in OUTPUT
        end
        
        default: state <= IDLE;
      endcase
    end
  end
endmodule