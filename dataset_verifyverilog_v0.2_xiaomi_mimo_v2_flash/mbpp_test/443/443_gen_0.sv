module largest_neg(
    input [7:0] list1_0,
    input [7:0] list1_1,
    input [7:0] list1_2,
    input [7:0] list1_3,
    input [7:0] list1_4,
    input [7:0] list1_5,
    input [7:0] list1_6,
    input [7:0] list1_7,
    input [2:0] valid_count,
    output reg [7:0] result,
    output reg found
);

    integer i;
    wire signed [7:0] list [0:7];
    reg signed [7:0] current_max;
    reg has_neg;

    assign list[0] = $signed(list1_0);
    assign list[1] = $signed(list1_1);
    assign list[2] = $signed(list1_2);
    assign list[3] = $signed(list1_3);
    assign list[4] = $signed(list1_4);
    assign list[5] = $signed(list1_5);
    assign list[6] = $signed(list1_6);
    assign list[7] = $signed(list1_7);

    always @(*) begin
        has_neg = 1'b0;
        current_max = 8'sd0;
        
        if (valid_count > 3'd0) begin
            if (list[0] < 0) begin
                has_neg = 1'b1;
                current_max = list[0];
            end
            
            for (i = 1; i < 8; i = i + 1) begin
                if (i < valid_count) begin
                    if (list[i] < 0) begin
                        if (!has_neg) begin
                            has_neg = 1'b1;
                            current_max = list[i];
                        end else if (list[i] > current_max) begin
                            current_max = list[i];
                        end
                    end
                end
            end
        end
        
        if (has_neg) begin
            result = current_max;
            found = 1'b1;
        end else begin
            result = 8'sd0;
            found = 1'b0;
        end
    end

endmodule