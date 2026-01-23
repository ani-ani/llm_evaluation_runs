module ExtractFirstElements (
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [2:0] num_sublists,
    output reg [7:0] result_0, result_1, result_2, result_3,
                     result_4, result_5, result_6, result_7,
    output reg [2:0] result_count
);

    always @(*) begin
        result_0 = 8'd0;
        result_1 = 8'd0;
        result_2 = 8'd0;
        result_3 = 8'd0;
        result_4 = 8'd0;
        result_5 = 8'd0;
        result_6 = 8'd0;
        result_7 = 8'd0;
        result_count = 3'd0;
        
        case (num_sublists)
            3'd1: begin
                result_0 = arr_0;
                result_count = 3'd1;
            end
            3'd2: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_count = 3'd2;
            end
            3'd3: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_count = 3'd3;
            end
            3'd4: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_3 = arr_3;
                result_count = 3'd4;
            end
            3'd5: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_3 = arr_3;
                result_4 = arr_4;
                result_count = 3'd5;
            end
            3'd6: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_3 = arr_3;
                result_4 = arr_4;
                result_5 = arr_5;
                result_count = 3'd6;
            end
            3'd7: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_3 = arr_3;
                result_4 = arr_4;
                result_5 = arr_5;
                result_6 = arr_6;
                result_count = 3'd7;
            end
            3'd8: begin
                result_0 = arr_0;
                result_1 = arr_1;
                result_2 = arr_2;
                result_3 = arr_3;
                result_4 = arr_4;
                result_5 = arr_5;
                result_6 = arr_6;
                result_7 = arr_7;
                result_count = 3'd8;
            end
            default: begin
                result_count = 3'd0;
            end
        endcase
    end

endmodule