module perfect_squares(
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  output reg [7:0] square_out,
  output reg valid,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // State variables
  reg [1:0] state;
  reg [7:0] a_reg, b_reg;
  reg [7:0] j;
  reg [15:0] current_square;

  // Calculate next square using recurrence: (j+1)^2 = j^2 + 2*j + 1
  wire [15:0] next_square = current_square + (j << 1) + 1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all outputs and state
      state <= IDLE;
      square_out <= 8'b0;
      valid <= 1'b0;
      done <= 1'b0;
      a_reg <= 8'b0;
      b_reg <= 8'b0;
      j <= 8'b0;
      current_square <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          valid <= 1'b0;
          if (start) begin
            // Load inputs and initialize for processing
            a_reg <= a;
            b_reg <= b;
            j <= 8'd1;
            current_square <= 16'd1;  // 1*1
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          // Check if current square is in valid range
          if (current_square >= a_reg && current_square <= b_reg) begin
            square_out <= current_square[7:0];
            valid <= 1'b1;
          end else begin
            valid <= 1'b0;
          end

          // Update for next iteration
          j <= j + 1;
          current_square <= next_square;

          // Check if we've exceeded the upper bound
          if (next_square > b_reg) begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          valid <= 1'b0;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
          done <= 1'b0;
          valid <= 1'b0;
        end
      endcase
    end
  end

endmodule