module get_positive(
    input [7:0][7:0] data_in,  // 8 elements, each 8-bit signed (range -128 to 127)
    input [2:0] count,         // Number of valid elements in input (0-8)
    output reg [7:0] data_out_0,
    output reg [7:0] data_out_1,
    output reg [7:0] data_out_2,
    output reg [7:0] data_out_3,
    output reg [7:0] data_out_4,
    output reg [7:0] data_out_5,
    output reg [7:0] data_out_6,
    output reg [7:0] data_out_7,
    output reg [2:0] out_count  // Number of positive values found
);

    integer i;
    reg [2:0] temp_count;

    always @(*) begin
        temp_count = 0;
        data_out_0 = 0; data_out_1 = 0; data_out_2 = 0; data_out_3 = 0;
        data_out_4 = 0; data_out_5 = 0; data_out_6 = 0; data_out_7 = 0;

        for (i = 0; i < 8; i = i + 1) begin
            if (i < count) begin
                if (data_in[i][7] == 0 && data_in[i] != 0) begin
                    case (temp_count)
                        0: data_out_0 = data_in[i];
                        1: data_out_1 = data_in[i];
                        2: data_out_2 = data_in[i];
                        3: data_out_3 = data_in[i];
                        4: data_out_4 = data_in[i];
                        5: data_out_5 = data_in[i];
                        6: data_out_6 = data_in[i];
                        7: data_out_7 = data_in[i];
                    endcase
                    temp_count = temp_count + 1;
                end
            end
        end
        out_count = temp_count;
    end

endmodule