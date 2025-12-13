module count_unequal_pairs(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [2:0]  size,
  input  wire [7:0]  arr [7:0],
  output reg  [15:0] count,
  output reg         done
);

  reg [2:0] i;
  reg [2:0] j;
  reg       busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 16'd0;
      done  <= 1'b0;
      i     <= 3'd0;
      j     <= 3'd1;
      busy  <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Initialize for new computation
        count <= 16'd0;
        done  <= 1'b0;
        busy  <= 1'b1;
        if (size < 3'd2) begin
          // No pairs to process
          i    <= 3'd0;
          j    <= 3'd1;
          done <= 1'b1;
          busy <= 1'b0;
        end else begin
          i <= 3'd0;
          j <= 3'd1;
        end
      end else if (busy) begin
        // Process current pair (i,j)
        if (arr[i] != arr[j]) begin
          count <= count + 16'd1;
        end

        // Move to next pair
        if (j + 3'd1 < size) begin
          j <= j + 3'd1;
        end else begin
          if (i + 3'd2 < size) begin
            i <= i + 3'd1;
            j <= i + 3'd2;
          end else begin
            // All pairs processed
            done <= 1'b1;
            busy <= 1'b0;
          end
        end
      end else begin
        // Idle state
        done <= done; // hold
      end
    end
  end

endmodule