module remove_duplicates (
    input [7:0] data_in_0,
    input [7:0] data_in_1,
    input [7:0] data_in_2,
    input [7:0] data_in_3,
    input [7:0] data_in_4,
    input [7:0] data_in_5,
    input [7:0] data_in_6,
    input [7:0] data_in_7,
    input [2:0] valid_count,
    output reg [7:0] unique_0,
    output reg [7:0] unique_1,
    output reg [7:0] unique_2,
    output reg [7:0] unique_3,
    output reg [7:0] unique_4,
    output reg [7:0] unique_5,
    output reg [7:0] unique_6,
    output reg [7:0] unique_7,
    output reg [3:0] unique_count
);

    // Combinational logic block
    always @(*) begin
        // Internal storage for all inputs
        reg [7:0] inputs [0:7];
        reg [7:0] temp_unique [0:7];
        reg [2:0] idx;
        reg [2:0] j;
        reg is_duplicate;
        integer unique_idx;
        integer i;

        // Initialize array
        inputs[0] = data_in_0;
        inputs[1] = data_in_1;
        inputs[2] = data_in_2;
        inputs[3] = data_in_3;
        inputs[4] = data_in_4;
        inputs[5] = data_in_5;
        inputs[6] = data_in_6;
        inputs[7] = data_in_7;

        // Initialize temp_unique to invalid
        for (i = 0; i < 8; i = i + 1) begin
            temp_unique[i] = 8'hFF;
        end

        unique_idx = 0;

        // Check each valid input
        for (idx = 0; idx < valid_count; idx = idx + 1) begin
            is_duplicate = 0;
            
            // Compare with all previous elements
            for (j = 0; j < idx; j = j + 1) begin
                if (inputs[idx] == inputs[j]) begin
                    is_duplicate = 1;
                end
            end

            // Compare with all subsequent elements
            for (j = idx + 1; j < valid_count; j = j + 1) begin
                if (inputs[idx] == inputs[j]) begin
                    is_duplicate = 1;
                end
            end

            // If no duplicate found, add to unique list
            if (!is_duplicate) begin
                if (unique_idx < 8) begin
                    temp_unique[unique_idx] = inputs[idx];
                    unique_idx = unique_idx + 1;
                end
            end
        end

        // Assign outputs
        unique_0 = (unique_idx > 0) ? temp_unique[0] : 8'hFF;
        unique_1 = (unique_idx > 1) ? temp_unique[1] : 8'hFF;
        unique_2 = (unique_idx > 2) ? temp_unique[2] : 8'hFF;
        unique_3 = (unique_idx > 3) ? temp_unique[3] : 8'hFF;
        unique_4 = (unique_idx > 4) ? temp_unique[4] : 8'hFF;
        unique_5 = (unique_idx > 5) ? temp_unique[5] : 8'hFF;
        unique_6 = (unique_idx > 6) ? temp_unique[6] : 8'hFF;
        unique_7 = (unique_idx > 7) ? temp_unique[7] : 8'hFF;
        unique_count = unique_idx;
    end

endmodule