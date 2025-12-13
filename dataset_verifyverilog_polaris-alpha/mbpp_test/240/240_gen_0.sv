module list_replacer (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  list1_in [7:0],
  input  logic [7:0]  list2_in [7:0],
  input  logic [3:0]  len1_in,
  input  logic [3:0]  len2_in,
  output logic [7:0]  result_out [7:0],
  output logic [3:0]  result_len_out,
  output logic        done
);

  logic [3:0] computed_len;
  logic [7:0] next_result [7:0];
  integer i;
  integer out_index;

  // Combinational logic to compute next_result and computed_len
  always_comb begin
    // Default assignments
    for (i = 0; i < 8; i = i + 1) begin
      next_result[i] = 8'd0;
    end

    // Compute tentative length: (len1_in - 1) + len2_in
    automatic int temp_len;
    temp_len = (len1_in > 0) ? (len1_in - 1 + len2_in) : 0;

    if (temp_len > 15)
      computed_len = 4'd15;
    else
      computed_len = temp_len[3:0];

    out_index = 0;

    // 1) Copy list1_in[0 .. len1_in-2]
    if (len1_in > 0) begin
      for (i = 0; i < 8; i = i + 1) begin
        if ((i < (len1_in - 1)) && (out_index < 8) && (out_index < computed_len)) begin
          next_result[out_index] = list1_in[i];
          out_index = out_index + 1;
        end
      end
    end

    // 2) Append list2_in[0 .. len2_in-1]
    for (i = 0; i < 8; i = i + 1) begin
      if ((i < len2_in) && (out_index < 8) && (out_index < computed_len)) begin
        next_result[out_index] = list2_in[i];
        out_index = out_index + 1;
      end
    end
  end

  // Sequential logic for outputs and done signaling
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset: clear outputs
      result_len_out <= 4'd0;
      done           <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        result_out[i] <= 8'd0;
      end
    end else begin
      // done is asserted one cycle after start
      done <= start;

      if (start) begin
        // Capture combinational results in one cycle
        result_len_out <= computed_len;
        for (i = 0; i < 8; i = i + 1) begin
          result_out[i] <= next_result[i];
        end
      end
    end
  end

endmodule