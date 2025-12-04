module even_power_sum (
  input clk,
  input rst_n,
  input [4:0] n,
  input start,
  output reg [29:0] sum,
  output reg done
);

  // State encoding
  parameter IDLE = 2'b00;
  parameter RUN  = 2'b01;
  parameter DONE = 2'b10;

  // State variable
  reg [1:0] state;

  // Counter and accumulator
  reg [4:0] i;
  reg [29:0] running_sum;

  // Lookup table for terms: 32 * (i^5)
  reg [29:0] term_table [0:31];
  genvar k;
  for (k=0; k<=31; k=k+1) begin : term_table_gen
    assign term_table[k] = (k * k * k * k * k) * 32;
  end

  // Combinational term for current i
  reg [29:0] term;
  always_comb begin
    term = term_table[i];
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      running_sum <= 0;
      sum <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RUN;
            i <= 1;
            running_sum <= 0;
          end
        end

        RUN: begin
          running_sum <= running_sum + term;
          i <= i + 1;
          if (i == n) begin
            sum <= running_sum + term;
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          if (start) begin
            state <= RUN;
            i <= 1;
            running_sum <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule