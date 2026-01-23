module optimal_probability (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [7:0] p_in,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] INPUT = 2'b01;
  localparam [1:0] PROCESS = 2'b10;
  localparam [1:0] DONE = 2'b11;

  reg [1:0] state = IDLE;
  reg [3:0] count = 0;
  reg [31:0] prod = 32'hFFFFFFFF; // Q16.16: 1.0
  reg [31:0] sum = 32'h00000000; // Q16.16: 0.0
  reg [31:0] max_prob = 32'h00000000; // Q16.16: 0.0

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      prod <= 32'hFFFFFFFF;
      sum <= 32'h00000000;
      max_prob <= 32'h00000000;
      result <= 32'h00000000;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INPUT;
            count <= 0;
            prod <= 32'hFFFFFFFF;
            sum <= 32'h00000000;
            max_prob <= 32'h00000000;
          end
        end
        INPUT: begin
          if (count < n) begin
            // Convert p_in from Q8.8 to Q16.16
            reg [31:0] p_q16 = {16'h0000, p_in};
            reg [31:0] one_minus_p = 32'hFFFFFFFF - p_q16;

            // Update sum and prod
            reg [31:0] new_sum = (sum * one_minus_p) + (prod * p_q16);
            reg [31:0] new_prod = prod * one_minus_p;

            sum <= new_sum;
            prod <= new_prod;

            // Track maximum probability
            if (new_sum > max_prob) begin
              max_prob <= new_sum;
            end

            count <= count + 1;
          end else begin
            state <= PROCESS;
          end
        end
        PROCESS: begin
          state <= DONE;
          result <= max_prob;
        end
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule