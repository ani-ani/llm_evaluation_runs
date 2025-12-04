module div7_digit_rearranger(
  input [31:0] digits_in,
  output reg [31:0] rearranged_out
);

  wire [3:0] d [7:0];
  assign d[7] = digits_in[31:28];
  assign d[6] = digits_in[27:24];
  assign d[5] = digits_in[23:20];
  assign d[4] = digits_in[19:16];
  assign d[3] = digits_in[15:12];
  assign d[2] = digits_in[11:8];
  assign d[1] = digits_in[7:4];
  assign d[0] = digits_in[3:0];

  reg [3:0] remaining_digits [0:3];
  integer i, idx;
  always_comb begin
    idx = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (d[i] != 4'd1 && d[i] != 4'd6 && d[i] != 4'd8 && d[i] != 4'd9) begin
        if (idx < 4) begin
          remaining_digits[idx] = d[i];
          idx = idx + 1;
        end
      end
    end
  end

  reg [3:0] sorted [0:3];
  integer j,k;
  reg [3:0] temp;
  always_comb begin
    for (j = 0; j < 4; j = j + 1) begin
      sorted[j] = remaining_digits[j];
    end
    for (j = 0; j < 3; j = j + 1) begin
      for (k = 0; k < 3 - j; k = k + 1) begin
        if (sorted[k] < sorted[k + 1]) begin
          temp = sorted[k];
          sorted[k] = sorted[k + 1];
          sorted[k + 1] = temp;
        end
      end
    end
  end

  wire [6:0] sum_mod_in = (6 * sorted[0]) + (2 * sorted[1]) + (3 * sorted[2]) + sorted[3];
  wire [2:0] rem1 = sum_mod_in % 7;
  wire [2:0] rem_total = (rem1 * 3'd4) % 7;

  reg [2:0] perm_index;
  always_comb begin
    perm_index = (rem_total == 3'd0) ? 3'd0 : 3'(7 - rem_total);
  end

  reg [15:0] perm_out;
  always_comb begin
    case (perm_index)
      3'd0: perm_out = 16'h1869;
      3'd1: perm_out = 16'h1968;
      3'd2: perm_out = 16'h1689;
      3'd3: perm_out = 16'h6198;
      3'd4: perm_out = 16'h1698;
      3'd5: perm_out = 16'h9861;
      3'd6: perm_out = 16'h1896;
      default: perm_out = 16'h1869;
    endcase
  end

  wire all_zeros = (sorted[0] == 4'd0) & (sorted[1] == 4'd0) & (sorted[2] == 4'd0) & (sorted[3] == 4'd0);

  always_comb begin
    if (all_zeros) begin
      rearranged_out = {perm_out, 16'd0};
    end else begin
      rearranged_out = {sorted[0], sorted[1], sorted[2], sorted[3], perm_out};
    end
  end

endmodule