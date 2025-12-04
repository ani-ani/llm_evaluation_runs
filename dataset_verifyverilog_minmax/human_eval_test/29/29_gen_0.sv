module string_filter (
    input [255:0] strings_flat,
    input [63:0] prefix,
    input [2:0] prefix_len,
    output [3:0] match_mask
);

    // Extract the four strings
    wire [63:0] string0 = strings_flat[63:0];
    wire [63:0] string1 = strings_flat[127:64];
    wire [63:0] string2 = strings_flat[191:128];
    wire [63:0] string3 = strings_flat[255:192];

    // Generate the mask for the prefix
    reg [63:0] mask;
    always_comb begin
        case (prefix_len)
            0: mask = 64'b0;
            1: mask = 64'hFF << 56;
            2: mask = 64'hFFFF << 48;
            3: mask = 64'hFFFFFF << 40;
            4: mask = 64'hFFFFFFFF << 32;
            5: mask = 64'hFFFFFFFFFF << 24;
            6: mask = 64'hFFFFFFFFFFFF << 16;
            7: mask = 64'hFFFFFFFFFFFFFF << 8;
        endcase
    end

    // Assign the match_mask
    assign match_mask[0] = ( (string0 & mask) == (prefix & mask) );
    assign match_mask[1] = ( (string1 & mask) == (prefix & mask) );
    assign match_mask[2] = ( (string2 & mask) == (prefix & mask) );
    assign match_mask[3] = ( (string3 & mask) == (prefix & mask) );

endmodule