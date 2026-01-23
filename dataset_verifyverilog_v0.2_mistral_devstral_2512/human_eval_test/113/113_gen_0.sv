module odd_count(
    input [7:0][7:0] input_str,
    output [255:0] result
);

    wire [2:0] count;
    wire [7:0] count_ascii = count + 8'd48; // 0x30

    // Count odd digits (1,3,5,7,9) in parallel
    assign count = 
        (input_str[0] == 8'd49 || input_str[0] == 8'd51 || input_str[0] == 8'd53 || input_str[0] == 8'd55 || input_str[0] == 8'd57) +
        (input_str[1] == 8'd49 || input_str[1] == 8'd51 || input_str[1] == 8'd53 || input_str[1] == 8'd55 || input_str[1] == 8'd57) +
        (input_str[2] == 8'd49 || input_str[2] == 8'd51 || input_str[2] == 8'd53 || input_str[2] == 8'd55 || input_str[2] == 8'd57) +
        (input_str[3] == 8'd49 || input_str[3] == 8'd51 || input_str[3] == 8'd53 || input_str[3] == 8'd55 || input_str[3] == 8'd57) +
        (input_str[4] == 8'd49 || input_str[4] == 8'd51 || input_str[4] == 8'd53 || input_str[4] == 8'd55 || input_str[4] == 8'd57) +
        (input_str[5] == 8'd49 || input_str[5] == 8'd51 || input_str[5] == 8'd53 || input_str[5] == 8'd55 || input_str[5] == 8'd57) +
        (input_str[6] == 8'd49 || input_str[6] == 8'd51 || input_str[6] == 8'd53 || input_str[6] == 8'd55 || input_str[6] == 8'd57) +
        (input_str[7] == 8'd49 || input_str[7] == 8'd51 || input_str[7] == 8'd53 || input_str[7] == 8'd55 || input_str[7] == 8'd57);

    // Generate output string with count substitution
    // Positions 35, 41, 46, 52 should be replaced with count_ascii
    // All other positions use the fixed template
    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : gen_result
            always_comb begin
                if (i == 35 || i == 41 || i == 46 || i == 52) begin
                    result[i] = count_ascii;
                end else begin
                    // Fixed template string
                    case (i)
                        0: result[i] = 8'h74; // 't'
                        1: result[i] = 8'h68; // 'h'
                        2: result[i] = 8'h65; // 'e'
                        3: result[i] = 8'h20; // ' '
                        4: result[i] = 8'h6e; // 'n'
                        5: result[i] = 8'h75; // 'u'
                        6: result[i] = 8'h6d; // 'm'
                        7: result[i] = 8'h62; // 'b'
                        8: result[i] = 8'h65; // 'e'
                        9: result[i] = 8'h72; // 'r'
                        10: result[i] = 8'h20; // ' '
                        11: result[i] = 8'h6f; // 'o'
                        12: result[i] = 8'h66; // 'f'
                        13: result[i] = 8'h20; // ' '
                        14: result[i] = 8'h6f; // 'o'
                        15: result[i] = 8'h64; // 'd'
                        16: result[i] = 8'h64; // 'd'
                        17: result[i] = 8'h20; // ' '
                        18: result[i] = 8'h65; // 'e'
                        19: result[i] = 8'h6c; // 'l'
                        20: result[i] = 8'h65; // 'e'
                        21: result[i] = 8'h6d; // 'm'
                        22: result[i] = 8'h65; // 'e'
                        23: result[i] = 8'h6e; // 'n'
                        24: result[i] = 8'h74; // 't'
                        25: result[i] = 8'h73; // 's'
                        26: result[i] = 8'h20; // ' '
                        27: result[i] = 8'h6e; // 'n'
                        28: result[i] = 8'h20; // ' '
                        29: result[i] = 8'h74; // 't'
                        30: result[i] = 8'h68; // 'h'
                        31: result[i] = 8'h65; // 'e'
                        32: result[i] = 8'h20; // ' '
                        33: result[i] = 8'h73; // 's'
                        34: result[i] = 8'h74; // 't'
                        35: result[i] = 8'h72; // 'r' (replaced by count)
                        36: result[i] = 8'h6e; // 'n'
                        37: result[i] = 8'h67; // 'g'
                        38: result[i] = 8'h20; // ' '
                        39: result[i] = 8'h6e; // 'n'
                        40: result[i] = 8'h20; // ' '
                        41: result[i] = 8'h6f; // 'o' (replaced by count)
                        42: result[i] = 8'h66; // 'f'
                        43: result[i] = 8'h20; // ' '
                        44: result[i] = 8'h74; // 't'
                        45: result[i] = 8'h68; // 'h'
                        46: result[i] = 8'h65; // 'e' (replaced by count)
                        47: result[i] = 8'h20; // ' '
                        48: result[i] = 8'h6f; // 'o'
                        49: result[i] = 8'h66; // 'f'
                        50: result[i] = 8'h20; // ' '
                        51: result[i] = 8'h74; // 't'
                        52: result[i] = 8'h68; // 'h' (replaced by count)
                        53: result[i] = 8'h65; // 'e'
                        54: result[i] = 8'h20; // ' '
                        55: result[i] = 8'h6e; // 'n'
                        56: result[i] = 8'h70; // 'p'
                        57: result[i] = 8'h75; // 'u'
                        58: result[i] = 8'h74; // 't'
                        59: result[i] = 8'h2e; // '.'
                        default: result[i] = 8'h00; // Null for unused positions
                    endcase
                end
            end
        end
    endgenerate

endmodule