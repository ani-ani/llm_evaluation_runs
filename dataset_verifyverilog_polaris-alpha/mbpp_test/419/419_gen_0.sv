module round_and_sum(
    input  signed [15:0] numbers [0:7],
    input        [2:0]  length,
    output signed [13:0] total
);

    // Internal wires for rounded values and their absolute values
    wire signed [8:0]  rounded_val   [0:7];
    wire signed [8:0]  abs_val       [0:7];

    // Rounded value: (number + 0.5) >>> 8 (arithmetic)
    assign rounded_val[0] = (numbers[0] + 16'sh0080) >>> 8;
    assign rounded_val[1] = (numbers[1] + 16'sh0080) >>> 8;
    assign rounded_val[2] = (numbers[2] + 16'sh0080) >>> 8;
    assign rounded_val[3] = (numbers[3] + 16'sh0080) >>> 8;
    assign rounded_val[4] = (numbers[4] + 16'sh0080) >>> 8;
    assign rounded_val[5] = (numbers[5] + 16'sh0080) >>> 8;
    assign rounded_val[6] = (numbers[6] + 16'sh0080) >>> 8;
    assign rounded_val[7] = (numbers[7] + 16'sh0080) >>> 8;

    // Absolute values of rounded integers
    assign abs_val[0] = (rounded_val[0] < 0) ? -rounded_val[0] : rounded_val[0];
    assign abs_val[1] = (rounded_val[1] < 0) ? -rounded_val[1] : rounded_val[1];
    assign abs_val[2] = (rounded_val[2] < 0) ? -rounded_val[2] : rounded_val[2];
    assign abs_val[3] = (rounded_val[3] < 0) ? -rounded_val[3] : rounded_val[3];
    assign abs_val[4] = (rounded_val[4] < 0) ? -rounded_val[4] : rounded_val[4];
    assign abs_val[5] = (rounded_val[5] < 0) ? -rounded_val[5] : rounded_val[5];
    assign abs_val[6] = (rounded_val[6] < 0) ? -rounded_val[6] : rounded_val[6];
    assign abs_val[7] = (rounded_val[7] < 0) ? -rounded_val[7] : rounded_val[7];

    // Sum of absolute values for the first 'length' elements (combinational, no clock)
    // Use full sum, then mask out elements beyond 'length'
    wire [8:0] abs0_en = (length > 3'd0) ? abs_val[0] : 9'd0;
    wire [8:0] abs1_en = (length > 3'd1) ? abs_val[1] : 9'd0;
    wire [8:0] abs2_en = (length > 3'd2) ? abs_val[2] : 9'd0;
    wire [8:0] abs3_en = (length > 3'd3) ? abs_val[3] : 9'd0;
    wire [8:0] abs4_en = (length > 3'd4) ? abs_val[4] : 9'd0;
    wire [8:0] abs5_en = (length > 3'd5) ? abs_val[5] : 9'd0;
    wire [8:0] abs6_en = (length > 3'd6) ? abs_val[6] : 9'd0;
    wire [8:0] abs7_en = (length > 3'd7) ? abs_val[7] : 9'd0;

    // Sum of up to 8 values, each up to 9 bits -> need up to 12 bits
    wire [11:0] sum0 = abs0_en + abs1_en;
    wire [11:0] sum1 = abs2_en + abs3_en;
    wire [11:0] sum2 = abs4_en + abs5_en;
    wire [11:0] sum3 = abs6_en + abs7_en;

    wire [12:0] sum01 = sum0 + sum1; // 13 bits
    wire [12:0] sum23 = sum2 + sum3; // 13 bits

    wire [12:0] total_sum = sum01 + sum23; // final sum of abs rounded values

    // Multiply sum by 'length' (length is 1-8 per spec)
    // Max total_sum <= 2040, length <= 8 -> product fits in 14 bits
    wire [13:0] product = total_sum * length;

    assign total = product;

endmodule