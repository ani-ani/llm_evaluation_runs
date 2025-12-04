module largest_prime_factor(clk, rst_n, start, n, result, done);
  input clk;
  input rst_n;
  input start;
  input [15:0] n;
  output reg [15:0] result;
  output reg done;

  reg [1:0] state;
  localparam IDLE        = 2'b00;
  localparam PROCESSING  = 2'b01;
  localparam DONE_STATE  = 2'b10;

  reg [15:0] current;
  reg [15:0] divisor;

  wire [31:0] divisor_sq = divisor * divisor;
  wire no_divisor = divisor_sq > current;
  wire divisible = (current % divisor == 0);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'b0;
      current <= 16'b0;
      divisor <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current <= n;
            divisor <= 16'd2;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          if (no_divisor) begin
            result <= current;
            done <= 1'b1;
            state <= DONE_STATE;
          end else if (divisible) begin
            current <= current / divisor;
          end else begin
            divisor <= (divisor == 16'd2) ? 16'd3 : divisor + 16'd2;
          end
        end

        DONE_STATE: begin
          done <= 1'b0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule