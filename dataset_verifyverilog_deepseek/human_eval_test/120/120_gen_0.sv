module top_k_sorted (
  input clk,
  input rst_n,
  input start,
  input [2:0] arr_size,
  input [2:0] k_val,
  input [11:0] arr_data [7:0],
  output reg [95:0] result,
  output reg done,
  output valid
);
  reg [11:0] sorted_arr [7:0];
  reg [11:0] padded_arr [7:0];
  reg [4:0] counter;
  reg processing;
  reg [2:0] latched_arr_size;
  reg [2:0] latched_k_val;
  reg start_prev;
  wire start_pulse = start && !start_prev;
  wire signed [11:0] signed_arr [7:0];
  assign valid = done;

  genvar i;
  generate
    for (i=0; i<8; i=i+1) begin
      assign signed_arr[i] = $signed(arr_data[i]);
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_prev <= 0;
      counter <= 0;
      processing <= 0;
      done <= 0;
      result <= 0;
      sorted_arr <= '{default:12'sh0};
      padded_arr <= '{default:12'sh800};
      latched_arr_size <= 0;
      latched_k_val <= 0;
    end else begin
      start_prev <= start;
      done <= 0;

      if (start_pulse) begin
        latched_arr_size <= arr_size;
        latched_k_val <= k_val;
        for (int j=0; j<8; j=j+1) begin
          padded_arr[j] <= (j < arr_size) ? signed_arr[j] : 12'sh800;
        end
        sorted_arr <= padded_arr;
        counter <= 0;
        processing <= 1;
      end else if (processing && counter < 15) begin
        counter <= counter + 1;

        // Sorting network (8 elements, semi-optimized bubble sort)
        for (int j=0; j<7; j=j+1) begin
          if (counter < 8) begin
            if (counter[0] == j[0]) begin // Alternate even/odd
              if ($signed(sorted_arr[j]) > $signed(sorted_arr[j+1])) begin
                {sorted_arr[j], sorted_arr[j+1]} <= {sorted_arr[j+1], sorted_arr[j]};
              end
            end
          end
        end
      end else if (processing) begin
        processing <= 0;
        done <= 1;

        // Format output
        result <= 0;
        for (int m=0; m<latched_k_val; m=m+1) begin
          if ((8 - latched_k_val + m) < 8) begin
            result[m*12 +: 12] <= sorted_arr[8 - latched_k_val + m];
          end
        end
      end
    end
  end
endmodule