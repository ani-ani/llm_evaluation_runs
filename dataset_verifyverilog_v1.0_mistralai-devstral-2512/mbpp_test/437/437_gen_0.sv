module remove_odd_chars(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [7:0] char_8,
    input [7:0] char_9,
    input [7:0] char_10,
    input [7:0] char_11,
    input [7:0] char_12,
    input [7:0] char_13,
    input [7:0] char_14,
    input [7:0] char_15,
    input [3:0] len,
    output reg [7:0] out_char_0,
    output reg [7:0] out_char_1,
    output reg [7:0] out_char_2,
    output reg [7:0] out_char_3,
    output reg [7:0] out_char_4,
    output reg [7:0] out_char_5,
    output reg [7:0] out_char_6,
    output reg [7:0] out_char_7,
    output reg [7:0] out_char_8,
    output reg [7:0] out_char_9,
    output reg [7:0] out_char_10,
    output reg [7:0] out_char_11,
    output reg [7:0] out_char_12,
    output reg [7:0] out_char_13,
    output reg [7:0] out_char_14,
    output reg [7:0] out_char_15,
    output reg [3:0] out_len
);

    reg [3:0] i;
    reg [3:0] out_idx;
    reg [7:0] temp_out [0:15];

    always @(*) begin
        out_len = 4'd0;
        out_idx = 4'd0;

        for (i = 0; i < 16; i = i + 1) begin
            temp_out[i] = 8'd0;
        end

        for (i = 0; i < len; i = i + 1) begin
            if ((i + 1) % 2 == 0) begin
                case (i)
                    0: temp_out[out_idx] = char_0;
                    1: temp_out[out_idx] = char_1;
                    2: temp_out[out_idx] = char_2;
                    3: temp_out[out_idx] = char_3;
                    4: temp_out[out_idx] = char_4;
                    5: temp_out[out_idx] = char_5;
                    6: temp_out[out_idx] = char_6;
                    7: temp_out[out_idx] = char_7;
                    8: temp_out[out_idx] = char_8;
                    9: temp_out[out_idx] = char_9;
                    10: temp_out[out_idx] = char_10;
                    11: temp_out[out_idx] = char_11;
                    12: temp_out[out_idx] = char_12;
                    13: temp_out[out_idx] = char_13;
                    14: temp_out[out_idx] = char_14;
                    15: temp_out[out_idx] = char_15;
                    default: temp_out[out_idx] = 8'd0;
                endcase
                out_idx = out_idx + 1;
            end
        end

        out_len = out_idx;

        out_char_0 = temp_out[0];
        out_char_1 = temp_out[1];
        out_char_2 = temp_out[2];
        out_char_3 = temp_out[3];
        out_char_4 = temp_out[4];
        out_char_5 = temp_out[5];
        out_char_6 = temp_out[6];
        out_char_7 = temp_out[7];
        out_char_8 = temp_out[8];
        out_char_9 = temp_out[9];
        out_char_10 = temp_out[10];
        out_char_11 = temp_out[11];
        out_char_12 = temp_out[12];
        out_char_13 = temp_out[13];
        out_char_14 = temp_out[14];
        out_char_15 = temp_out[15];
    end

endmodule