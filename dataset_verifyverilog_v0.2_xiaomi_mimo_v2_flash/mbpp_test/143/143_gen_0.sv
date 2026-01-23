module find_lists #(
    parameter NUM_LISTS = 3,    // Maximum number of lists in tuple
    parameter LIST_SIZE = 8,    // Maximum size of each list
    parameter DATA_WIDTH = 8    // Width of data elements
)(
    input logic [NUM_LISTS-1:0][LIST_SIZE-1:0][DATA_WIDTH-1:0] tuple_data,
    input logic [NUM_LISTS-1:0] list_valid, // High if the list at this index is valid/active
    output logic [3:0] num_lists_out        // Count of valid lists
);

    // Combinational logic to count set bits in list_valid
    // This simulates finding the number of lists present
    always_comb begin
        num_lists_out = 0;
        for (int i = 0; i < NUM_LISTS; i++) begin
            if (list_valid[i]) begin
                num_lists_out = num_lists_out + 1;
            end
        end
    end

endmodule