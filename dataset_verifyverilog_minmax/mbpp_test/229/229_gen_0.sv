module rearrange_neg_pos(
  input clk,
  input rst_n,
  input start,
  input reg [3:0] n,
  input reg [15:0][7:0] arr_in,
  output reg [15:0][7:0] arr_out,
  output reg done
);

  // Internal signals
  reg [4:0] idx; // counts 0..15 over 16 cycles
  reg [4:0] neg_cnt, pos_cnt;
  reg neg_valid, pos_valid;
  reg [3:0] neg_valid_cnt, pos_valid_cnt;

  // Temporary storage for rearrangement
  reg [15:0][7:0] tmp_neg, tmp_pos;
  reg [3:0] neg_total, pos_total;
  reg [3:0] neg_total_q, pos_total_q;

  // Determine how many negatives/positives will be in the first n elements
  always_comb begin
    neg_total = 0;
    pos_total = 0;
    for (int i = 0; i < 16; i++) begin
      if (i < n) begin
        if ($signed(arr_in[i]) < 0) neg_total++;
        else pos_total++;
      end
    end
  end

  // Latch counts at the start of processing
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      neg_total_q <= '0;
      pos_total_q <= '0;
    end else if (start) begin
      neg_total_q <= neg_total;
      pos_total_q <= pos_total;
    end
  end

  // Fill tmp arrays during processing (exactly 16 cycles after start)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx <= '0;
      neg_cnt <= '0;
      pos_cnt <= '0;
      neg_valid <= 1'b0;
      pos_valid <= 1'b0;
      neg_valid_cnt <= '0;
      pos_valid_cnt <= '0;
      tmp_neg <= '0;
      tmp_pos <= '0;
    end else if (start) begin
      idx <= 5'd0;
      neg_cnt <= 5'd0;
      pos_cnt <= 5'd0;
      neg_valid <= 1'b0;
      pos_valid <= 1'b0;
      neg_valid_cnt <= 4'd0;
      pos_valid_cnt <= 4'd0;
      tmp_neg <= '0;
      tmp_pos <= '0;
    end else begin
      if (idx < 5'd15) begin
        idx <= idx + 1;
        if (idx < n) begin
          if ($signed(arr_in[idx]) < 0) begin
            tmp_neg[neg_cnt] <= arr_in[idx];
            neg_cnt <= neg_cnt + 1;
            neg_valid_cnt <= neg_valid_cnt + 1;
            neg_valid <= 1'b1;
          end else begin
            tmp_pos[pos_cnt] <= arr_in[idx];
            pos_cnt <= pos_cnt + 1;
            pos_valid_cnt <= pos_valid_cnt + 1;
            pos_valid <= 1'b1;
          end
        end
      end else begin
        idx <= 5'd15;
        neg_valid <= 1'b0;
        pos_valid <= 1'b0;
        neg_valid_cnt <= '0;
        pos_valid_cnt <= '0;
      end
    end
  end

  // Compose output from rearranged prefix and untouched suffix
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arr_out <= '0;
    end else if (start) begin
      arr_out <= arr_in; // copy base; will be overwritten by first n elements during processing
    end else begin
      for (int i = 0; i < 16; i++) begin
        if (i < n) begin
          if (i < neg_total_q) begin
            arr_out[i] <= tmp_neg[i];
          end else begin
            arr_out[i] <= tmp_pos[i - neg_total_q];
          end
        end else begin
          arr_out[i] <= arr_in[i];
        end
      end
    end
  end

  // done is asserted when processing is complete (16 cycles after start)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) done <= 1'b0;
    else if (start) done <= 1'b0;
    else if (idx == 5'd15) done <= 1'b1;
  end

endmodule
