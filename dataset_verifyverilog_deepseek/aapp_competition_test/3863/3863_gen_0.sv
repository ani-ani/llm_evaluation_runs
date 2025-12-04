module palindromic_sequence_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] N,
  input [15:0] K,
  output reg [31:0] result,
  output reg done
);

parameter MOD = 32'd1000000007;
localparam DIV_LIMIT = 32;

typedef enum logic [1:0] {IDLE, FIND_DIVS, PROCESS_DIV, COMPLETE} state_t;
state_t state;

reg [15:0] divisors[0:DIV_LIMIT-1];
reg [31:0] terms[0:DIV_LIMIT-1];
reg [5:0] div_count;
reg [5:0] process_ctr;
reg [31:0] result_reg;

reg [5:0] d_found;
wire [15:0] div_i = d_found;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    result <= 32'd0;
    result_reg <= 32'd0;
    div_count <= 6'd0;
    process_ctr <= 6'd0;
    d_found <= 6'd1;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        result_reg <= 32'd0;
        process_ctr <= 6'd0;
        d_found <= 6'd1;
        if (start) begin
          state <= FIND_DIVS;
          div_count <= 6'd0;
        end
      end

      FIND_DIVS: begin
        if (div_i <= N && d_found[5] == 1'b0) begin
          if ((N % div_i) == 0 && div_count < DIV_LIMIT) begin
            divisors[div_count] <= div_i;
            div_count <= div_count + 1;
          end
          d_found <= d_found + 1;
        end else begin
          state <= PROCESS_DIV;
          process_ctr <= 6'd0;
        end
      end

      PROCESS_DIV: begin
        if (process_ctr < div_count) begin
          automatic logic [15:0] d = divisors[process_ctr];
          automatic logic [31:0] power_term = 1;
          automatic logic [31:0] sum_prev = 32'd0;
          for (int j=0; j<process_ctr; j++) begin
            if ((d % divisors[j]) == 0)
              sum_prev = (sum_prev + terms[j]) % MOD;
          end
          for (int i=0; i<(d+1)>>1; i++)
            power_term = (power_term * K) % MOD;
          terms[process_ctr] <= (power_term - sum_prev + MOD) % MOD;
          if (d[0]) // odd
            result_reg <= (result_reg + (((d % MOD) * ((power_term - sum_prev + MOD) % MOD)) % MOD)) % MOD;
          else // even
            result_reg <= (result_reg + ((((d/2) % MOD) * ((power_term - sum_prev + MOD) % MOD)) % MOD)) % MOD;
          process_ctr <= process_ctr + 1;
        end else begin
          state <= COMPLETE;
          done <= 1'b1;
          result <= result_reg;
        end
      end

      COMPLETE: begin
        if (!start)
          state <= IDLE;
      end
    endcase
  end
end

endmodule