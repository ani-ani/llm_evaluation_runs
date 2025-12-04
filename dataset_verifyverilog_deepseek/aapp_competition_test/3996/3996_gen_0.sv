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

  localparam [31:0] mod = 32'd1000000007;
  localparam [31:0] mod_phi = 32'd1000000006;
  localparam [31:0] inv2 = 32'd500000004;
  localparam [31:0] inv3 = 32'd333333336;

  typedef enum {IDLE, PROCESS, MOD_EXP, DONE} state_t;
  state_t state;

  reg [3:0] counter;
  reg [31:0] exp_prod;
  reg parity;
  reg [31:0] temp_beta;
  reg [31:0] temp_alpha;

  function automatic [31:0] mod_exp;
    input [31:0] base;
    input [31:0] exponent;
    input [31:0] modulus;
    reg [63:0] result, b;
    integer i;
    begin
      result = 1;
      b = base % modulus;
      for (i = 0; i < 32; i = i + 1) begin
        if (exponent[i]) begin
          result = (result * b) % modulus;
        end
        b = (b * b) % modulus;
      end
      mod_exp = result;
    end
  endfunction

  function automatic [31:0] mod_mul;
    input [31:0] a;
    input [31:0] b;
    input [31:0] modulus;
    reg [63:0] product;
    begin
      product = a * b;
      mod_mul = product % modulus;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      p <= 0;
      q <= 0;
      done <= 0;
      exp_prod <= 0;
      parity <= 0;
      counter <= 0;
      temp_beta <= 0;
      temp_alpha <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          p <= 0;
          q <= 0;
          if (start) begin
            state <= PROCESS;
            exp_prod <= 1;
            parity <= 0;
            counter <= 0;
          end
        end

        PROCESS: begin
          if (counter < k) begin
            exp_prod <= mod_mul(exp_prod, a[counter], mod_phi);
            if (a[counter][0] == 0) begin
              parity <= 1;
            end
            counter <= counter + 1;
          end else begin
            state <= MOD_EXP;
          end
        end

        MOD_EXP: begin
          temp_beta <= mod_mul(mod_exp(32'd2, exp_prod, mod), inv2, mod);
          temp_alpha <= mod_mul((temp_beta + (parity ? 32'd1 : mod - 1)) % mod, inv3, mod);
          state <= DONE;
        end

        DONE: begin
          p <= temp_alpha;
          q <= temp_beta;
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule