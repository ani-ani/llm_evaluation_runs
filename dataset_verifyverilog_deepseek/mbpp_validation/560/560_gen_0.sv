module tuple_union_sorted(input [4:0] tuple1 [0:7], input [4:0] tuple2 [0:7], output reg [4:0] union_result [0:15], output reg [4:0] valid_count);
  reg [4:0] merged [0:15];
  reg is_unique [0:15];
  reg [4:0] packed_unique [0:15];
  reg [4:0] sorted [0:15];
  integer i, j, idx, pass, k;
  reg [4:0] temp;
  always_comb begin
    for (i = 0; i < 8; i = i + 1) begin
      merged[i] = tuple1[i];
      merged[i + 8] = tuple2[i];
    end
    for (i = 0; i < 16; i = i + 1) begin
      is_unique[i] = 1'b1;
      for (j = 0; j < i; j = j + 1) begin
        if (merged[i] == merged[j]) begin
          is_unique[i] = 1'b0;
        end
      end
    end
    idx = 0;
    for (i = 0; i < 16; i = i + 1) begin
      if (is_unique[i]) begin
        packed_unique[idx] = merged[i];
        idx = idx + 1;
      end
    end
    for (i = idx; i < 16; i = i + 1) begin
      packed_unique[i] = 5'b0;
    end
    valid_count = idx;
    for (i = 0; i < 16; i = i + 1) begin
      sorted[i] = packed_unique[i];
    end
    for (pass = 0; pass < 15; pass = pass + 1) begin
      if (pass < valid_count) begin
        for (k = 0; k < valid_count - 1; k = k + 1) begin
          if (sorted[k] > sorted[k + 1]) begin
            temp = sorted[k];
            sorted[k] = sorted[k + 1];
            sorted[k + 1] = temp;
          end
        end
      end
    end
    union_result = sorted;
  end
endmodule