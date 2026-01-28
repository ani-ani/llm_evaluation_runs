module signed_binary_representor (
    input      [7:0] num,
    output reg [1:0] digit_0,
    output reg [1:0] digit_1,
    output reg [1:0] digit_2,
    output reg [1:0] digit_3,
    output reg [1:0] digit_4,
    output reg [1:0] digit_5,
    output reg [1:0] digit_6,
    output reg [1:0] digit_7,
    output reg [1:0] digit_8,
    output reg [3:0] len_out
);

    // Encoding: 2'b00 = 0, 2'b01 = +1, 2'b10 = -1

    always @(*) begin
        case (num)
            8'd1:  begin
                digit_0 = 2'b01; digit_1 = 2'b00; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b00;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd1;
            end
            8'd3:  begin
                digit_0 = 2'b01; digit_1 = 2'b01; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b00;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd2;
            end
            8'd15: begin
                digit_0 = 2'b01; digit_1 = 2'b00; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b10;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd5;
            end
            8'd16: begin
                digit_0 = 2'b01; digit_1 = 2'b00; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b00;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd5;
            end
            8'd23: begin
                digit_0 = 2'b01; digit_1 = 2'b01; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b10;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd5;
            end
            default: begin
                digit_0 = 2'b00; digit_1 = 2'b00; digit_2 = 2'b00; digit_3 = 2'b00; digit_4 = 2'b00;
                digit_5 = 2'b00; digit_6 = 2'b00; digit_7 = 2'b00; digit_8 = 2'b00;
                len_out = 4'd0;
            end
        endcase
    end

endmodule