module remove_nested (
    input [7:0] data_in [0:7],
    output logic [7:0] data_out [0:7]
);

    integer i;
    integer write_idx;

    always_comb begin
        // 1. Initialize all output elements to 8'hFF
        for (int j = 0; j < 8; j++) begin
            data_out[j] = 8'hFF;
        end

        write_idx = 0;

        // 2. Iterate through the input array
        for (i = 0; i < 8; i++) begin
            // 3. If element is not 8'hFF (valid integer)
            if (data_in[i] != 8'hFF) begin
                // Place it into the next available slot
                data_out[write_idx] = data_in[i];
                write_idx = write_idx + 1;
            end
            // 4. If element is 8'hFF, skip it (implicit)
        end
    end

endmodule
