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

  reg [7:0]  i;
  reg [7:0]  j;
  reg        dir;       // 1: RIGHT, 0: LEFT
  reg [15:0] step;
  reg        active;

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count  <= 16'd0;
      done   <= 1'b0;
      i      <= 8'd0;
      j      <= 8'd0;
      dir    <= 1'b1;   // RIGHT
      step   <= 16'd0;
      active <= 1'b0;
    end else begin
      // Handle start: highest priority when not active or to restart
      if (start) begin
        count  <= 16'd0;
        done   <= 1'b0;
        i      <= 8'd0;
        j      <= 8'd0;
        dir    <= 1'b1; // RIGHT
        step   <= 16'd0;
        active <= 1'b1;
      end else if (active && !done) begin
        // If already completed K steps, assert done and stop
        if (step == K) begin
          done   <= 1'b1;
          active <= 1'b0;
        end else begin
          // Check current cell grey condition: (i & j) == 0
          if ((i & j) == 8'd0) begin
            count <= count + 16'd1;
          end

          // Increment step
          step <= step + 16'd1;

          // Move to next cell in zig-zag (only if not yet at K after this step)
          // Direction: 1=RIGHT, 0=LEFT
          if (dir) begin
            // Moving RIGHT
            if (j < (C - 1)) begin
              j <= j + 8'd1;
            end else begin
              // Reached right boundary, go down and switch direction
              if (i < (R - 1)) begin
                i <= i + 8'd1;
              end
              dir <= 1'b0; // switch to LEFT
            end
          end else begin
            // Moving LEFT
            if (j > 8'd0) begin
              j <= j - 8'd1;
            end else begin
              // Reached left boundary, go down and switch direction
              if (i < (R - 1)) begin
                i <= i + 8'd1;
              end
              dir <= 1'b1; // switch to RIGHT
            end
          end
        end
      end
    end
  end

endmodule