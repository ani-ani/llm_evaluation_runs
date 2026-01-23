module uppercase_counter (
    input [7:0][7:0] char_array,
    input [2:0] valid_length,
    output logic [3:0] count
);

    logic [7:0] is_upper [8];

    always_comb begin
        count = 4'd0;
        for (int i = 0; i < 8; i++) begin
            // Check if index is valid
            if (i < valid_length) begin
                // Check if character is uppercase ASCII ('A' to 'Z')
                if ((char_array[i] >= 8'h41) && (char_array[i] <= 8'h5A)) begin
                    count = count + 4'd1;
                end
            end
        end
    end

endmodule