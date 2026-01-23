module pair_sum_counter(
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [8:0] target_sum,
    input valid,
    output reg [3:0] pair_count,
    output reg result_valid
);

    // Internal wires for all 28 pair sums
    wire [8:0] sum_01, sum_02, sum_03, sum_04, sum_05, sum_06, sum_07;
    wire [8:0] sum_12, sum_13, sum_14, sum_15, sum_16, sum_17;
    wire [8:0] sum_23, sum_24, sum_25, sum_26, sum_27;
    wire [8:0] sum_34, sum_35, sum_36, sum_37;
    wire [8:0] sum_45, sum_46, sum_47;
    wire [8:0] sum_56, sum_57;
    wire [8:0] sum_67;

    // Internal wires for match flags
    wire match_01, match_02, match_03, match_04, match_05, match_06, match_07;
    wire match_12, match_13, match_14, match_15, match_16, match_17;
    wire match_23, match_24, match_25, match_26, match_27;
    wire match_34, match_35, match_36, match_37;
    wire match_45, match_46, match_47;
    wire match_56, match_57;
    wire match_67;

    // Compute all 28 pair sums (signed arithmetic)
    assign sum_01 = $signed(arr_0) + $signed(arr_1);
    assign sum_02 = $signed(arr_0) + $signed(arr_2);
    assign sum_03 = $signed(arr_0) + $signed(arr_3);
    assign sum_04 = $signed(arr_0) + $signed(arr_4);
    assign sum_05 = $signed(arr_0) + $signed(arr_5);
    assign sum_06 = $signed(arr_0) + $signed(arr_6);
    assign sum_07 = $signed(arr_0) + $signed(arr_7);
    assign sum_12 = $signed(arr_1) + $signed(arr_2);
    assign sum_13 = $signed(arr_1) + $signed(arr_3);
    assign sum_14 = $signed(arr_1) + $signed(arr_4);
    assign sum_15 = $signed(arr_1) + $signed(arr_5);
    assign sum_16 = $signed(arr_1) + $signed(arr_6);
    assign sum_17 = $signed(arr_1) + $signed(arr_7);
    assign sum_23 = $signed(arr_2) + $signed(arr_3);
    assign sum_24 = $signed(arr_2) + $signed(arr_4);
    assign sum_25 = $signed(arr_2) + $signed(arr_5);
    assign sum_26 = $signed(arr_2) + $signed(arr_6);
    assign sum_27 = $signed(arr_2) + $signed(arr_7);
    assign sum_34 = $signed(arr_3) + $signed(arr_4);
    assign sum_35 = $signed(arr_3) + $signed(arr_5);
    assign sum_36 = $signed(arr_3) + $signed(arr_6);
    assign sum_37 = $signed(arr_3) + $signed(arr_7);
    assign sum_45 = $signed(arr_4) + $signed(arr_5);
    assign sum_46 = $signed(arr_4) + $signed(arr_6);
    assign sum_47 = $signed(arr_4) + $signed(arr_7);
    assign sum_56 = $signed(arr_5) + $signed(arr_6);
    assign sum_57 = $signed(arr_5) + $signed(arr_7);
    assign sum_67 = $signed(arr_6) + $signed(arr_7);

    // Compare each sum with target_sum
    assign match_01 = (sum_01 == target_sum);
    assign match_02 = (sum_02 == target_sum);
    assign match_03 = (sum_03 == target_sum);
    assign match_04 = (sum_04 == target_sum);
    assign match_05 = (sum_05 == target_sum);
    assign match_06 = (sum_06 == target_sum);
    assign match_07 = (sum_07 == target_sum);
    assign match_12 = (sum_12 == target_sum);
    assign match_13 = (sum_13 == target_sum);
    assign match_14 = (sum_14 == target_sum);
    assign match_15 = (sum_15 == target_sum);
    assign match_16 = (sum_16 == target_sum);
    assign match_17 = (sum_17 == target_sum);
    assign match_23 = (sum_23 == target_sum);
    assign match_24 = (sum_24 == target_sum);
    assign match_25 = (sum_25 == target_sum);
    assign match_26 = (sum_26 == target_sum);
    assign match_27 = (sum_27 == target_sum);
    assign match_34 = (sum_34 == target_sum);
    assign match_35 = (sum_35 == target_sum);
    assign match_36 = (sum_36 == target_sum);
    assign match_37 = (sum_37 == target_sum);
    assign match_45 = (sum_45 == target_sum);
    assign match_46 = (sum_46 == target_sum);
    assign match_47 = (sum_47 == target_sum);
    assign match_56 = (sum_56 == target_sum);
    assign match_57 = (sum_57 == target_sum);
    assign match_67 = (sum_67 == target_sum);

    // Combinational always block for outputs
    always @(*) begin
        if (valid) begin
            pair_count = 4'd0;
            pair_count = pair_count + {3'd0, match_01};
            pair_count = pair_count + {3'd0, match_02};
            pair_count = pair_count + {3'd0, match_03};
            pair_count = pair_count + {3'd0, match_04};
            pair_count = pair_count + {3'd0, match_05};
            pair_count = pair_count + {3'd0, match_06};
            pair_count = pair_count + {3'd0, match_07};
            pair_count = pair_count + {3'd0, match_12};
            pair_count = pair_count + {3'd0, match_13};
            pair_count = pair_count + {3'd0, match_14};
            pair_count = pair_count + {3'd0, match_15};
            pair_count = pair_count + {3'd0, match_16};
            pair_count = pair_count + {3'd0, match_17};
            pair_count = pair_count + {3'd0, match_23};
            pair_count = pair_count + {3'd0, match_24};
            pair_count = pair_count + {3'd0, match_25};
            pair_count = pair_count + {3'd0, match_26};
            pair_count = pair_count + {3'd0, match_27};
            pair_count = pair_count + {3'd0, match_34};
            pair_count = pair_count + {3'd0, match_35};
            pair_count = pair_count + {3'd0, match_36};
            pair_count = pair_count + {3'd0, match_37};
            pair_count = pair_count + {3'd0, match_45};
            pair_count = pair_count + {3'd0, match_46};
            pair_count = pair_count + {3'd0, match_47};
            pair_count = pair_count + {3'd0, match_56};
            pair_count = pair_count + {3'd0, match_57};
            pair_count = pair_count + {3'd0, match_67};
            result_valid = 1'b1;
        end else begin
            pair_count = 4'd0;
            result_valid = 1'b0;
        end
    end

endmodule