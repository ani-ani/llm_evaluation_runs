module tuple_search (
    input [79:0] data_array,
    input [7:0] target,
    input [3:0] valid_count,
    output found
);

    wire [9:0] match_vec;
    wire [9:0] valid_mask;

    // Extract and compare each element
    assign match_vec[0] = (data_array[7:0] == target);
    assign match_vec[1] = (data_array[15:8] == target);
    assign match_vec[2] = (data_array[23:16] == target);
    assign match_vec[3] = (data_array[31:24] == target);
    assign match_vec[4] = (data_array[39:32] == target);
    assign match_vec[5] = (data_array[47:40] == target);
    assign match_vec[6] = (data_array[55:48] == target);
    assign match_vec[7] = (data_array[63:56] == target);
    assign match_vec[8] = (data_array[71:64] == target);
    assign match_vec[9] = (data_array[79:72] == target);

    // Create mask for valid elements based on valid_count
    // valid_count 1 -> bit 0 set, 2 -> bits 1:0 set, ..., 10 -> all bits set
    assign valid_mask = (valid_count == 4'd0) ? 10'b0000000000 :
                        (valid_count == 4'd1) ? 10'b0000000001 :
                        (valid_count == 4'd2) ? 10'b0000000011 :
                        (valid_count == 4'd3) ? 10'b0000000111 :
                        (valid_count == 4'd4) ? 10'b0000001111 :
                        (valid_count == 4'd5) ? 10'b0000011111 :
                        (valid_count == 4'd6) ? 10'b0000111111 :
                        (valid_count == 4'd7) ? 10'b0001111111 :
                        (valid_count == 4'd8) ? 10'b0011111111 :
                        (valid_count == 4'd9) ? 10'b0111111111 :
                                                10'b1111111111; // valid_count == 10

    // OR-reduce only the masked matches
    assign found = |(match_vec & valid_mask);

endmodule