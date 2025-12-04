module list_replacer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  list1_in [0:7],
  input  logic [7:0]  list2_in [0:7],
  input  logic [3:0]  len1_in,
  input  logic [3:0]  len2_in,
  output logic [7:0]  result_out [0:14],
  output logic [3:0]  result_len_out,
  output logic        done
);

  // Temporary signals for next-state computation
  logic [3:0] next_len;
  logic [7:0] next_res [0:14];
  logic       next_done;

  // Compute next state combinatorially
  always_comb begin
    next_len = 4'd0;
    next_done = 1'b0;
    // Initialize result with zeros to avoid unintended latches
    for (int i = 0; i < 15; i++) next_res[i] = 8'd0;

    if (rst_n == 1'b0) begin
      next_len = 4'd0;
      next_done = 1'b0;
    end else begin
      next_done = start;
      if (start) begin
        // Copy first (len1_in - 1) elements from list1_in
        for (int i = 0; i < 15; i++) begin
          if (i < (len1_in - 1)) next_res[i] = list1_in[i];
        end
        // Append all len2_in elements from list2_in
        for (int j = 0; j < 15; j++) begin
          if (j < len2_in) next_res[(len1_in - 1) + j] = list2_in[j];
        end
        // Compute length with truncation to 15
        next_len = (len1_in + len2_in > 15) ? 4'd15 : (len1_in + len2_in - 4'd1);
      end
    end
  end

  // Synchronous update (one cycle after start)
  always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
      result_len_out <= 4'd0;
      done           <= 1'b0;
      for (int k = 0; k < 15; k++) result_out[k] <= 8'd0;
    end else begin
      result_len_out <= next_len;
      done           <= next_done;
      result_out     <= next_res;
    end
  end

endmodule
