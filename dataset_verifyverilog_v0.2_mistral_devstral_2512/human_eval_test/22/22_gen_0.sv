module filter_integers (
  input [15:0][23:0] data_array,
  output [7:0] count,
  output [15:0][15:0] filtered_integers
);

  wire [15:0] valid_mask = {16{1'b0}};
  wire [15:0][15:0] temp_values = '{default:0};

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : filter_loop
      assign valid_mask[i] = (data_array[i][7:0] == 8'h00);
      assign temp_values[i] = data_array[i][23:8];
    end
  endgenerate

  wire [15:0] prefix_sum = {16{1'b0}};
  assign prefix_sum[0] = valid_mask[0];
  assign prefix_sum[1] = prefix_sum[0] + valid_mask[1];
  assign prefix_sum[2] = prefix_sum[1] + valid_mask[2];
  assign prefix_sum[3] = prefix_sum[2] + valid_mask[3];
  assign prefix_sum[4] = prefix_sum[3] + valid_mask[4];
  assign prefix_sum[5] = prefix_sum[4] + valid_mask[5];
  assign prefix_sum[6] = prefix_sum[5] + valid_mask[6];
  assign prefix_sum[7] = prefix_sum[6] + valid_mask[7];
  assign prefix_sum[8] = prefix_sum[7] + valid_mask[8];
  assign prefix_sum[9] = prefix_sum[8] + valid_mask[9];
  assign prefix_sum[10] = prefix_sum[9] + valid_mask[10];
  assign prefix_sum[11] = prefix_sum[10] + valid_mask[11];
  assign prefix_sum[12] = prefix_sum[11] + valid_mask[12];
  assign prefix_sum[13] = prefix_sum[12] + valid_mask[13];
  assign prefix_sum[14] = prefix_sum[13] + valid_mask[14];
  assign prefix_sum[15] = prefix_sum[14] + valid_mask[15];

  assign count = prefix_sum[15];

  genvar j;
  generate
    for (j = 0; j < 16; j = j + 1) begin : output_loop
      wire [15:0] filtered_value = 16'h0;
      always_comb begin
        case (prefix_sum[j])
          1: filtered_value = temp_values[0];
          2: filtered_value = temp_values[1];
          3: filtered_value = temp_values[2];
          4: filtered_value = temp_values[3];
          5: filtered_value = temp_values[4];
          6: filtered_value = temp_values[5];
          7: filtered_value = temp_values[6];
          8: filtered_value = temp_values[7];
          9: filtered_value = temp_values[8];
          10: filtered_value = temp_values[9];
          11: filtered_value = temp_values[10];
          12: filtered_value = temp_values[11];
          13: filtered_value = temp_values[12];
          14: filtered_value = temp_values[13];
          15: filtered_value = temp_values[14];
          16: filtered_value = temp_values[15];
          default: filtered_value = 16'h0;
        endcase
      end
      assign filtered_integers[j] = filtered_value;
    end
  endgenerate

endmodule