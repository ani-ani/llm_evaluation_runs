module removezero_ip(
    input [7:0] char_in_0,
    input [7:0] char_in_1,
    input [7:0] char_in_2,
    input [7:0] char_in_3,
    input [7:0] char_in_4,
    input [7:0] char_in_5,
    input [7:0] char_in_6,
    input [7:0] char_in_7,
    input [7:0] char_in_8,
    input [7:0] char_in_9,
    input [7:0] char_in_10,
    input [7:0] char_in_11,
    input [7:0] char_in_12,
    input [7:0] char_in_13,
    input [7:0] char_in_14,
    input [7:0] char_in_15,
    output reg [7:0] char_out_0,
    output reg [7:0] char_out_1,
    output reg [7:0] char_out_2,
    output reg [7:0] char_out_3,
    output reg [7:0] char_out_4,
    output reg [7:0] char_out_5,
    output reg [7:0] char_out_6,
    output reg [7:0] char_out_7,
    output reg [7:0] char_out_8,
    output reg [7:0] char_out_9,
    output reg [7:0] char_out_10,
    output reg [7:0] char_out_11,
    output reg [7:0] char_out_12,
    output reg [7:0] char_out_13,
    output reg [7:0] char_out_14,
    output reg [7:0] char_out_15
);

    reg [7:0] char_in [0:15];
    reg [7:0] char_out [0:15];
    integer i;

    always @(*) begin
        char_in[0] = char_in_0;
        char_in[1] = char_in_1;
        char_in[2] = char_in_2;
        char_in[3] = char_in_3;
        char_in[4] = char_in_4;
        char_in[5] = char_in_5;
        char_in[6] = char_in_6;
        char_in[7] = char_in_7;
        char_in[8] = char_in_8;
        char_in[9] = char_in_9;
        char_in[10] = char_in_10;
        char_in[11] = char_in_11;
        char_in[12] = char_in_12;
        char_in[13] = char_in_13;
        char_in[14] = char_in_14;
        char_in[15] = char_in_15;

        for (i = 0; i < 16; i = i + 1) begin
            if (char_in[i] == 8'd46) begin
                char_out[i] = 8'd46;
            end else if (char_in[i] == 8'd48) begin
                if (i < 15 && char_in[i+1] != 8'd46 && char_in[i+1] != 8'd0 && char_in[i+1] != 8'd32) begin
                    char_out[i] = 8'd32;
                end else begin
                    char_out[i] = 8'd48;
                end
            end else begin
                char_out[i] = char_in[i];
            end
        end

        char_out_0 = char_out[0];
        char_out_1 = char_out[1];
        char_out_2 = char_out[2];
        char_out_3 = char_out[3];
        char_out_4 = char_out[4];
        char_out_5 = char_out[5];
        char_out_6 = char_out[6];
        char_out_7 = char_out[7];
        char_out_8 = char_out[8];
        char_out_9 = char_out[9];
        char_out_10 = char_out[10];
        char_out_11 = char_out[11];
        char_out_12 = char_out[12];
        char_out_13 = char_out[13];
        char_out_14 = char_out[14];
        char_out_15 = char_out[15];
    end

endmodule