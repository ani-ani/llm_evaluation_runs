module unique_sorter(
    input [7:0][15:0] numbers,
    output [7:0][15:0] result
);

    reg [15:0] sorted [0:7];
    reg [15:0] unique [0:7];
    reg [15:0] compacted [0:7];
    integer i, j;

    // Sorting network (bitonic sort for 8 elements)
    always @(*) begin
        // Stage 1
        sorted[0] = numbers[0] < numbers[1] ? numbers[0] : numbers[1];
        sorted[1] = numbers[0] < numbers[1] ? numbers[1] : numbers[0];
        sorted[2] = numbers[2] < numbers[3] ? numbers[2] : numbers[3];
        sorted[3] = numbers[2] < numbers[3] ? numbers[3] : numbers[2];
        sorted[4] = numbers[4] < numbers[5] ? numbers[4] : numbers[5];
        sorted[5] = numbers[4] < numbers[5] ? numbers[5] : numbers[4];
        sorted[6] = numbers[6] < numbers[7] ? numbers[6] : numbers[7];
        sorted[7] = numbers[6] < numbers[7] ? numbers[7] : numbers[6];

        // Stage 2
        sorted[0] = sorted[0] < sorted[2] ? sorted[0] : sorted[2];
        sorted[2] = sorted[0] < sorted[2] ? sorted[2] : sorted[0];
        sorted[1] = sorted[1] < sorted[3] ? sorted[1] : sorted[3];
        sorted[3] = sorted[1] < sorted[3] ? sorted[3] : sorted[1];
        sorted[4] = sorted[4] < sorted[6] ? sorted[4] : sorted[6];
        sorted[6] = sorted[4] < sorted[6] ? sorted[6] : sorted[4];
        sorted[5] = sorted[5] < sorted[7] ? sorted[5] : sorted[7];
        sorted[7] = sorted[5] < sorted[7] ? sorted[7] : sorted[5];

        // Stage 3
        sorted[0] = sorted[0] < sorted[4] ? sorted[0] : sorted[4];
        sorted[4] = sorted[0] < sorted[4] ? sorted[4] : sorted[0];
        sorted[1] = sorted[1] < sorted[5] ? sorted[1] : sorted[5];
        sorted[5] = sorted[1] < sorted[5] ? sorted[5] : sorted[1];
        sorted[2] = sorted[2] < sorted[6] ? sorted[2] : sorted[6];
        sorted[6] = sorted[2] < sorted[6] ? sorted[6] : sorted[2];
        sorted[3] = sorted[3] < sorted[7] ? sorted[3] : sorted[7];
        sorted[7] = sorted[3] < sorted[7] ? sorted[7] : sorted[3];

        // Stage 4
        sorted[1] = sorted[1] < sorted[2] ? sorted[1] : sorted[2];
        sorted[2] = sorted[1] < sorted[2] ? sorted[2] : sorted[1];
        sorted[3] = sorted[3] < sorted[6] ? sorted[3] : sorted[6];
        sorted[6] = sorted[3] < sorted[6] ? sorted[6] : sorted[3];
        sorted[5] = sorted[5] < sorted[6] ? sorted[5] : sorted[6];
        sorted[6] = sorted[5] < sorted[6] ? sorted[6] : sorted[5];

        // Stage 5
        sorted[0] = sorted[0] < sorted[1] ? sorted[0] : sorted[1];
        sorted[1] = sorted[0] < sorted[1] ? sorted[1] : sorted[0];
        sorted[2] = sorted[2] < sorted[3] ? sorted[2] : sorted[3];
        sorted[3] = sorted[2] < sorted[3] ? sorted[3] : sorted[2];
        sorted[4] = sorted[4] < sorted[5] ? sorted[4] : sorted[5];
        sorted[5] = sorted[4] < sorted[5] ? sorted[5] : sorted[4];
        sorted[6] = sorted[6] < sorted[7] ? sorted[6] : sorted[7];
        sorted[7] = sorted[6] < sorted[7] ? sorted[7] : sorted[6];

        // Stage 6
        sorted[2] = sorted[2] < sorted[4] ? sorted[2] : sorted[4];
        sorted[4] = sorted[2] < sorted[4] ? sorted[4] : sorted[2];
        sorted[3] = sorted[3] < sorted[5] ? sorted[3] : sorted[5];
        sorted[5] = sorted[3] < sorted[5] ? sorted[5] : sorted[3];

        // Stage 7
        sorted[1] = sorted[1] < sorted[4] ? sorted[1] : sorted[4];
        sorted[4] = sorted[1] < sorted[4] ? sorted[4] : sorted[1];
        sorted[3] = sorted[3] < sorted[4] ? sorted[3] : sorted[4];
        sorted[4] = sorted[3] < sorted[4] ? sorted[4] : sorted[3];

        // Stage 8
        sorted[0] = sorted[0] < sorted[1] ? sorted[0] : sorted[1];
        sorted[1] = sorted[0] < sorted[1] ? sorted[1] : sorted[0];
        sorted[2] = sorted[2] < sorted[3] ? sorted[2] : sorted[3];
        sorted[3] = sorted[2] < sorted[3] ? sorted[3] : sorted[2];
        sorted[4] = sorted[4] < sorted[5] ? sorted[4] : sorted[5];
        sorted[5] = sorted[4] < sorted[5] ? sorted[5] : sorted[4];
        sorted[6] = sorted[6] < sorted[7] ? sorted[6] : sorted[7];
        sorted[7] = sorted[6] < sorted[7] ? sorted[7] : sorted[6];
    end

    // Duplicate detection and removal
    always @(*) begin
        // Mark duplicates (keep first occurrence, mark rest as 0)
        unique[0] = sorted[0];
        unique[1] = (sorted[1] == sorted[0]) ? 16'd0 : sorted[1];
        unique[2] = (sorted[2] == sorted[1] || sorted[2] == sorted[0]) ? 16'd0 : sorted[2];
        unique[3] = (sorted[3] == sorted[2] || sorted[3] == sorted[1] || sorted[3] == sorted[0]) ? 16'd0 : sorted[3];
        unique[4] = (sorted[4] == sorted[3] || sorted[4] == sorted[2] || sorted[4] == sorted[1] || sorted[4] == sorted[0]) ? 16'd0 : sorted[4];
        unique[5] = (sorted[5] == sorted[4] || sorted[5] == sorted[3] || sorted[5] == sorted[2] || sorted[5] == sorted[1] || sorted[5] == sorted[0]) ? 16'd0 : sorted[5];
        unique[6] = (sorted[6] == sorted[5] || sorted[6] == sorted[4] || sorted[6] == sorted[3] || sorted[6] == sorted[2] || sorted[6] == sorted[1] || sorted[6] == sorted[0]) ? 16'd0 : sorted[6];
        unique[7] = (sorted[7] == sorted[6] || sorted[7] == sorted[5] || sorted[7] == sorted[4] || sorted[7] == sorted[3] || sorted[7] == sorted[2] || sorted[7] == sorted[1] || sorted[7] == sorted[0]) ? 16'd0 : sorted[7];

        // Compact non-zero values to the left
        compacted[0] = unique[0];
        compacted[1] = (unique[1] != 16'd0) ? unique[1] : (unique[2] != 16'd0) ? unique[2] : (unique[3] != 16'd0) ? unique[3] : (unique[4] != 16'd0) ? unique[4] : (unique[5] != 16'd0) ? unique[5] : (unique[6] != 16'd0) ? unique[6] : (unique[7] != 16'd0) ? unique[7] : 16'd0;
        compacted[2] = (unique[2] != 16'd0 && unique[1] == 16'd0) ? unique[2] : (unique[3] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0) ? unique[3] : (unique[4] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0) ? unique[4] : (unique[5] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0) ? unique[5] : (unique[6] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0) ? unique[6] : (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
        compacted[3] = (unique[3] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0) ? unique[3] : (unique[4] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0) ? unique[4] : (unique[5] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0) ? unique[5] : (unique[6] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0) ? unique[6] : (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
        compacted[4] = (unique[4] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0) ? unique[4] : (unique[5] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0) ? unique[5] : (unique[6] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0) ? unique[6] : (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
        compacted[5] = (unique[5] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0) ? unique[5] : (unique[6] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0) ? unique[6] : (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
        compacted[6] = (unique[6] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0) ? unique[6] : (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
        compacted[7] = (unique[7] != 16'd0 && unique[1] == 16'd0 && unique[2] == 16'd0 && unique[3] == 16'd0 && unique[4] == 16'd0 && unique[5] == 16'd0 && unique[6] == 16'd0) ? unique[7] : 16'd0;
    end

    // Assign result
    always @(*) begin
        result[0] = compacted[0];
        result[1] = compacted[1];
        result[2] = compacted[2];
        result[3] = compacted[3];
        result[4] = compacted[4];
        result[5] = compacted[5];
        result[6] = compacted[6];
        result[7] = compacted[7];
    end

endmodule