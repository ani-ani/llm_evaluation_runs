module is_prime(input clk, input rst_n, input start, input [15:0] n, output reg ready, output reg is_prime);
  typedef enum logic {IDLE, CHECK} state_t;
  state_t state;
  reg [15:0] n_reg;
  reg [7:0] divisor;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ready <= 1'b1;
      is_prime <= 1'b0;
      n_reg <= 16'b0;
      divisor <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            if (n < 16'd2) begin
              is_prime <= 1'b0;
              ready <= 1'b1;
            end else if (n == 16'd2) begin
              is_prime <= 1'b1;
              ready <= 1'b1;
            end else begin
              ready <= 1'b0;
              divisor <= 8'd2;
              state <= CHECK;
            end
          end else begin
            ready <= 1'b1;
          end
        end
        CHECK: begin
          if ((divisor * divisor) > n_reg) begin
            is_prime <= 1'b1;
            ready <= 1'b1;
            state <= IDLE;
          end else if ((n_reg % divisor) == 16'd0) begin
            is_prime <= 1'b0;
            ready <= 1'b1;
            state <= IDLE;
          end else begin
            if (divisor == 8'd2) begin
              divisor <= 8'd3;
            end else begin
              divisor <= divisor + 8'd2;
            end
            state <= CHECK;
            ready <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule