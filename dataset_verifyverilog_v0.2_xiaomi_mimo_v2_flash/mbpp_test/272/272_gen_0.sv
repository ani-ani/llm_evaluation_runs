module rear_extract (
    input [2:0] num_tuples,
    input [7:0] tuple_field0 [0:3],
    input [7:0] tuple_field1 [0:3],
    input [7:0] tuple_field2 [0:3],
    output reg [7:0] rear_elements [0:3]
);

    integer i;

    always @(*) begin
        // Initialize all output elements to 0
        for (i = 0; i < 4; i = i + 1) begin
            rear_elements[i] = 8'h00;
        end

        // Extract the last element (tuple_field2) for valid tuples
        for (i = 0; i < 4; i = i + 1) begin
            if (i < num_tuples) begin
                rear_elements[i] = tuple_field2[i];
            end
        end
    end

endmodule