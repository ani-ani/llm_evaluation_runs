module big_diff(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [15:0] result
);
    reg [7:0] arr [0:7];
    reg [7:0] max_val;
    reg [7:0] min_val;
    integer i;

    always @(*) begin
        arr[0] = arr_0;
        arr[1] = arr_1;
        arr[2] = arr_2;
        arr[3] = arr_3;
        arr[4] = arr_4;
        arr[5] = arr_5;
        arr[6] = arr_6;
        arr[7] = arr_7;
        
        if (len == 4'd0) begin
            max_val = 8'd0;
            min_val = 8'd0;
        end else begin
            max_val = arr[0];
            min_val = arr[0];
            
            for (i = 1; i < 8; i = i + 1) begin
                if (i < len) begin
                    if (arr[i] > max_val)
                        max_val = arr[i];
                    if (arr[i] < min_val)
                        min_val = arr[i];
                end
            end
        end
        
        result = {8'd0, max_val} - {8'd0, min_val};
    end
endmodule