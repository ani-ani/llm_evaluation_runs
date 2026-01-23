module by_length (
    input [7:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7,
    output [7:0] out0_char0, out0_char1, out0_char2, out0_char3, out0_char4,
    output [7:0] out1_char0, out1_char1, out1_char2, out1_char3, out1_char4,
    output [7:0] out2_char0, out2_char1, out2_char2, out2_char3, out2_char4,
    output [7:0] out3_char0, out3_char1, out3_char2, out3_char3, out3_char4,
    output [7:0] out4_char0, out4_char1, out4_char2, out4_char3, out4_char4,
    output [7:0] out5_char0, out5_char1, out5_char2, out5_char3, out5_char4,
    output [7:0] out6_char0, out6_char1, out6_char2, out6_char3, out6_char4,
    output [7:0] out7_char0, out7_char1, out7_char2, out7_char3, out7_char4,
    output [3:0] count
);

    wire [7:0] arr [0:7];
    assign arr[0] = arr0;
    assign arr[1] = arr1;
    assign arr[2] = arr2;
    assign arr[3] = arr3;
    assign arr[4] = arr4;
    assign arr[5] = arr5;
    assign arr[6] = arr6;
    assign arr[7] = arr7;

    wire [7:0] valid [0:7];
    wire [7:0] sorted [0:7];
    wire [7:0] reversed [0:7];
    wire [3:0] valid_count;

    assign valid_count = 
        ((arr[0] >= 8'sd1 && arr[0] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[1] >= 8'sd1 && arr[1] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[2] >= 8'sd1 && arr[2] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[3] >= 8'sd1 && arr[3] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[4] >= 8'sd1 && arr[4] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[5] >= 8'sd1 && arr[5] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[6] >= 8'sd1 && arr[6] <= 8'sd9) ? 4'd1 : 4'd0) +
        ((arr[7] >= 8'sd1 && arr[7] <= 8'sd9) ? 4'd1 : 4'd0);

    assign count = valid_count;

    reg [7:0] temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;

    integer i, j, k;
    reg [7:0] min_val;
    reg [7:0] tmp_swap;
    reg [7:0] in_vals [0:7];
    reg [7:0] working [0:7];
    reg [7:0] sorted_reg [0:7];
    reg [7:0] reversed_reg [0:7];
    
    reg [7:0] result_strings [0:7][0:4];

    always @(*) begin
        // Filter
        in_vals[0] = arr0;
        in_vals[1] = arr1;
        in_vals[2] = arr2;
        in_vals[3] = arr3;
        in_vals[4] = arr4;
        in_vals[5] = arr5;
        in_vals[6] = arr6;
        in_vals[7] = arr7;

        working[0] = 8'd0;
        working[1] = 8'd0;
        working[2] = 8'd0;
        working[3] = 8'd0;
        working[4] = 8'd0;
        working[5] = 8'd0;
        working[6] = 8'd0;
        working[7] = 8'd0;

        k = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (in_vals[i] >= 8'sd1 && in_vals[i] <= 8'sd9) begin
                working[k] = in_vals[i];
                k = k + 1;
            end
        end

        // Sort (Selection Sort)
        sorted_reg[0] = working[0];
        sorted_reg[1] = working[1];
        sorted_reg[2] = working[2];
        sorted_reg[3] = working[3];
        sorted_reg[4] = working[4];
        sorted_reg[5] = working[5];
        sorted_reg[6] = working[6];
        sorted_reg[7] = working[7];

        for (i = 0; i < 7; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                if (sorted_reg[j] < sorted_reg[i]) begin
                    tmp_swap = sorted_reg[i];
                    sorted_reg[i] = sorted_reg[j];
                    sorted_reg[j] = tmp_swap;
                end
            end
        end

        // Reverse
        reversed_reg[0] = sorted_reg[7];
        reversed_reg[1] = sorted_reg[6];
        reversed_reg[2] = sorted_reg[5];
        reversed_reg[3] = sorted_reg[4];
        reversed_reg[4] = sorted_reg[3];
        reversed_reg[5] = sorted_reg[2];
        reversed_reg[6] = sorted_reg[1];
        reversed_reg[7] = sorted_reg[0];

        // Map to strings
        for (i = 0; i < 8; i = i + 1) begin
            case (reversed_reg[i])
                8'sd1: begin
                    result_strings[i][0] = 8'h4F; result_strings[i][1] = 8'h6E; result_strings[i][2] = 8'h65; result_strings[i][3] = 8'h20; result_strings[i][4] = 8'h20;
                end
                8'sd2: begin
                    result_strings[i][0] = 8'h54; result_strings[i][1] = 8'h77; result_strings[i][2] = 8'h6F; result_strings[i][3] = 8'h20; result_strings[i][4] = 8'h20;
                end
                8'sd3: begin
                    result_strings[i][0] = 8'h54; result_strings[i][1] = 8'h68; result_strings[i][2] = 8'h72; result_strings[i][3] = 8'h65; result_strings[i][4] = 8'h65;
                end
                8'sd4: begin
                    result_strings[i][0] = 8'h46; result_strings[i][1] = 8'h6F; result_strings[i][2] = 8'h75; result_strings[i][3] = 8'h72; result_strings[i][4] = 8'h20;
                end
                8'sd5: begin
                    result_strings[i][0] = 8'h46; result_strings[i][1] = 8'h69; result_strings[i][2] = 8'h76; result_strings[i][3] = 8'h65; result_strings[i][4] = 8'h20;
                end
                8'sd6: begin
                    result_strings[i][0] = 8'h53; result_strings[i][1] = 8'h69; result_strings[i][2] = 8'h78; result_strings[i][3] = 8'h20; result_strings[i][4] = 8'h20;
                end
                8'sd7: begin
                    result_strings[i][0] = 8'h53; result_strings[i][1] = 8'h65; result_strings[i][2] = 8'h76; result_strings[i][3] = 8'h65; result_strings[i][4] = 8'h6D;
                end
                8'sd8: begin
                    result_strings[i][0] = 8'h45; result_strings[i][1] = 8'h69; result_strings[i][2] = 8'h67; result_strings[i][3] = 8'h68; result_strings[i][4] = 8'h74;
                end
                8'sd9: begin
                    result_strings[i][0] = 8'h4E; result_strings[i][1] = 8'h69; result_strings[i][2] = 8'h6E; result_strings[i][3] = 8'h65; result_strings[i][4] = 8'h20;
                end
                default: begin
                    result_strings[i][0] = 8'h20; result_strings[i][1] = 8'h20; result_strings[i][2] = 8'h20; result_strings[i][3] = 8'h20; result_strings[i][4] = 8'h20;
                end
            endcase
        end
    end

    assign out0_char0 = result_strings[0][0]; assign out0_char1 = result_strings[0][1]; assign out0_char2 = result_strings[0][2]; assign out0_char3 = result_strings[0][3]; assign out0_char4 = result_strings[0][4];
    assign out1_char0 = result_strings[1][0]; assign out1_char1 = result_strings[1][1]; assign out1_char2 = result_strings[1][2]; assign out1_char3 = result_strings[1][3]; assign out1_char4 = result_strings[1][4];
    assign out2_char0 = result_strings[2][0]; assign out2_char1 = result_strings[2][1]; assign out2_char2 = result_strings[2][2]; assign out2_char3 = result_strings[2][3]; assign out2_char4 = result_strings[2][4];
    assign out3_char0 = result_strings[3][0]; assign out3_char1 = result_strings[3][1]; assign out3_char2 = result_strings[3][2]; assign out3_char3 = result_strings[3][3]; assign out3_char4 = result_strings[3][4];
    assign out4_char0 = result_strings[4][0]; assign out4_char1 = result_strings[4][1]; assign out4_char2 = result_strings[4][2]; assign out4_char3 = result_strings[4][3]; assign out4_char4 = result_strings[4][4];
    assign out5_char0 = result_strings[5][0]; assign out5_char1 = result_strings[5][1]; assign out5_char2 = result_strings[5][2]; assign out5_char3 = result_strings[5][3]; assign out5_char4 = result_strings[5][4];
    assign out6_char0 = result_strings[6][0]; assign out6_char1 = result_strings[6][1]; assign out6_char2 = result_strings[6][2]; assign out6_char3 = result_strings[6][3]; assign out6_char4 = result_strings[6][4];
    assign out7_char0 = result_strings[7][0]; assign out7_char1 = result_strings[7][1]; assign out7_char2 = result_strings[7][2]; assign out7_char3 = result_strings[7][3]; assign out7_char4 = result_strings[7][4];

endmodule