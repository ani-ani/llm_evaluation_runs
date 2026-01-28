module DecimalToRoman (
    input [9:0] num,
    output reg [63:0] result,
    output reg [3:0] len
);
    // Digit extraction
    reg [9:0] num_reg;
    reg [3:0] thousands, hundreds, tens, ones;
    
    // Lookup data structures - ASCII bytes and lengths
    // Thousands (0-1)
    reg [7:0] th_bytes [0:0];  // Only 1 possible non-zero value (1 -> "m")
    reg [3:0] th_len [0:0];
    
    // Hundreds (0-9)
    reg [7:0] h_bytes [0:9][0:3];  // Max 3 chars for hundreds
    reg [3:0] h_len [0:9];
    
    // Tens (0-9)
    reg [7:0] t_bytes [0:9][0:3];  // Max 3 chars for tens
    reg [3:0] t_len [0:9];
    
    // Ones (0-9)
    reg [7:0] o_bytes [0:9][0:3];  // Max 3 chars for ones
    reg [3:0] o_len [0:9];
    
    // Output buffers
    reg [7:0] out_bytes [0:7];  // Maximum 7 chars + 1 for safety
    
    integer i, j, pos;
    
    // Initialize lookup tables
    initial begin
        // Thousands
        th_bytes[0] = 8'h6D;  // 'm' = 109
        th_len[0] = 4'd1;
        
        // Hundreds: 0-9
        // 0: empty
        h_len[0] = 4'd0;
        
        // 1: "c" (1 char)
        h_bytes[1][0] = 8'h63;  // 'c' = 99
        h_len[1] = 4'd1;
        
        // 2: "cc" (2 chars)
        h_bytes[2][0] = 8'h63;
        h_bytes[2][1] = 8'h63;
        h_len[2] = 4'd2;
        
        // 3: "ccc" (3 chars)
        h_bytes[3][0] = 8'h63;
        h_bytes[3][1] = 8'h63;
        h_bytes[3][2] = 8'h63;
        h_len[3] = 4'd3;
        
        // 4: "cd" (2 chars)
        h_bytes[4][0] = 8'h63;  // 'c' = 99
        h_bytes[4][1] = 8'h64;  // 'd' = 100
        h_len[4] = 4'd2;
        
        // 5: "d" (1 char)
        h_bytes[5][0] = 8'h64;  // 'd' = 100
        h_len[5] = 4'd1;
        
        // 6: "dc" (2 chars)
        h_bytes[6][0] = 8'h64;  // 'd' = 100
        h_bytes[6][1] = 8'h63;  // 'c' = 99
        h_len[6] = 4'd2;
        
        // 7: "dcc" (3 chars)
        h_bytes[7][0] = 8'h64;
        h_bytes[7][1] = 8'h63;
        h_bytes[7][2] = 8'h63;
        h_len[7] = 4'd3;
        
        // 8: "dccc" (4 chars)
        h_bytes[8][0] = 8'h64;
        h_bytes[8][1] = 8'h63;
        h_bytes[8][2] = 8'h63;
        h_bytes[8][3] = 8'h63;
        h_len[8] = 4'd4;
        
        // 9: "cm" (2 chars)
        h_bytes[9][0] = 8'h63;  // 'c' = 99
        h_bytes[9][1] = 8'h6D;  // 'm' = 109
        h_len[9] = 4'd2;
        
        // Tens: 0-9 (using x, l, etc.)
        // 0: empty
        t_len[0] = 4'd0;
        
        // 1: "x" (1 char)
        t_bytes[1][0] = 8'h78;  // 'x' = 120
        t_len[1] = 4'd1;
        
        // 2: "xx" (2 chars)
        t_bytes[2][0] = 8'h78;
        t_bytes[2][1] = 8'h78;
        t_len[2] = 4'd2;
        
        // 3: "xxx" (3 chars)
        t_bytes[3][0] = 8'h78;
        t_bytes[3][1] = 8'h78;
        t_bytes[3][2] = 8'h78;
        t_len[3] = 4'd3;
        
        // 4: "xl" (2 chars)
        t_bytes[4][0] = 8'h78;  // 'x' = 120
        t_bytes[4][1] = 8'h6C;  // 'l' = 108
        t_len[4] = 4'd2;
        
        // 5: "l" (1 char)
        t_bytes[5][0] = 8'h6C;  // 'l' = 108
        t_len[5] = 4'd1;
        
        // 6: "lx" (2 chars)
        t_bytes[6][0] = 8'h6C;  // 'l' = 108
        t_bytes[6][1] = 8'h78;  // 'x' = 120
        t_len[6] = 4'd2;
        
        // 7: "lxx" (3 chars)
        t_bytes[7][0] = 8'h6C;
        t_bytes[7][1] = 8'h78;
        t_bytes[7][2] = 8'h78;
        t_len[7] = 4'd3;
        
        // 8: "lxxx" (4 chars)
        t_bytes[8][0] = 8'h6C;
        t_bytes[8][1] = 8'h78;
        t_bytes[8][2] = 8'h78;
        t_bytes[8][3] = 8'h78;
        t_len[8] = 4'd4;
        
        // 9: "xc" (2 chars)
        t_bytes[9][0] = 8'h78;  // 'x' = 120
        t_bytes[9][1] = 8'h63;  // 'c' = 99
        t_len[9] = 4'd2;
        
        // Ones: 0-9
        // 0: empty
        o_len[0] = 4'd0;
        
        // 1: "i" (1 char)
        o_bytes[1][0] = 8'h69;  // 'i' = 105
        o_len[1] = 4'd1;
        
        // 2: "ii" (2 chars)
        o_bytes[2][0] = 8'h69;
        o_bytes[2][1] = 8'h69;
        o_len[2] = 4'd2;
        
        // 3: "iii" (3 chars)
        o_bytes[3][0] = 8'h69;
        o_bytes[3][1] = 8'h69;
        o_bytes[3][2] = 8'h69;
        o_len[3] = 4'd3;
        
        // 4: "iv" (2 chars)
        o_bytes[4][0] = 8'h69;  // 'i' = 105
        o_bytes[4][1] = 8'h76;  // 'v' = 118
        o_len[4] = 4'd2;
        
        // 5: "v" (1 char)
        o_bytes[5][0] = 8'h76;  // 'v' = 118
        o_len[5] = 4'd1;
        
        // 6: "vi" (2 chars)
        o_bytes[6][0] = 8'h76;  // 'v' = 118
        o_bytes[6][1] = 8'h69;  // 'i' = 105
        o_len[6] = 4'd2;
        
        // 7: "vii" (3 chars)
        o_bytes[7][0] = 8'h76;
        o_bytes[7][1] = 8'h69;
        o_bytes[7][2] = 8'h69;
        o_len[7] = 4'd3;
        
        // 8: "viii" (4 chars)
        o_bytes[8][0] = 8'h76;
        o_bytes[8][1] = 8'h69;
        o_bytes[8][2] = 8'h69;
        o_bytes[8][3] = 8'h69;
        o_len[8] = 4'd4;
        
        // 9: "ix" (2 chars)
        o_bytes[9][0] = 8'h69;  // 'i' = 105
        o_bytes[9][1] = 8'h78;  // 'x' = 120
        o_len[9] = 4'd2;
    end
    
    // Combinational logic
    always @(*) begin
        // Extract digits
        num_reg = num;
        thousands = num_reg / 10'd1000;
        hundreds = (num_reg % 10'd1000) / 10'd100;
        tens = (num_reg % 10'd100) / 10'd10;
        ones = num_reg % 10'd10;
        
        // Calculate lengths
        // Note: thousands only has value 1, others 0-9
        len = 4'd0;
        
        // Add thousands length (only if thousands == 1)
        if (thousands == 4'd1) begin
            len = len + th_len[0];
        end
        
        // Add hundreds length
        len = len + h_len[hundreds];
        
        // Add tens length
        len = len + t_len[tens];
        
        // Add ones length
        len = len + o_len[ones];
        
        // Initialize output bytes to 0
        for (i = 0; i < 8; i = i + 1) begin
            out_bytes[i] = 8'd0;
        end
        
        // Pack bytes in order: thousands, hundreds, tens, ones
        pos = 0;
        
        // Thousands (if present)
        if (thousands == 4'd1) begin
            for (i = 0; i < 1; i = i + 1) begin
                if (i < th_len[0]) begin
                    out_bytes[pos] = th_bytes[i];
                    pos = pos + 1;
                end
            end
        end
        
        // Hundreds
        for (i = 0; i < 4; i = i + 1) begin
            if (i < h_len[hundreds]) begin
                out_bytes[pos] = h_bytes[hundreds][i];
                pos = pos + 1;
            end
        end
        
        // Tens
        for (i = 0; i < 4; i = i + 1) begin
            if (i < t_len[tens]) begin
                out_bytes[pos] = t_bytes[tens][i];
                pos = pos + 1;
            end
        end
        
        // Ones
        for (i = 0; i < 4; i = i + 1) begin
            if (i < o_len[ones]) begin
                out_bytes[pos] = o_bytes[ones][i];
                pos = pos + 1;
            end
        end
        
        // Pack into 64-bit result (little-endian: first byte at LSB)
        result = {
            out_bytes[7], out_bytes[6], out_bytes[5], out_bytes[4],
            out_bytes[3], out_bytes[2], out_bytes[1], out_bytes[0]
        };
    end
endmodule