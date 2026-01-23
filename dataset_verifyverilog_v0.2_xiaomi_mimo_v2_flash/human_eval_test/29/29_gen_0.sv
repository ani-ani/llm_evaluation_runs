module filter_by_prefix(
    input [63:0] strings [0:7],
    input [63:0] prefix,
    input [2:0] prefix_len,
    output [63:0] matches [0:7],
    output [2:0] match_count
);

    // Wires to store comparison results for each string
    wire [7:0] match_vec;
    
    // Compare each string against the prefix
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : compare_loop
            compare_prefix cmp (
                .str(strings[i]),
                .pre(prefix),
                .len(prefix_len),
                .match(match_vec[i])
            );
        end
    endgenerate
    
    // Count matches using a combinational popcount
    assign match_count = (
        (match_vec[0] + match_vec[1]) + (match_vec[2] + match_vec[3]) +
        (match_vec[4] + match_vec[5]) + (match_vec[6] + match_vec[7])
    );
    
    // Generate matches array in order
    wire [63:0] matches_int [0:7];
    wire [2:0] idx;
    
    // Priority encoder to pack matches
    // This is a combinational packing logic
    assign matches_int[0] = match_vec[0] ? strings[0] : 
                            match_vec[1] ? strings[1] :
                            match_vec[2] ? strings[2] :
                            match_vec[3] ? strings[3] :
                            match_vec[4] ? strings[4] :
                            match_vec[5] ? strings[5] :
                            match_vec[6] ? strings[6] :
                            match_vec[7] ? strings[7] : 64'd0;
    
    // For subsequent positions, we need to find which strings remain after packing
    // This creates a complex combinational network
    wire [7:0] second_match_mask;
    assign second_match_mask = match_vec & ~((match_vec[0] ? 8'h01 : 8'h00) |
                                             (match_vec[1] ? 8'h02 : 8'h00) |
                                             (match_vec[2] ? 8'h04 : 8'h00) |
                                             (match_vec[3] ? 8'h08 : 8'h00) |
                                             (match_vec[4] ? 8'h10 : 8'h00) |
                                             (match_vec[5] ? 8'h20 : 8'h00) |
                                             (match_vec[6] ? 8'h40 : 8'h00) |
                                             (match_vec[7] ? 8'h80 : 8'h00));
    
    assign matches_int[1] = second_match_mask[0] ? strings[0] :
                            second_match_mask[1] ? strings[1] :
                            second_match_mask[2] ? strings[2] :
                            second_match_mask[3] ? strings[3] :
                            second_match_mask[4] ? strings[4] :
                            second_match_mask[5] ? strings[5] :
                            second_match_mask[6] ? strings[6] :
                            second_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] third_match_mask;
    assign third_match_mask = second_match_mask & ~((second_match_mask[0] ? 8'h01 : 8'h00) |
                                                    (second_match_mask[1] ? 8'h02 : 8'h00) |
                                                    (second_match_mask[2] ? 8'h04 : 8'h00) |
                                                    (second_match_mask[3] ? 8'h08 : 8'h00) |
                                                    (second_match_mask[4] ? 8'h10 : 8'h00) |
                                                    (second_match_mask[5] ? 8'h20 : 8'h00) |
                                                    (second_match_mask[6] ? 8'h40 : 8'h00) |
                                                    (second_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[2] = third_match_mask[0] ? strings[0] :
                            third_match_mask[1] ? strings[1] :
                            third_match_mask[2] ? strings[2] :
                            third_match_mask[3] ? strings[3] :
                            third_match_mask[4] ? strings[4] :
                            third_match_mask[5] ? strings[5] :
                            third_match_mask[6] ? strings[6] :
                            third_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] fourth_match_mask;
    assign fourth_match_mask = third_match_mask & ~((third_match_mask[0] ? 8'h01 : 8'h00) |
                                                    (third_match_mask[1] ? 8'h02 : 8'h00) |
                                                    (third_match_mask[2] ? 8'h04 : 8'h00) |
                                                    (third_match_mask[3] ? 8'h08 : 8'h00) |
                                                    (third_match_mask[4] ? 8'h10 : 8'h00) |
                                                    (third_match_mask[5] ? 8'h20 : 8'h00) |
                                                    (third_match_mask[6] ? 8'h40 : 8'h00) |
                                                    (third_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[3] = fourth_match_mask[0] ? strings[0] :
                            fourth_match_mask[1] ? strings[1] :
                            fourth_match_mask[2] ? strings[2] :
                            fourth_match_mask[3] ? strings[3] :
                            fourth_match_mask[4] ? strings[4] :
                            fourth_match_mask[5] ? strings[5] :
                            fourth_match_mask[6] ? strings[6] :
                            fourth_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] fifth_match_mask;
    assign fifth_match_mask = fourth_match_mask & ~((fourth_match_mask[0] ? 8'h01 : 8'h00) |
                                                    (fourth_match_mask[1] ? 8'h02 : 8'h00) |
                                                    (fourth_match_mask[2] ? 8'h04 : 8'h00) |
                                                    (fourth_match_mask[3] ? 8'h08 : 8'h00) |
                                                    (fourth_match_mask[4] ? 8'h10 : 8'h00) |
                                                    (fourth_match_mask[5] ? 8'h20 : 8'h00) |
                                                    (fourth_match_mask[6] ? 8'h40 : 8'h00) |
                                                    (fourth_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[4] = fifth_match_mask[0] ? strings[0] :
                            fifth_match_mask[1] ? strings[1] :
                            fifth_match_mask[2] ? strings[2] :
                            fifth_match_mask[3] ? strings[3] :
                            fifth_match_mask[4] ? strings[4] :
                            fifth_match_mask[5] ? strings[5] :
                            fifth_match_mask[6] ? strings[6] :
                            fifth_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] sixth_match_mask;
    assign sixth_match_mask = fifth_match_mask & ~((fifth_match_mask[0] ? 8'h01 : 8'h00) |
                                                   (fifth_match_mask[1] ? 8'h02 : 8'h00) |
                                                   (fifth_match_mask[2] ? 8'h04 : 8'h00) |
                                                   (fifth_match_mask[3] ? 8'h08 : 8'h00) |
                                                   (fifth_match_mask[4] ? 8'h10 : 8'h00) |
                                                   (fifth_match_mask[5] ? 8'h20 : 8'h00) |
                                                   (fifth_match_mask[6] ? 8'h40 : 8'h00) |
                                                   (fifth_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[5] = sixth_match_mask[0] ? strings[0] :
                            sixth_match_mask[1] ? strings[1] :
                            sixth_match_mask[2] ? strings[2] :
                            sixth_match_mask[3] ? strings[3] :
                            sixth_match_mask[4] ? strings[4] :
                            sixth_match_mask[5] ? strings[5] :
                            sixth_match_mask[6] ? strings[6] :
                            sixth_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] seventh_match_mask;
    assign seventh_match_mask = sixth_match_mask & ~((sixth_match_mask[0] ? 8'h01 : 8'h00) |
                                                     (sixth_match_mask[1] ? 8'h02 : 8'h00) |
                                                     (sixth_match_mask[2] ? 8'h04 : 8'h00) |
                                                     (sixth_match_mask[3] ? 8'h08 : 8'h00) |
                                                     (sixth_match_mask[4] ? 8'h10 : 8'h00) |
                                                     (sixth_match_mask[5] ? 8'h20 : 8'h00) |
                                                     (sixth_match_mask[6] ? 8'h40 : 8'h00) |
                                                     (sixth_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[6] = seventh_match_mask[0] ? strings[0] :
                            seventh_match_mask[1] ? strings[1] :
                            seventh_match_mask[2] ? strings[2] :
                            seventh_match_mask[3] ? strings[3] :
                            seventh_match_mask[4] ? strings[4] :
                            seventh_match_mask[5] ? strings[5] :
                            seventh_match_mask[6] ? strings[6] :
                            seventh_match_mask[7] ? strings[7] : 64'd0;
    
    wire [7:0] eighth_match_mask;
    assign eighth_match_mask = seventh_match_mask & ~((seventh_match_mask[0] ? 8'h01 : 8'h00) |
                                                      (seventh_match_mask[1] ? 8'h02 : 8'h00) |
                                                      (seventh_match_mask[2] ? 8'h04 : 8'h00) |
                                                      (seventh_match_mask[3] ? 8'h08 : 8'h00) |
                                                      (seventh_match_mask[4] ? 8'h10 : 8'h00) |
                                                      (seventh_match_mask[5] ? 8'h20 : 8'h00) |
                                                      (seventh_match_mask[6] ? 8'h40 : 8'h00) |
                                                      (seventh_match_mask[7] ? 8'h80 : 8'h00));
    
    assign matches_int[7] = eighth_match_mask[0] ? strings[0] :
                            eighth_match_mask[1] ? strings[1] :
                            eighth_match_mask[2] ? strings[2] :
                            eighth_match_mask[3] ? strings[3] :
                            eighth_match_mask[4] ? strings[4] :
                            eighth_match_mask[5] ? strings[5] :
                            eighth_match_mask[6] ? strings[6] :
                            eighth_match_mask[7] ? strings[7] : 64'd0;
    
    // Assign outputs
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : output_assign
            assign matches[j] = matches_int[j];
        end
    endgenerate

endmodule

module compare_prefix(
    input [63:0] str,
    input [63:0] pre,
    input [2:0] len,
    output match
);
    wire [7:0] char0_match = (len > 0) ? ((str[63:56] == pre[63:56]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char1_match = (len > 1) ? ((str[55:48] == pre[55:48]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char2_match = (len > 2) ? ((str[47:40] == pre[47:40]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char3_match = (len > 3) ? ((str[39:32] == pre[39:32]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char4_match = (len > 4) ? ((str[31:24] == pre[31:24]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char5_match = (len > 5) ? ((str[23:16] == pre[23:16]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char6_match = (len > 6) ? ((str[15:8] == pre[15:8]) ? 1'b1 : 1'b0) : 1'b1;
    wire [7:0] char7_match = (len > 7) ? ((str[7:0] == pre[7:0]) ? 1'b1 : 1'b0) : 1'b1;
    
    assign match = char0_match & char1_match & char2_match & char3_match & 
                   char4_match & char5_match & char6_match & char7_match;

endmodule