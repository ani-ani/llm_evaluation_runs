module MaxScorePartition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] k,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PRECOMPUTE = 2'd1;
    localparam [1:0] ENUMERATE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] seg_score [0:7][0:7];
    reg [7:0] temp_min, temp_max;
    reg [3:0] i, j, p, split;
    reg [7:0] current_gcd;
    integer iter;
    reg [7:0] arr [0:7];

    // Helper function for GCD
    function [7:0] gcd;
        input [7:0] a, b;
        reg [7:0] x, y, temp;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            gcd = x;
        end
    endfunction

    // Helper function for largest prime factor
    function [7:0] largest_prime_factor;
        input [7:0] n;
        begin
            case (n)
                0: largest_prime_factor = 8'd0;
                1: largest_prime_factor = 8'd0;
                2: largest_prime_factor = 8'd2;
                3: largest_prime_factor = 8'd3;
                4: largest_prime_factor = 8'd2;
                5: largest_prime_factor = 8'd5;
                6: largest_prime_factor = 8'd3;
                7: largest_prime_factor = 8'd7;
                8: largest_prime_factor = 8'd2;
                9: largest_prime_factor = 8'd3;
                10: largest_prime_factor = 8'd5;
                11: largest_prime_factor = 8'd11;
                12: largest_prime_factor = 8'd3;
                13: largest_prime_factor = 8'd13;
                14: largest_prime_factor = 8'd7;
                15: largest_prime_factor = 8'd5;
                16: largest_prime_factor = 8'd2;
                17: largest_prime_factor = 8'd17;
                18: largest_prime_factor = 8'd3;
                19: largest_prime_factor = 8'd19;
                20: largest_prime_factor = 8'd5;
                21: largest_prime_factor = 8'd7;
                22: largest_prime_factor = 8'd11;
                23: largest_prime_factor = 8'd23;
                24: largest_prime_factor = 8'd3;
                25: largest_prime_factor = 8'd5;
                26: largest_prime_factor = 8'd13;
                27: largest_prime_factor = 8'd3;
                28: largest_prime_factor = 8'd7;
                29: largest_prime_factor = 8'd29;
                30: largest_prime_factor = 8'd5;
                31: largest_prime_factor = 8'd31;
                32: largest_prime_factor = 8'd2;
                33: largest_prime_factor = 8'd11;
                34: largest_prime_factor = 8'd17;
                35: largest_prime_factor = 8'd7;
                36: largest_prime_factor = 8'd3;
                37: largest_prime_factor = 8'd37;
                38: largest_prime_factor = 8'd19;
                39: largest_prime_factor = 8'd13;
                40: largest_prime_factor = 8'd5;
                41: largest_prime_factor = 8'd41;
                42: largest_prime_factor = 8'd7;
                43: largest_prime_factor = 8'd43;
                44: largest_prime_factor = 8'd11;
                45: largest_prime_factor = 8'd5;
                46: largest_prime_factor = 8'd23;
                47: largest_prime_factor = 8'd47;
                48: largest_prime_factor = 8'd3;
                49: largest_prime_factor = 8'd7;
                50: largest_prime_factor = 8'd5;
                51: largest_prime_factor = 8'd17;
                52: largest_prime_factor = 8'd13;
                53: largest_prime_factor = 8'd53;
                54: largest_prime_factor = 8'd3;
                55: largest_prime_factor = 8'd11;
                56: largest_prime_factor = 8'd7;
                57: largest_prime_factor = 8'd19;
                58: largest_prime_factor = 8'd29;
                59: largest_prime_factor = 8'd59;
                60: largest_prime_factor = 8'd5;
                61: largest_prime_factor = 8'd61;
                62: largest_prime_factor = 8'd31;
                63: largest_prime_factor = 8'd7;
                64: largest_prime_factor = 8'd2;
                65: largest_prime_factor = 8'd13;
                66: largest_prime_factor = 8'd11;
                67: largest_prime_factor = 8'd67;
                68: largest_prime_factor = 8'd17;
                69: largest_prime_factor = 8'd23;
                70: largest_prime_factor = 8'd7;
                71: largest_prime_factor = 8'd71;
                72: largest_prime_factor = 8'd3;
                73: largest_prime_factor = 8'd73;
                74: largest_prime_factor = 8'd37;
                75: largest_prime_factor = 8'd5;
                76: largest_prime_factor = 8'd19;
                77: largest_prime_factor = 8'd11;
                78: largest_prime_factor = 8'd13;
                79: largest_prime_factor = 8'd79;
                80: largest_prime_factor = 8'd5;
                81: largest_prime_factor = 8'd3;
                82: largest_prime_factor = 8'd41;
                83: largest_prime_factor = 8'd83;
                84: largest_prime_factor = 8'd7;
                85: largest_prime_factor = 8'd17;
                86: largest_prime_factor = 8'd43;
                87: largest_prime_factor = 8'd29;
                88: largest_prime_factor = 8'd11;
                89: largest_prime_factor = 8'd89;
                90: largest_prime_factor = 8'd5;
                91: largest_prime_factor = 8'd13;
                92: largest_prime_factor = 8'd23;
                93: largest_prime_factor = 8'd31;
                94: largest_prime_factor = 8'd47;
                95: largest_prime_factor = 8'd19;
                96: largest_prime_factor = 8'd3;
                97: largest_prime_factor = 8'd97;
                98: largest_prime_factor = 8'd7;
                99: largest_prime_factor = 8'd11;
                100: largest_prime_factor = 8'd5;
                101: largest_prime_factor = 8'd101;
                102: largest_prime_factor = 8'd17;
                103: largest_prime_factor = 8'd103;
                104: largest_prime_factor = 8'd13;
                105: largest_prime_factor = 8'd7;
                106: largest_prime_factor = 8'd53;
                107: largest_prime_factor = 8'd107;
                108: largest_prime_factor = 8'd3;
                109: largest_prime_factor = 8'd109;
                110: largest_prime_factor = 8'd11;
                111: largest_prime_factor = 8'd37;
                112: largest_prime_factor = 8'd7;
                113: largest_prime_factor = 8'd113;
                114: largest_prime_factor = 8'd19;
                115: largest_prime_factor = 8'd23;
                116: largest_prime_factor = 8'd29;
                117: largest_prime_factor = 8'd13;
                118: largest_prime_factor = 8'd59;
                119: largest_prime_factor = 8'd17;
                120: largest_prime_factor = 8'd5;
                121: largest_prime_factor = 8'd11;
                122: largest_prime_factor = 8'd61;
                123: largest_prime_factor = 8'd41;
                124: largest_prime_factor = 8'd31;
                125: largest_prime_factor = 8'd5;
                126: largest_prime_factor = 8'd7;
                127: largest_prime_factor = 8'd127;
                128: largest_prime_factor = 8'd2;
                129: largest_prime_factor = 8'd43;
                130: largest_prime_factor = 8'd13;
                131: largest_prime_factor = 8'd131;
                132: largest_prime_factor = 8'd11;
                133: largest_prime_factor = 8'd7;
                134: largest_prime_factor = 8'd67;
                135: largest_prime_factor = 8'd5;
                136: largest_prime_factor = 8'd17;
                137: largest_prime_factor = 8'd137;
                138: largest_prime_factor = 8'd23;
                139: largest_prime_factor = 8'd139;
                140: largest_prime_factor = 8'd7;
                141: largest_prime_factor = 8'd47;
                142: largest_prime_factor = 8'd71;
                143: largest_prime_factor = 8'd11;
                144: largest_prime_factor = 8'd3;
                145: largest_prime_factor = 8'd29;
                146: largest_prime_factor = 8'd73;
                147: largest_prime_factor = 8'd7;
                148: largest_prime_factor = 8'd37;
                149: largest_prime_factor = 8'd149;
                150: largest_prime_factor = 8'd5;
                151: largest_prime_factor = 8'd151;
                152: largest_prime_factor = 8'd19;
                153: largest_prime_factor = 8'd17;
                154: largest_prime_factor = 8'd7;
                155: largest_prime_factor = 8'd31;
                156: largest_prime_factor = 8'd13;
                157: largest_prime_factor = 8'd157;
                158: largest_prime_factor = 8'd79;
                159: largest_prime_factor = 8'd53;
                160: largest_prime_factor = 8'd5;
                161: largest_prime_factor = 8'd23;
                162: largest_prime_factor = 8'd3;
                163: largest_prime_factor = 8'd163;
                164: largest_prime_factor = 8'd41;
                165: largest_prime_factor = 8'd11;
                166: largest_prime_factor = 8'd83;
                167: largest_prime_factor = 8'd167;
                168: largest_prime_factor = 8'd7;
                169: largest_prime_factor = 8'd13;
                170: largest_prime_factor = 8'd17;
                171: largest_prime_factor = 8'd19;
                172: largest_prime_factor = 8'd43;
                173: largest_prime_factor = 8'd173;
                174: largest_prime_factor = 8'd29;
                175: largest_prime_factor = 8'd7;
                176: largest_prime_factor = 8'd11;
                177: largest_prime_factor = 8'd59;
                178: largest_prime_factor = 8'd89;
                179: largest_prime_factor = 8'd179;
                180: largest_prime_factor = 8'd5;
                181: largest_prime_factor = 8'd181;
                182: largest_prime_factor = 8'd7;
                183: largest_prime_factor = 8'd183;
                184: largest_prime_factor = 8'd23;
                185: largest_prime_factor = 8'd37;
                186: largest_prime_factor = 8'd93;
                187: largest_prime_factor = 8'd11;
                188: largest_prime_factor = 8'd47;
                189: largest_prime_factor = 8'd31;
                190: largest_prime_factor = 8'd19;
                191: largest_prime_factor = 8'd191;
                192: largest_prime_factor = 8'd3;
                193: largest_prime_factor = 8'd193;
                194: largest_prime_factor = 8'd97;
                195: largest_prime_factor = 8'd13;
                196: largest_prime_factor = 8'd49;
                197: largest_prime_factor = 8'd197;
                198: largest_prime_factor = 8'd11;
                199: largest_prime_factor = 8'd199;
                200: largest_prime_factor = 8'd5;
                201: largest_prime_factor = 8'd67;
                202: largest_prime_factor = 8'd101;
                203: largest_prime_factor = 8'd7;
                204: largest_prime_factor = 8'd17;
                205: largest_prime_factor = 8'd41;
                206: largest_prime_factor = 8'd103;
                207: largest_prime_factor = 8'd23;
                208: largest_prime_factor = 8'd13;
                209: largest_prime_factor = 8'd11;
                210: largest_prime_factor = 8'd7;
                211: largest_prime_factor = 8'd211;
                212: largest_prime_factor = 8'd53;
                213: largest_prime_factor = 8'd71;
                214: largest_prime_factor = 8'd107;
                215: largest_prime_factor = 8'd43;
                216: largest_prime_factor = 8'd3;
                217: largest_prime_factor = 8'd31;
                218: largest_prime_factor = 8'd109;
                219: largest_prime_factor = 8'd73;
                220: largest_prime_factor = 8'd11;
                221: largest_prime_factor = 8'd13;
                222: largest_prime_factor = 8'd37;
                223: largest_prime_factor = 8'd223;
                224: largest_prime_factor = 8'd7;
                225: largest_prime_factor = 8'd5;
                226: largest_prime_factor = 8'd113;
                227: largest_prime_factor = 8'd227;
                228: largest_prime_factor = 8'd19;
                229: largest_prime_factor = 8'd229;
                230: largest_prime_factor = 8'd23;
                231: largest_prime_factor = 8'd7;
                232: largest_prime_factor = 8'd29;
                233: largest_prime_factor = 8'd233;
                234: largest_prime_factor = 8'd13;
                235: largest_prime_factor = 8'd47;
                236: largest_prime_factor = 8'd59;
                237: largest_prime_factor = 8'd79;
                238: largest_prime_factor = 8'd7;
                239: largest_prime_factor = 8'd239;
                240: largest_prime_factor = 8'd5;
                241: largest_prime_factor = 8'd241;
                242: largest_prime_factor = 8'd11;
                243: largest_prime_factor = 8'd81;
                244: largest_prime_factor = 8'd61;
                245: largest_prime_factor = 8'd49;
                246: largest_prime_factor = 8'd41;
                247: largest_prime_factor = 8'd13;
                248: largest_prime_factor = 8'd31;
                249: largest_prime_factor = 8'd49;
                250: largest_prime_factor = 8'd5;
                251: largest_prime_factor = 8'd251;
                252: largest_prime_factor = 8'd7;
                253: largest_prime_factor = 8'd11;
                254: largest_prime_factor = 8'd127;
                255: largest_prime_factor = 8'd5;
                default: largest_prime_factor = 8'd0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            temp_min <= 8'd0;
            temp_max <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            p <= 4'd0;
            split <= 4'd0;
            current_gcd <= 8'd0;
            for (iter = 0; iter < 8; iter = iter + 1) begin
                for (integer iter2 = 0; iter2 < 8; iter2 = iter2 + 1) begin
                    seg_score[iter][iter2] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = PRECOMPUTE;
                    i = 4'd0;
                    j = 4'd0;
                    p = 4'd0;
                    split = 4'd0;
                    temp_min = 8'd0;
                    temp_max = 8'd0;
                    arr[0] = arr_0;
                    arr[1] = arr_1;
                    arr[2] = arr_2;
                    arr[3] = arr_3;
                    arr[4] = arr_4;
                    arr[5] = arr_5;
                    arr[6] = arr_6;
                    arr[7] = arr_7;
                end
            end
            PRECOMPUTE: begin
                if (i < n) begin
                    if (j < n) begin
                        if (j == i) begin
                            current_gcd = arr[i];
                        end else begin
                            current_gcd = gcd(current_gcd, arr[j]);
                        end
                        seg_score[i][j] = largest_prime_factor(current_gcd);
                        j = j + 4'd1;
                    end else begin
                        j = 4'd0;
                        i = i + 4'd1;
                    end
                end else begin
                    next_state = ENUMERATE;
                    i = 4'd0;
                    j = 4'd0;
                    p = 4'd0;
                    split = 4'd0;
                    temp_min = 8'd0;
                    temp_max = 8'd0;
                end
            end
            ENUMERATE: begin
                if (k == 3'd1) begin
                    temp_max = seg_score[0][n-1];
                    next_state = DONE;
                end else if (k == 3'd2) begin
                    if (split < n) begin
                        if (split > 0) begin
                            temp_min = seg_score[0][split-1];
                            if (seg_score[split][n-1] < temp_min) begin
                                temp_min = seg_score[split][n-1];
                            end
                            if (temp_min > temp_max) begin
                                temp_max = temp_min;
                            end
                        end
                        split = split + 4'd1;
                    end else begin
                        next_state = DONE;
                    end
                end else if (k == 3'd3) begin
                    if (i < n) begin
                        if (j < n) begin
                            if (j > i) begin
                                temp_min = seg_score[0][i-1];
                                if (seg_score[i][j-1] < temp_min) begin
                                    temp_min = seg_score[i][j-1];
                                end
                                if (seg_score[j][n-1] < temp_min) begin
                                    temp_min = seg_score[j][n-1];
                                end
                                if (temp_min > temp_max) begin
                                    temp_max = temp_min;
                                end
                            end
                            j = j + 4'd1;
                        end else begin
                            j = 4'd0;
                            i = i + 4'd1;
                        end
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            DONE: begin
                result = temp_max;
                done = 1'b1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule