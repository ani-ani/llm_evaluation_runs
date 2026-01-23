module remove_duplicates(
    input [7:0] numbers [0:7],
    input [3:0] length,
    output [7:0] result [0:7],
    output [3:0] result_length
);

    integer i;
    integer j;
    integer k;
    reg [7:0] temp_result [0:7];
    reg [3:0] temp_length;
    reg [7:0] unique_count;

    always @(*) begin
        unique_count = 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
            temp_result[i] = 8'd0;
        end

        for (i = 0; i < length; i = i + 1) begin
            reg [7:0] is_duplicate;
            is_duplicate = 8'd0;

            for (j = 0; j < length; j = j + 1) begin
                if (j != i && numbers[i] == numbers[j]) begin
                    is_duplicate = 8'd1;
                end
            end

            if (!is_duplicate) begin
                temp_result[unique_count] = numbers[i];
                unique_count = unique_count + 8'd1;
            end
        end

        temp_length = unique_count;

        for (k = 0; k < 8; k = k + 1) begin
            result[k] = temp_result[k];
        end

        result_length = temp_length;
    end

endmodule