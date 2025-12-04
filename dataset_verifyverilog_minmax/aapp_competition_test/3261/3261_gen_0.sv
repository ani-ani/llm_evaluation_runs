module grey_cell_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] R,
  input [7:0] C,
  input [15:0] K,
  output reg [15:0] count,
  output reg done
);

  // Internal state
  reg [15:0] step;
  reg [7:0] i;
  reg [7:0] j;
  reg       direction; // 1=right, 0=left

  // Traversal state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count      <= 16'h0;
      done       <= 1'b0;
      step       <= 16'h0;
      i          <= 8'h0;
      j          <= 8'h0;
      direction  <= 1'b1; // right
    end else begin
      // Start a new traversal
      if (start) begin
        count      <= 16'h0;
        done       <= 1'b0;
        step       <= 16'h0;
        i          <= 8'h0;
        j          <= 8'h0;
        direction  <= 1'b1; // start moving right
      end else if (!done) begin
        // Evaluate current cell (i, j)
        if ((i & j) == 8'h0) begin
          count <= count + 1;
        end

        // Advance step
        step <= step + 1;

        // Check if target steps reached after processing current cell
        if (step == K) begin
          done <= 1'b1;
          // Hold position and step constant when done
        end else begin
          // Move to next cell (zig-zag)
          if (direction == 1'b1) begin
            // Moving right
            if (j < (C - 1)) begin
              j <= j + 1;
            end else begin
              // Right edge reached: move down a row and reverse direction
              i <= i + 1;
              direction <= 1'b0;
            end
          end else begin
            // Moving left
            if (j > 8'h0) begin
              j <= j - 1;
            end else begin
              // Left edge reached: move down a row and reverse direction
              i <= i + 1;
              direction <= 1'b1;
            end
          end
        end
      end
    end
  end

endmodule