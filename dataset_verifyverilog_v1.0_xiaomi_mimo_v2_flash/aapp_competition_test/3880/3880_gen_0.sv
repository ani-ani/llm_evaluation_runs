module max_sum (
    input [2:0] n,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    output reg [9:0] result
);

    wire [7:0] arr [0:6];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;

    wire [2:0] num_elements;
    assign num_elements = (n == 3'd3) ? 3'd3 : 
                         (n == 3'd4) ? 3'd5 : 3'd7;

    integer i;
    reg [9:0] sum_abs;
    reg [2:0] neg_count;
    reg zero_exists;
    reg [7:0] min_abs;
    reg [7:0] abs_val_reg;

    always @(*) begin
        sum_abs = 10'd0;
        neg_count = 3'd0;
        zero_exists = 1'b0;
        min_abs = 8'hFF;

        for (i = 0; i < 7; i = i + 1) begin
            if (i < num_elements) begin
                if (arr[i][7]) begin
                    neg_count = neg_count + 3'd1;
                    abs_val_reg = (~arr[i]) + 8'd1;
                end else begin
                    abs_val_reg = arr[i];
                end

                if (arr[i] == 8'd0) begin
                    zero_exists = 1'b1;
                end

                sum_abs = sum_abs + {2'b00, abs_val_reg};

                if (abs_val_reg < min_abs) begin
                    min_abs = abs_val_reg;
                end
            end
        end
    end

    wire is_odd;
    assign is_odd = n[0];

    always @(*) begin
        if (is_odd) begin
            result = sum_abs;
        end else begin
            if (neg_count[0] == 1'b0 || zero_exists) begin
                result = sum_abs;
            end else begin
                result = sum_abs - ({2'b00, min_abs} << 1);
            end
        end
    end

endmodule