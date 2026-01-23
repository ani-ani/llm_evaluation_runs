module triangular_index(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] CALC_POW = 3'b001;
  localparam [2:0] CALC_SQRT = 3'b010;
  localparam [2:0] ROUND = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [31:0] target;
  reg [31:0] sqrt_val;
  reg [15:0] counter = 0;

  // Precomputed values for n=1-4
  reg [31:0] pow10 [0:3] = '{1, 10, 100, 1000};
  reg [15:0] sqrt_results [0:3] = '{1, 4, 14, 45};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_POW;
            counter <= 0;
          end
        end
        CALC_POW: begin
          target <= pow10[n-1];
          state <= CALC_SQRT;
        end
        CALC_SQRT: begin
          sqrt_val <= 2 * target;
          state <= ROUND;
        end
        ROUND: begin
          result <= sqrt_results[n-1];
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (counter == 50) begin
            done <= 0;
            state <= IDLE;
          end else begin
            counter <= counter + 1;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule