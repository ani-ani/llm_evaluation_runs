module frequency_counter (
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start processing
  input [3:0][3:0][7:0] list1, // 4 sublists of 4 elements each (8-bit values)
  input [7:0] query_num, // number to query frequency for
  output reg [3:0] frequency, // count for query_num (0-15)
  output reg done // high when processing complete
);

  // 256 x 4 register file (counts clamped to 4 bits: 0-15)
  logic [3:0] mem [256];

  // Flatten list1 (4x4) into a 12-element array
  logic [7:0] flat [12];
  integer i, j;
  always_comb begin
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        flat[i*4 + j] = list1[i][j];
      end
    end
  end

  // Sequential control
  reg [3:0] cycle;
  reg processing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 4'd0;
      processing <= 1'b0;
      done <= 1'b0;
    end else begin
      if (start && !processing) begin
        // Begin processing
        cycle <= 4'd0;
        processing <= 1'b1;
        done <= 1'b0;
      end else if (processing) begin
        if (cycle < 4'd15) begin
          cycle <= cycle + 1;
        end else begin
          // Completed 16 cycles (cycle=15 indicates last active cycle)
          cycle <= 4'd0;
          processing <= 1'b0;
          done <= 1'b1;
        end
      end else begin
        // Idle
        cycle <= 4'd0;
        done <= 1'b0;
      end
    end
  end

  // Counting over exactly 16 cycles: only first 12 cycles modify counts
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Clear register file
      for (integer k = 0; k < 256; k = k + 1) mem[k] <= 4'd0;
    end else begin
      if (processing) begin
        if (cycle < 4'd12) begin
          automatic logic [7:0] val = flat[cycle];
          if (mem[val] != 4'd15) mem[val] <= mem[val] + 1;
        end
      end
    end
  end

  // Combinational read for query mode when done=1
  always_comb begin
    if (done) frequency = mem[query_num];
    else frequency = 4'd0;
  end

endmodule
