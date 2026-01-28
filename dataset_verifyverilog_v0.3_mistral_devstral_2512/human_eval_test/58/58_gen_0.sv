module common_elements(
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [2:0] len1,
    input [2:0] len2,
    output reg [7:0] result [0:7],
    output reg [2:0] result_len
);

    reg [7:0] temp_result [0:7];
    reg [7:0] unique_check [0:7];
    reg [7:0] common_elements [0:7];
    integer i, j, k, m, n;
    reg [7:0] temp;
    reg found;
    reg [2:0] common_count;

    always @(*) begin
        // Initialize temporary arrays
        for (i = 0; i < 8; i = i + 1) begin
            temp_result[i] = 8'd0;
            unique_check[i] = 8'd0;
            common_elements[i] = 8'd0;
        end
        common_count = 3'd0;

        // Find common elements from list1 that exist in list2
        for (i = 0; i < len1; i = i + 1) begin
            found = 1'b0;
            // Check if element exists in list2
            for (j = 0; j < len2; j = j + 1) begin
                if (list1[i] == list2[j]) begin
                    found = 1'b1;
                    break;
                end
            end

            // Check if element is unique in list1
            if (found) begin
                found = 1'b0;
                for (k = 0; k < i; k = k + 1) begin
                    if (list1[i] == list1[k]) begin
                        found = 1'b1;
                        break;
                    end
                end
                if (!found) begin
                    common_elements[common_count] = list1[i];
                    common_count = common_count + 1'b1;
                end
            end
        end

        // Sort the common elements using bubble sort
        for (m = 0; m < common_count - 1; m = m + 1) begin
            for (n = 0; n < common_count - m - 1; n = n + 1) begin
                if (common_elements[n] > common_elements[n + 1]) begin
                    temp = common_elements[n];
                    common_elements[n] = common_elements[n + 1];
                    common_elements[n + 1] = temp;
                end
            end
        end

        // Copy sorted elements to result
        for (i = 0; i < 8; i = i + 1) begin
            if (i < common_count) begin
                result[i] = common_elements[i];
            end else begin
                result[i] = 8'd0;
            end
        end
        result_len = common_count;
    end

endmodule