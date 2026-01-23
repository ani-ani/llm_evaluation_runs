module find_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [63:0] k,
    output reg [7:0] char,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] RECURSE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Fixed strings as packed arrays (max 75 chars per string)
    // f0: "What are you doing at the end of the world? Are you busy? Will you save us?"
    reg [7:0] f0;
    // prefix: "What are you doing while sending \""
    reg [7:0] prefix;
    // middle: "\"? Are you busy? Will you send \""
    reg [7:0] middle;
    // suffix: "\"?"
    reg [7:0] suffix;

    // Length lookup table (n=0 to 10)
    reg [63:0] length [0:10];

    // Internal registers
    reg [2:0] state;
    reg [7:0] curr_n;
    reg [63:0] curr_k;
    reg [7:0] char_temp;

    // Initialize length table (computed at compile time)
    initial begin
        length[0] = 75;
        length[1] = 218;
        length[2] = 504;
        length[3] = 1076;
        length[4] = 2220;
        length[5] = 4508;
        length[6] = 9084;
        length[7] = 18236;
        length[8] = 36540;
        length[9] = 73148;
        length[10] = 146364;
    end

    // Combinational logic to read character from string
    always @(*) begin
        // Default values
        f0 = 8'd0;
        prefix = 8'd0;
        middle = 8'd0;
        suffix = 8'd0;

        // f0: 75 chars (indexed 0-74)
        case (curr_k)
            0: f0 = 8'd87;  // 'W'
            1: f0 = 8'd104; // 'h'
            2: f0 = 8'd97;  // 'a'
            3: f0 = 8'd116; // 't'
            4: f0 = 8'd32;  // ' '
            5: f0 = 8'd97;  // 'a'
            6: f0 = 8'd114; // 'r'
            7: f0 = 8'd101; // 'e'
            8: f0 = 8'd32;  // ' '
            9: f0 = 8'd121; // 'y'
            10: f0 = 8'd111; // 'o'
            11: f0 = 8'd117; // 'u'
            12: f0 = 8'd32;  // ' '
            13: f0 = 8'd100; // 'd'
            14: f0 = 8'd111; // 'o'
            15: f0 = 8'd105; // 'i'
            16: f0 = 8'd110; // 'n'
            17: f0 = 8'd103; // 'g'
            18: f0 = 8'd32;  // ' '
            19: f0 = 8'd97;  // 'a'
            20: f0 = 8'd116; // 't'
            21: f0 = 8'd32;  // ' '
            22: f0 = 8'd116; // 't'
            23: f0 = 8'd104; // 'h'
            24: f0 = 8'd101; // 'e'
            25: f0 = 8'd32;  // ' '
            26: f0 = 8'd101; // 'e'
            27: f0 = 8'd110; // 'n'
            28: f0 = 8'd100; // 'd'
            29: f0 = 8'd32;  // ' '
            30: f0 = 8'd111; // 'o'
            31: f0 = 8'd102; // 'f'
            32: f0 = 8'd32;  // ' '
            33: f0 = 8'd116; // 't'
            34: f0 = 8'd104; // 'h'
            35: f0 = 8'd101; // 'e'
            36: f0 = 8'd32;  // ' '
            37: f0 = 8'd119; // 'w'
            38: f0 = 8'd111; // 'o'
            39: f0 = 8'd114; // 'r'
            40: f0 = 8'd108; // 'l'
            41: f0 = 8'd100; // 'd'
            42: f0 = 8'd63;  // '?'
            43: f0 = 8'd32;  // ' '
            44: f0 = 8'd65;  // 'A'
            45: f0 = 8'd114; // 'r'
            46: f0 = 8'd101; // 'e'
            47: f0 = 8'd32;  // ' '
            48: f0 = 8'd121; // 'y'
            49: f0 = 8'd111; // 'o'
            50: f0 = 8'd117; // 'u'
            51: f0 = 8'd32;  // ' '
            52: f0 = 8'd98;  // 'b'
            53: f0 = 8'd117; // 'u'
            54: f0 = 8'd115; // 's'
            55: f0 = 8'd121; // 'y'
            56: f0 = 8'd63;  // '?'
            57: f0 = 8'd32;  // ' '
            58: f0 = 8'd87;  // 'W'
            59: f0 = 8'd105; // 'i'
            60: f0 = 8'd108; // 'l'
            61: f0 = 8'd108; // 'l'
            62: f0 = 8'd32;  // ' '
            63: f0 = 8'd121; // 'y'
            64: f0 = 8'd111; // 'o'
            65: f0 = 8'd117; // 'u'
            66: f0 = 8'd32;  // ' '
            67: f0 = 8'd115; // 's'
            68: f0 = 8'd97;  // 'a'
            69: f0 = 8'd118; // 'v'
            70: f0 = 8'd101; // 'e'
            71: f0 = 8'd32;  // ' '
            72: f0 = 8'd117; // 'u'
            73: f0 = 8'd115; // 's'
            74: f0 = 8'd63;  // '?'
            default: f0 = 8'd0;
        endcase

        // prefix: 34 chars (indexed 0-33)
        case (curr_k)
            0: prefix = 8'd87;
            1: prefix = 8'd104;
            2: prefix = 8'd97;
            3: prefix = 8'd116;
            4: prefix = 8'd32;
            5: prefix = 8'd97;
            6: prefix = 8'd114;
            7: prefix = 8'd101;
            8: prefix = 8'd32;
            9: prefix = 8'd121;
            10: prefix = 8'd111;
            11: prefix = 8'd117;
            12: prefix = 8'd32;
            13: prefix = 8'd100;
            14: prefix = 8'd111;
            15: prefix = 8'd105;
            16: prefix = 8'd110;
            17: prefix = 8'd103;
            18: prefix = 8'd32;
            19: prefix = 8'd119;
            20: prefix = 8'd104;
            21: prefix = 8'd105;
            22: prefix = 8'd108;
            23: prefix = 8'd101;
            24: prefix = 8'd32;
            25: prefix = 8'd115;
            26: prefix = 8'd101;
            27: prefix = 8'd110;
            28: prefix = 8'd100;
            29: prefix = 8'd105;
            30: prefix = 8'd110;
            31: prefix = 8'd103;
            32: prefix = 8'd32;
            33: prefix = 8'd34;
            default: prefix = 8'd0;
        endcase

        // middle: 32 chars (indexed 0-31)
        case (curr_k)
            0: middle = 8'd34;
            1: middle = 8'd63;
            2: middle = 8'd32;
            3: middle = 8'd65;
            4: middle = 8'd114;
            5: middle = 8'd101;
            6: middle = 8'd32;
            7: middle = 8'd121;
            8: middle = 8'd111;
            9: middle = 8'd117;
            10: middle = 8'd32;
            11: middle = 8'd98;
            12: middle = 8'd117;
            13: middle = 8'd115;
            14: middle = 8'd121;
            15: middle = 8'd63;
            16: middle = 8'd32;
            17: middle = 8'd87;
            18: middle = 8'd105;
            19: middle = 8'd108;
            20: middle = 8'd108;
            21: middle = 8'd32;
            22: middle = 8'd121;
            23: middle = 8'd111;
            24: middle = 8'd117;
            25: middle = 8'd32;
            26: middle = 8'd115;
            27: middle = 8'd101;
            28: middle = 8'd110;
            29: middle = 8'd100;
            30: middle = 8'd32;
            31: middle = 8'd34;
            default: middle = 8'd0;
        endcase

        // suffix: 2 chars (indexed 0-1)
        case (curr_k)
            0: suffix = 8'd34;
            1: suffix = 8'd63;
            default: suffix = 8'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            char <= 8'd0;
            curr_n <= 8'd0;
            curr_k <= 64'd0;
            char_temp <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        curr_n <= (n > 8'd10) ? 8'd10 : n;
                        curr_k <= k;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (curr_n == 8'd0) begin
                        if (curr_k <= 75 && curr_k > 64'd0) begin
                            // Get char from f0
                            if (curr_k <= 75) begin
                                // f0 is indexed from 0-74
                                char <= f0;
                            end else begin
                                char <= 8'd46; // '.'
                            end
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            char <= 8'd46; // '.'
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end else if (curr_k <= 34) begin
                        char <= prefix;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end else if (curr_k <= 34 + length[curr_n - 1]) begin
                        // Recursive call for first part
                        curr_k <= curr_k - 34;
                        curr_n <= curr_n - 8'd1;
                        state <= RECURSE;
                    end else if (curr_k <= 34 + length[curr_n - 1] + 32) begin
                        // Middle string
                        char <= middle;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end else if (curr_k <= 34 + length[curr_n - 1] + 32 + length[curr_n - 1]) begin
                        // Recursive call for second part
                        curr_k <= curr_k - 34 - length[curr_n - 1] - 32;
                        curr_n <= curr_n - 8'd1;
                        state <= RECURSE;
                    end else if (curr_k <= 34 + length[curr_n - 1] + 32 + length[curr_n - 1] + 2) begin
                        // Suffix string
                        char <= suffix;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        // Out of bounds
                        char <= 8'd46; // '.'
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                RECURSE: begin
                    // Keep recursing until done
                    state <= CHECK;
                end

                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule