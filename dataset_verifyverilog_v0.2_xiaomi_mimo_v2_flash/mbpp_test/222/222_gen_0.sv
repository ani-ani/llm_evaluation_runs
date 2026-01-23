module check_same_type(
    input [7:0] data_array [0:7],
    output reg result
);

    // Intermediate equality flags
    wire eq [1:7];
    
    // Instantiate comparators for indices 1 through 7
    assign eq[1] = (data_array[1] == data_array[0]);
    assign eq[2] = (data_array[2] == data_array[0]);
    assign eq[3] = (data_array[3] == data_array[0]);
    assign eq[4] = (data_array[4] == data_array[0]);
    assign eq[5] = (data_array[5] == data_array[0]);
    assign eq[6] = (data_array[6] == data_array[0]);
    assign eq[7] = (data_array[7] == data_array[0]);
    
    // Combinational logic to aggregate results
    always @(*) begin
        result = 1'b1;
        if (!eq[1] || !eq[2] || !eq[3] || !eq[4] || !eq[5] || !eq[6] || !eq[7])
            result = 1'b0;
    end

endmodule