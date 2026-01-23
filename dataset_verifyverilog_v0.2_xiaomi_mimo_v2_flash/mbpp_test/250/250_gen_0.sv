module element_counter (
    input [7:0] target,
    input [11:0][7:0] data_array,
    output [7:0] count
);

    wire [11:0] match;
    wire [7:0] sum_stage1 [5:0];
    wire [7:0] sum_stage2 [2:0];
    wire [7:0] sum_stage3 [1:0];
    wire [7:0] sum_stage4;

    // Compare each element with target
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : gen_compare
            assign match[i] = (data_array[i] == target);
        end
    endgenerate

    // Tree of adders to sum the 12 match bits
    // Stage 1: 12 -> 6 (2 inputs each)
    assign sum_stage1[0] = {7'b0, match[0]} + {7'b0, match[1]};
    assign sum_stage1[1] = {7'b0, match[2]} + {7'b0, match[3]};
    assign sum_stage1[2] = {7'b0, match[4]} + {7'b0, match[5]};
    assign sum_stage1[3] = {7'b0, match[6]} + {7'b0, match[7]};
    assign sum_stage1[4] = {7'b0, match[8]} + {7'b0, match[9]};
    assign sum_stage1[5] = {7'b0, match[10]} + {7'b0, match[11]};

    // Stage 2: 6 -> 3 (2 inputs each)
    assign sum_stage2[0] = sum_stage1[0] + sum_stage1[1];
    assign sum_stage2[1] = sum_stage1[2] + sum_stage1[3];
    assign sum_stage2[2] = sum_stage1[4] + sum_stage1[5];

    // Stage 3: 3 -> 2 (2 inputs, carry one)
    // Split 3 into 2+1
    assign sum_stage3[0] = sum_stage2[0] + sum_stage2[1];
    assign sum_stage3[1] = sum_stage2[2];

    // Stage 4: 2 -> 1
    assign sum_stage4 = sum_stage3[0] + sum_stage3[1];

    // Assign final output
    assign count = sum_stage4;

endmodule