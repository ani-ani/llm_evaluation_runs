module dance_complexity (
  input clk,
  input rst_n,
  input start,
  input [7:0] x_mask,
  input [2:0] n,
  output reg [31:0] result,
  output reg done
);

  parameter MOD = 1000000007;
  parameter IDLE = 2'b00;
  parameter CALCULATE = 2'b01;
  parameter DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [3:0] bit_pos = 0;
  reg [31:0] current_term = 0;
  reg [31:0] pow4_table [0:7];
  reg [31:0] temp = 0;
  reg [31:0] exponent = 0;
  reg [31:0] base = 4;
  reg [31:0] pow_result = 1;
  reg [3:0] count = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      bit_pos <= 0;
      result <= 0;
      done <= 0;
      count <= 0;
      pow_result <= 1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            bit_pos <= 0;
            result <= 0;
            done <= 0;
            count <= 0;
            pow_result <= 1;
          end
        end
        CALCULATE: begin
          if (count < 10) begin
            if (bit_pos < n) begin
              if (x_mask[7 - bit_pos]) begin
                exponent <= (n - bit_pos - 1);
                temp <= 1 << bit_pos;
                if (exponent == 0) begin
                  current_term <= temp;
                end else begin
                  pow_result <= 1;
                  for (int i = 0; i < exponent; i = i + 1) begin
                    pow_result <= (pow_result * base) % MOD;
                  end
                  current_term <= (temp * pow_result) % MOD;
                end
                result <= (result + current_term) % MOD;
              end
              bit_pos <= bit_pos + 1;
            end else begin
              state <= DONE;
            end
          end else begin
            state <= DONE;
          end
          count <= count + 1;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule