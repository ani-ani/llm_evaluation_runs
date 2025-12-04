module top_k_sorted (
  input clk,
  input rst_n,
  input start,            // pulse high to start processing
  input [2:0] arr_size,   // actual array size (1-8)
  input [2:0] k_val,      // k value (1-8, must be <= arr_size)
  input signed [11:0] arr_data [7:0], // 8x12-bit signed integers (range: -2048 to 2047)
  output reg [95:0] result, // flattened 8x12-bit output (sorted list)
  output reg done,        // high when results valid
  output logic valid      // same as done
);

  logic [3:0] cycle, next_cycle;
  logic [3:0] cnt, next_cnt;
  logic [3:0] k_r, next_k_r;
  logic [2:0] arr_size_r, next_arr_size_r;

  logic signed [11:0] topk[8];
  logic signed [11:0] next_topk[8];
  logic signed [11:0] cmp[8];
  logic signed [11:0] next_cmp[8];
  logic [7:0] out_vals, next_out_vals;

  integer i, j;

  // Compare-and-select to maintain top-k largest values
  generate
    genvar gi;
    for (gi = 0; gi < 8; gi = gi + 1) begin : cmp_select
      always @* begin
        // Compare against current top-k element (signed)
        if (topk[gi] > cmp[gi]) begin
          next_cmp[gi] = topk[gi];
        end else begin
          next_cmp[gi] = cmp[gi];
        end
        // Select the larger of the incoming and current candidate (signed)
        if (next_cmp[gi] > arr_data[gi]) begin
          next_topk[gi] = next_cmp[gi];
        end else begin
          next_topk[gi] = arr_data[gi];
        end
      end
    end
  endgenerate

  // Sort the selected k elements (ascending) using simple insertion sort
  always @* begin
    // Bubble-up the current candidate through the existing candidates
    // This keeps next_out_vals in sorted ascending order on each update
    next_out_vals = out_vals;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < k_r) begin
        for (j = i; j > 0; j = j - 1) begin
          if ($signed({4'b0, next_out_vals[j*12 +: 12]}) <
              $signed({4'b0, next_out_vals[(j-1)*12 +: 12]})) begin
            next_out_vals[j*12 +: 12] = next_out_vals[(j-1)*12 +: 12];
            next_out_vals[(j-1)*12 +: 12] = topk[i];
          end else begin
            next_out_vals[j*12 +: 12] = topk[i];
          end
        end
        if (i == 0) next_out_vals[11:0] = topk[i];
      end
    end
    // Zero out the rest of the slots
    for (i = k_r; i < 8; i = i + 1) begin
      next_out_vals[i*12 +: 12] = 12'b0;
    end
  end

  // Control: fixed latency 16 cycles from start
  always @* begin
    next_cycle = cycle + 1'b1;
    next_cnt = cnt + 1'b1;
    next_k_r = k_val;
    next_arr_size_r = arr_size;
    if (rst_n == 1'b0 || start) begin
      next_cycle = 4'b0;
      next_cnt = 4'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 4'b0;
      cnt <= 4'b0;
      k_r <= 4'b0;
      arr_size_r <= 3'b0;
      for (i = 0; i < 8; i = i + 1) begin
        topk[i] <= 12'h800; // very small signed 12-bit value
        cmp[i] <= 12'h800;
      end
      out_vals <= 96'b0;
      result <= 96'b0;
      done <= 1'b0;
      valid <= 1'b0;
    end else begin
      cycle <= next_cycle;
      cnt <= next_cnt;
      k_r <= next_k_r;
      arr_size_r <= next_arr_size_r;
      topk <= next_topk;
      cmp <= next_cmp;
      out_vals <= next_out_vals;
      done <= (cycle == 4'd15);
      valid <= (cycle == 4'd15);
      if (cycle == 4'd15) begin
        result <= {out_vals[95:0]};
      end
    end
  end
endmodule
