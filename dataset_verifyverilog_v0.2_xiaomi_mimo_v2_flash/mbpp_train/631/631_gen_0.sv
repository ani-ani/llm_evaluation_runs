module replace_spaces (
    input [127:0] data_in,
    input [3:0] length,
    output reg [127:0] data_out,
    output reg [3:0] out_length
);

    integer i;
    reg [7:0] char_in;
    reg [7:0] char_out;

    always @(*) begin
        // Default assignments
        data_out = data_in;
        out_length = length;

        // Process only valid characters based on length
        // Note: Loop iterates 0 to 15, but we conditionally update based on length
        for (i = 0; i < 16; i = i + 1) begin
            if (i < length) begin
                char_in = data_in[8*i +: 8];
                
                // Transformation logic
                if (char_in == 8'h20) begin
                    char_out = 8'h5F;
                end else if (char_in == 8'h5F) begin
                    char_out = 8'h20;
                end else begin
                    char_out = char_in;
                end

                data_out[8*i +: 8] = char_out;
            end
            // Positions i >= length remain unchanged from data_in (though irrelevant)
        end
    end

endmodule