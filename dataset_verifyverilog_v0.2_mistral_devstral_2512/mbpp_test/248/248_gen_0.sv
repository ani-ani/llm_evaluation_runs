module harmonic_sum(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] CALCULATE = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [31:0] accumulator;
  reg [4:0] counter;

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      accumulator <= 32'b0;
      counter <= 5'b0;
      result <= 32'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            accumulator <= 32'd65536; // 1.0 in Q16.16
            counter <= 5'd1;
            done <= 1'b0;
          end
        end

        CALCULATE: begin
          if (counter < n - 1) begin
            // Compute 1/(counter+1) as 65536/(counter+1)
            accumulator <= accumulator + (32'd65536 / (counter + 1));
            counter <= counter + 1;
          end else begin
            state <= DONE;
            result <= accumulator;
            done <= 1'b1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule