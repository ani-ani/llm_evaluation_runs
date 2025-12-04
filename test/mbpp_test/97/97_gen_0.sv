module frequency_counter (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0][3:0][7:0] list1,
  input  [7:0] query_num,
  output reg [3:0] frequency,
  output reg done
);

  // Internal storage: 256 x 4-bit counter array
  reg [3:0] count_mem [0:255];

  // Index for 16 elements (0..15)
  reg [4:0] idx;

  // Control flag to indicate active processing
  reg processing;

  // Flattened element from list1 based on idx
  wire [7:0] curr_val;

  // Map idx[3:0] -> list1[outer][inner]
  // outer = idx[3:2], inner = idx[1:0]
  assign curr_val = list1[idx[3:2]][idx[1:0]];

  integer i;

  // Sequential logic for reset, start/processing, and counting
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset: clear all state
      for (i = 0; i < 256; i = i + 1) begin
        count_mem[i] <= 4'd0;
      end
      idx        <= 5'd0;
      processing <= 1'b0;
      done       <= 1'b0;
    end else begin
      if (!processing) begin
        // Idle state
        done <= 1'b0;
        if (start) begin
          // Initialize for new counting operation
          for (i = 0; i < 256; i = i + 1) begin
            count_mem[i] <= 4'd0;
          end
          idx        <= 5'd0;
          processing <= 1'b1;
        end
      end else begin
        // Processing state: count one element per cycle
        // Increment count for current value
        count_mem[curr_val] <= count_mem[curr_val] + 4'd1;

        if (idx == 5'd15) begin
          // Completed 16 elements
          processing <= 1'b0;
          done       <= 1'b1;
        end

        idx <= idx + 5'd1;
      end
    end
  end

  // Combinational query: valid when done=1
  always @(*) begin
    if (done) begin
      frequency = count_mem[query_num];
    end else begin
      frequency = 4'd0;
    end
  end

endmodule