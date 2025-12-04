module max_length_element (
  // For sublist 0
  input reg [7:0] data0_0, data0_1, data0_2, data0_3,
  input reg [3:0] valid0,
  // For sublist 1
  input reg [7:0] data1_0, data1_1, data1_2, data1_3,
  input reg [3:0] valid1,
  // For sublist 2
  input reg [7:0] data2_0, data2_1, data2_2, data2_3,
  input reg [3:0] valid2,
  // For sublist 3
  input reg [7:0] data3_0, data3_1, data3_2, data3_3,
  input reg [3:0] valid3,
  output reg [1:0] index
);

  // Compute the lengths (3 bits for each, so 0 to 4)
  wire [2:0] length0 = $countones(valid0);
  wire [2:0] length1 = $countones(valid1);
  wire [2:0] length2 = $countones(valid2);
  wire [2:0] length3 = $countones(valid3);

  // Compute the sums (10 bits for each)
  wire [9:0] sum0 = (valid0[0] ? {2'b00, data0_0} : 10'b0) + 
                    (valid0[1] ? {2'b00, data0_1} : 10'b0) + 
                    (valid0[2] ? {2'b00, data0_2} : 10'b0) + 
                    (valid0[3] ? {2'b00, data0_3} : 10'b0);
  wire [9:0] sum1 = (valid1[0] ? {2'b00, data1_0} : 10'b0) + 
                    (valid1[1] ? {2'b00, data1_1} : 10'b0) + 
                    (valid1[2] ? {2'b00, data1_2} : 10'b0) + 
                    (valid1[3] ? {2'b00, data1_3} : 10'b0);
  wire [9:0] sum2 = (valid2[0] ? {2'b00, data2_0} : 10'b0) + 
                    (valid2[1] ? {2'b00, data2_1} : 10'b0) + 
                    (valid2[2] ? {2'b00, data2_2} : 10'b0) + 
                    (valid2[3] ? {2'b00, data2_3} : 10'b0);
  wire [9:0] sum3 = (valid3[0] ? {2'b00, data3_0} : 10'b0) + 
                    (valid3[1] ? {2'b00, data3_1} : 10'b0) + 
                    (valid3[2] ? {2'b00, data3_2} : 10'b0) + 
                    (valid3[3] ? {2'b00, data3_3} : 10'b0);

  // Compute the maximum length
  wire [2:0] max_len = length0;
  wire [2:0] temp1 = (length1 > max_len) ? length1 : max_len;
  wire [2:0] temp2 = (length2 > temp1) ? length2 : temp1;
  wire [2:0] max_len_final = (length3 > temp2) ? length3 : temp2;

  // Compute the candidate sums (if the length of the sublist is max_len, then the candidate sum is the actual sum, otherwise 0)
  wire [9:0] candidate_sum0 = (length0 == max_len_final) ? sum0 : 10'b0;
  wire [9:0] candidate_sum1 = (length1 == max_len_final) ? sum1 : 10'b0;
  wire [9:0] candidate_sum2 = (length2 == max_len_final) ? sum2 : 10'b0;
  wire [9:0] candidate_sum3 = (length3 == max_len_final) ? sum3 : 10'b0;

  // Now compute the maximum candidate sum
  wire [9:0] max_candidate_sum = candidate_sum0;
  wire [9:0] temp_sum1 = (candidate_sum1 > max_candidate_sum) ? candidate_sum1 : max_candidate_sum;
  wire [9:0] temp_sum2 = (candidate_sum2 > temp_sum1) ? candidate_sum2 : temp_sum1;
  wire [9:0] max_candidate_sum_final = (candidate_sum3 > temp_sum2) ? candidate_sum3 : temp_sum2;

  // Now, choose the index: 
  always @(*) begin
    if (length0 == max_len_final && sum0 == max_candidate_sum_final) begin
        index = 2'b00;
    end
    else if (length1 == max_len_final && sum1 == max_candidate_sum_final) begin
        index = 2'b01;
    end
    else if (length2 == max_len_final && sum2 == max_candidate_sum_final) begin
        index = 2'b10;
    end
    else begin
        index = 2'b11;
    end
  end

endmodule