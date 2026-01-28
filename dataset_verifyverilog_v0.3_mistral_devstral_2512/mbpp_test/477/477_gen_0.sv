module string_to_lower(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_0, str_1, str_2, str_3,
    input wire [7:0] str_4, str_5, str_6, str_7,
    input wire [7:0] str_8, str_9, str_10, str_11,
    input wire [7:0] str_12, str_13, str_14, str_15,
    input wire [3:0] str_len,
    output reg [7:0] result_0, result_1, result_2, result_3,
    output reg [7:0] result_4, result_5, result_6, result_7,
    output reg [7:0] result_8, result_9, result_10, result_11,
    output reg [7:0] result_12, result_13, result_14, result_15,
    output reg done
);

    reg [3:0] idx;
    reg processing;

    wire [7:0] current_char;
    wire [7:0] converted_char;

    assign current_char = 
        (idx == 4'd0) ? str_0 :
        (idx == 4'd1) ? str_1 :
        (idx == 4'd2) ? str_2 :
        (idx == 4'd3) ? str_3 :
        (idx == 4'd4) ? str_4 :
        (idx == 4'd5) ? str_5 :
        (idx == 4'd6) ? str_6 :
        (idx == 4'd7) ? str_7 :
        (idx == 4'd8) ? str_8 :
        (idx == 4'd9) ? str_9 :
        (idx == 4'd10) ? str_10 :
        (idx == 4'd11) ? str_11 :
        (idx == 4'd12) ? str_12 :
        (idx == 4'd13) ? str_13 :
        (idx == 4'd14) ? str_14 :
        str_15;

    assign converted_char = (current_char >= 8'h41 && current_char <= 8'h5A) ?
                            (current_char | 8'h20) : current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 4'd0;
            processing <= 1'b0;
            done <= 1'b0;
            result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
            result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
            result_8 <= 8'd0; result_9 <= 8'd0; result_10 <= 8'd0; result_11 <= 8'd0;
            result_12 <= 8'd0; result_13 <= 8'd0; result_14 <= 8'd0; result_15 <= 8'd0;
        end else begin
            if (start && !processing) begin
                idx <= 4'd0;
                processing <= 1'b1;
                done <= 1'b0;
            end else if (processing) begin
                if (idx < str_len) begin
                    case (idx)
                        4'd0: result_0 <= converted_char;
                        4'd1: result_1 <= converted_char;
                        4'd2: result_2 <= converted_char;
                        4'd3: result_3 <= converted_char;
                        4'd4: result_4 <= converted_char;
                        4'd5: result_5 <= converted_char;
                        4'd6: result_6 <= converted_char;
                        4'd7: result_7 <= converted_char;
                        4'd8: result_8 <= converted_char;
                        4'd9: result_9 <= converted_char;
                        4'd10: result_10 <= converted_char;
                        4'd11: result_11 <= converted_char;
                        4'd12: result_12 <= converted_char;
                        4'd13: result_13 <= converted_char;
                        4'd14: result_14 <= converted_char;
                        4'd15: result_15 <= converted_char;
                    endcase
                    idx <= idx + 1'b1;
                end else begin
                    processing <= 1'b0;
                    done <= 1'b1;
                    idx <= 4'd0;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule