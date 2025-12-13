module resistance_calculator(
  input clk,                    // system clock
  input rst_n,                  // active-low reset
  input start,                  // pulse high to start computation
  input [15:0] a,               // numerator (1 ≤ a ≤ 65535)
  input [15:0] b,               // denominator (1 ≤ b ≤ 65535)
  output reg [15:0] result,     // minimum resistor count
  output reg done               // high when computation completes
);

  // Internal registers
  reg [15:0] x;
  reg [15:0] y;
  reg [31:0] count;            // Wider to prevent overflow during accumulation
  reg [1:0] state;

  localparam IDLE = 2'd0;
  localparam RUN  = 2'd1;
  localparam DONE = 2'd2;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      x      <= 16'd0;
      y      <= 16'd0;
      count  <= 32'd0;
      result <= 16'd0;
      done   <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            x     <= a;
            y     <= b;
            count <= 32'd0;
            state <= RUN;
          end
        end

        RUN: begin
          if (y != 16'd0) begin
            // Perform one Euclidean-like iteration per cycle
            count <= count + (x / y);
            // Swap and reduce
            x <= y;
            y <= x % y;
          end else begin
            // Computation complete
            result <= (count > 16'hFFFF) ? 16'hFFFF : count[15:0];
            done   <= 1'b1;
            state  <= DONE;
          end
        end

        DONE: begin
          // Hold result and done high until next start
          if (start) begin
            done  <= 1'b0;
            x     <= a;
            y     <= b;
            count <= 32'd0;
            state <= RUN;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule