module new_tuple (
    input [7:0][7:0] list_data,
    input [2:0] list_length,
    input [7:0] append_str,
    output reg [8:0][7:0] result_tuple,
    output reg [2:0] result_length
);

    integer i;

    always @(*) begin
        // Default initialization to avoid latches
        result_tuple = {9{8'b0}};
        result_length = 3'b0;

        // Copy valid elements from list_data to result_tuple
        for (i = 0; i < 8; i = i + 1) begin
            if (i < list_length) begin
                result_tuple[i] = list_data[i];
            end
        end

        // Place append_str at the next index
        if (list_length < 8) begin
            result_tuple[list_length] = append_str;
        end

        // Set the result length
        result_length = list_length + 1;
    end

endmodule