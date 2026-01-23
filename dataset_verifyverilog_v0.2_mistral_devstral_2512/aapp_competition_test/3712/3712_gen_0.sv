module student_swap_optimizer (
    input [4:0] compartment_31, compartment_30, compartment_29, compartment_28, compartment_27, compartment_26, compartment_25, compartment_24,
    input [4:0] compartment_23, compartment_22, compartment_21, compartment_20, compartment_19, compartment_18, compartment_17, compartment_16,
    input [4:0] compartment_15, compartment_14, compartment_13, compartment_12, compartment_11, compartment_10, compartment_9, compartment_8,
    input [4:0] compartment_7, compartment_6, compartment_5, compartment_4, compartment_3, compartment_2, compartment_1, compartment_0,
    output [7:0] min_swaps
);

    // Count compartments by student count (0, 1, 2, 3, 4)
    wire [5:0] count_0 = 
        (compartment_0 == 5'd0) + (compartment_1 == 5'd0) + (compartment_2 == 5'd0) + (compartment_3 == 5'd0) +
        (compartment_4 == 5'd0) + (compartment_5 == 5'd0) + (compartment_6 == 5'd0) + (compartment_7 == 5'd0) +
        (compartment_8 == 5'd0) + (compartment_9 == 5'd0) + (compartment_10 == 5'd0) + (compartment_11 == 5'd0) +
        (compartment_12 == 5'd0) + (compartment_13 == 5'd0) + (compartment_14 == 5'd0) + (compartment_15 == 5'd0) +
        (compartment_16 == 5'd0) + (compartment_17 == 5'd0) + (compartment_18 == 5'd0) + (compartment_19 == 5'd0) +
        (compartment_20 == 5'd0) + (compartment_21 == 5'd0) + (compartment_22 == 5'd0) + (compartment_23 == 5'd0) +
        (compartment_24 == 5'd0) + (compartment_25 == 5'd0) + (compartment_26 == 5'd0) + (compartment_27 == 5'd0) +
        (compartment_28 == 5'd0) + (compartment_29 == 5'd0) + (compartment_30 == 5'd0) + (compartment_31 == 5'd0);

    wire [5:0] count_1 = 
        (compartment_0 == 5'd1) + (compartment_1 == 5'd1) + (compartment_2 == 5'd1) + (compartment_3 == 5'd1) +
        (compartment_4 == 5'd1) + (compartment_5 == 5'd1) + (compartment_6 == 5'd1) + (compartment_7 == 5'd1) +
        (compartment_8 == 5'd1) + (compartment_9 == 5'd1) + (compartment_10 == 5'd1) + (compartment_11 == 5'd1) +
        (compartment_12 == 5'd1) + (compartment_13 == 5'd1) + (compartment_14 == 5'd1) + (compartment_15 == 5'd1) +
        (compartment_16 == 5'd1) + (compartment_17 == 5'd1) + (compartment_18 == 5'd1) + (compartment_19 == 5'd1) +
        (compartment_20 == 5'd1) + (compartment_21 == 5'd1) + (compartment_22 == 5'd1) + (compartment_23 == 5'd1) +
        (compartment_24 == 5'd1) + (compartment_25 == 5'd1) + (compartment_26 == 5'd1) + (compartment_27 == 5'd1) +
        (compartment_28 == 5'd1) + (compartment_29 == 5'd1) + (compartment_30 == 5'd1) + (compartment_31 == 5'd1);

    wire [5:0] count_2 = 
        (compartment_0 == 5'd2) + (compartment_1 == 5'd2) + (compartment_2 == 5'd2) + (compartment_3 == 5'd2) +
        (compartment_4 == 5'd2) + (compartment_5 == 5'd2) + (compartment_6 == 5'd2) + (compartment_7 == 5'd2) +
        (compartment_8 == 5'd2) + (compartment_9 == 5'd2) + (compartment_10 == 5'd2) + (compartment_11 == 5'd2) +
        (compartment_12 == 5'd2) + (compartment_13 == 5'd2) + (compartment_14 == 5'd2) + (compartment_15 == 5'd2) +
        (compartment_16 == 5'd2) + (compartment_17 == 5'd2) + (compartment_18 == 5'd2) + (compartment_19 == 5'd2) +
        (compartment_20 == 5'd2) + (compartment_21 == 5'd2) + (compartment_22 == 5'd2) + (compartment_23 == 5'd2) +
        (compartment_24 == 5'd2) + (compartment_25 == 5'd2) + (compartment_26 == 5'd2) + (compartment_27 == 5'd2) +
        (compartment_28 == 5'd2) + (compartment_29 == 5'd2) + (compartment_30 == 5'd2) + (compartment_31 == 5'd2);

    wire [5:0] count_3 = 
        (compartment_0 == 5'd3) + (compartment_1 == 5'd3) + (compartment_2 == 5'd3) + (compartment_3 == 5'd3) +
        (compartment_4 == 5'd3) + (compartment_5 == 5'd3) + (compartment_6 == 5'd3) + (compartment_7 == 5'd3) +
        (compartment_8 == 5'd3) + (compartment_9 == 5'd3) + (compartment_10 == 5'd3) + (compartment_11 == 5'd3) +
        (compartment_12 == 5'd3) + (compartment_13 == 5'd3) + (compartment_14 == 5'd3) + (compartment_15 == 5'd3) +
        (compartment_16 == 5'd3) + (compartment_17 == 5'd3) + (compartment_18 == 5'd3) + (compartment_19 == 5'd3) +
        (compartment_20 == 5'd3) + (compartment_21 == 5'd3) + (compartment_22 == 5'd3) + (compartment_23 == 5'd3) +
        (compartment_24 == 5'd3) + (compartment_25 == 5'd3) + (compartment_26 == 5'd3) + (compartment_27 == 5'd3) +
        (compartment_28 == 5'd3) + (compartment_29 == 5'd3) + (compartment_30 == 5'd3) + (compartment_31 == 5'd3);

    wire [5:0] count_4 = 
        (compartment_0 == 5'd4) + (compartment_1 == 5'd4) + (compartment_2 == 5'd4) + (compartment_3 == 5'd4) +
        (compartment_4 == 5'd4) + (compartment_5 == 5'd4) + (compartment_6 == 5'd4) + (compartment_7 == 5'd4) +
        (compartment_8 == 5'd4) + (compartment_9 == 5'd4) + (compartment_10 == 5'd4) + (compartment_11 == 5'd4) +
        (compartment_12 == 5'd4) + (compartment_13 == 5'd4) + (compartment_14 == 5'd4) + (compartment_15 == 5'd4) +
        (compartment_16 == 5'd4) + (compartment_17 == 5'd4) + (compartment_18 == 5'd4) + (compartment_19 == 5'd4) +
        (compartment_20 == 5'd4) + (compartment_21 == 5'd4) + (compartment_22 == 5'd4) + (compartment_23 == 5'd4) +
        (compartment_24 == 5'd4) + (compartment_25 == 5'd4) + (compartment_26 == 5'd4) + (compartment_27 == 5'd4) +
        (compartment_28 == 5'd4) + (compartment_29 == 5'd4) + (compartment_30 == 5'd4) + (compartment_31 == 5'd4);

    // Calculate total students
    wire [8:0] total_students = 
        (count_0 * 5'd0) + (count_1 * 5'd1) + (count_2 * 5'd2) + (count_3 * 5'd3) + (count_4 * 5'd4);

    // Check for impossible cases
    wire impossible = (total_students <= 5'd2) || (total_students == 5'd5);

    // Greedy algorithm steps
    wire [5:0] match_12 = (count_1 < count_2) ? count_1 : count_2;
    wire [5:0] count_1_after_12 = count_1 - match_12;
    wire [5:0] count_2_after_12 = count_2 - match_12;
    wire [5:0] count_3_after_12 = count_3 + match_12;

    wire [5:0] groups_of_3_from_1 = count_1_after_12 / 5'd3;
    wire [5:0] count_1_after_3 = count_1_after_12 % 5'd3;
    wire [5:0] count_3_after_3 = count_3_after_12 + groups_of_3_from_1;

    wire [5:0] groups_of_3_from_2 = count_2_after_12 / 5'd3;
    wire [5:0] count_2_after_3 = count_2_after_12 % 5'd3;
    wire [5:0] count_3_after_2 = count_3_after_3 + (groups_of_3_from_2 * 5'd2);

    // Cost calculation
    wire [7:0] cost_12 = match_12;
    wire [7:0] cost_3_from_1 = 2 * groups_of_3_from_1;
    wire [7:0] cost_3_from_2 = 2 * groups_of_3_from_2;
    wire [7:0] cost_so_far = cost_12 + cost_3_from_1 + cost_3_from_2;

    // Resolve remainders
    wire [7:0] cost_remainder;
    always @(*) begin
        if (impossible) begin
            cost_remainder = 8'hFF;
        end else begin
            case ({count_1_after_3, count_2_after_3})
                2'b00: cost_remainder = 8'd0;
                2'b01: begin
                    if (count_3_after_2 > 0) cost_remainder = 8'd1;
                    else if (count_4 >= 2) cost_remainder = 8'd2;
                    else cost_remainder = 8'hFF;
                end
                2'b10: begin
                    if (count_4 > 0) cost_remainder = 8'd2;
                    else if (count_3_after_2 >= 2) cost_remainder = 8'd2;
                    else cost_remainder = 8'hFF;
                end
                2'b11: begin
                    if (count_4 > 0) cost_remainder = 8'd1;
                    else if (count_3_after_2 >= 2) cost_remainder = 8'd2;
                    else cost_remainder = 8'hFF;
                end
                default: cost_remainder = 8'd0;
            endcase
        end
    end

    // Final cost
    assign min_swaps = (impossible || (cost_remainder == 8'hFF)) ? 8'hFF : (cost_so_far + cost_remainder);

endmodule