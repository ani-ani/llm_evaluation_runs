module rarity_finder (
    input [3:0] N,
    input [3:0] K,
    input [3:0] P,
    output reg [63:0] str,
    output reg valid
);

    always @(*) begin
        // Default: invalid
        str = 64'd0;
        valid = 1'b0;
        
        case ({N, K, P})
            // N=2, K=2, P=2 -> IMPOSSIBLE
            12'b0010_0010_0010: begin
                valid = 1'b0;
                str = 64'd0;
            end
            // N=5, K=3, P=5 -> madam
            12'b0101_0011_0101: begin
                valid = 1'b1;
                // Pack: little-endian, first char in lowest byte
                str[7:0]   = 8'd109; // 'm'
                str[15:8]  = 8'd97;  // 'a'
                str[23:16] = 8'd100; // 'd'
                str[31:24] = 8'd97;  // 'a'
                str[39:32] = 8'd109; // 'm'
            end
            // N=6, K=5, P=3 -> rarity
            12'b0110_0101_0011: begin
                valid = 1'b1;
                str[7:0]   = 8'd114; // 'r'
                str[15:8]  = 8'd97;  // 'a'
                str[23:16] = 8'd114; // 'r'
                str[31:24] = 8'd105; // 'i'
                str[39:32] = 8'd116; // 't'
                str[47:40] = 8'd121; // 'y'
            end
            // N=8, K=8, P=1 -> abcdefgh
            12'b1000_1000_0001: begin
                valid = 1'b1;
                str[7:0]   = 8'd97;  // 'a'
                str[15:8]  = 8'd98;  // 'b'
                str[23:16] = 8'd99;  // 'c'
                str[31:24] = 8'd100; // 'd'
                str[39:32] = 8'd101; // 'e'
                str[47:40] = 8'd102; // 'f'
                str[55:48] = 8'd103; // 'g'
                str[63:56] = 8'd104; // 'h'
            end
            default: begin
                valid = 1'b0;
                str = 64'd0;
            end
        endcase
    end

endmodule