module string_filter(input [127:0] str1, input [127:0] str2, output reg [127:0] filtered_str);
  reg [255:0] presence_vec;
  wire [15:0] valid;
  wire [4:0] prefix [0:16];

  always_comb begin
    presence_vec = 256'd0;
    for (int k=0; k<16; k++) begin
      presence_vec[str2[k*8 +:8]] = 1'b1;
    end
  end

  genvar j;
  generate
    for (j=0; j<16; j++) begin : valid_block
      assign valid[j] = !presence_vec[str1[j*8 +:8]];
    end
  endgenerate

  assign prefix[0] = 5'd0;
  genvar i;
  generate
    for (i=1; i<=16; i++) begin : prefix_block
      assign prefix[i] = prefix[i-1] + valid[i-1];
    end
  endgenerate

  genvar out_idx;
  generate
    for (out_idx=0; out_idx<16; out_idx++) begin : output_block
      always_comb begin
        filtered_str[out_idx*8 +:8] = '0;
        for (int idx=0; idx<16; idx++) begin
          if ((prefix[idx] == out_idx[4:0]) && valid[idx]) begin
            filtered_str[out_idx*8 +:8] = str1[idx*8 +:8];
          end
        end
      end
    end
  endgenerate
endmodule