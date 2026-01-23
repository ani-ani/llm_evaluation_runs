module convex_polygon_gen (
    input [3:0] N,
    output reg [7:0] x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7,
    output reg [7:0] x_8, x_9, x_10, x_11, x_12, x_13, x_14, x_15,
    output reg [7:0] y_0, y_1, y_2, y_3, y_4, y_5, y_6, y_7,
    output reg [7:0] y_8, y_9, y_10, y_11, y_12, y_13, y_14, y_15
);

    // Combinational logic to generate convex polygon points
    always @(*) begin
        // Default all outputs to 0
        x_0 = 8'd0;
        x_1 = 8'd0;
        x_2 = 8'd0;
        x_3 = 8'd0;
        x_4 = 8'd0;
        x_5 = 8'd0;
        x_6 = 8'd0;
        x_7 = 8'd0;
        x_8 = 8'd0;
        x_9 = 8'd0;
        x_10 = 8'd0;
        x_11 = 8'd0;
        x_12 = 8'd0;
        x_13 = 8'd0;
        x_14 = 8'd0;
        x_15 = 8'd0;
        
        y_0 = 8'd0;
        y_1 = 8'd0;
        y_2 = 8'd0;
        y_3 = 8'd0;
        y_4 = 8'd0;
        y_5 = 8'd0;
        y_6 = 8'd0;
        y_7 = 8'd0;
        y_8 = 8'd0;
        y_9 = 8'd0;
        y_10 = 8'd0;
        y_11 = 8'd0;
        y_12 = 8'd0;
        y_13 = 8'd0;
        y_14 = 8'd0;
        y_15 = 8'd0;
        
        // Assign points based on N
        if (N > 4'd0) begin
            x_0 = 8'd0;
            y_0 = 8'd0;
        end
        if (N > 4'd1) begin
            x_1 = 8'd1;
            y_1 = 8'd0;
        end
        if (N > 4'd2) begin
            x_2 = 8'd2;
            y_2 = 8'd1;
        end
        if (N > 4'd3) begin
            x_3 = 8'd3;
            y_3 = 8'd3;
        end
        if (N > 4'd4) begin
            x_4 = 8'd4;
            y_4 = 8'd6;
        end
        if (N > 4'd5) begin
            x_5 = 8'd5;
            y_5 = 8'd10;
        end
        if (N > 4'd6) begin
            x_6 = 8'd6;
            y_6 = 8'd15;
        end
        if (N > 4'd7) begin
            x_7 = 8'd7;
            y_7 = 8'd21;
        end
        if (N > 4'd8) begin
            x_8 = 8'd8;
            y_8 = 8'd28;
        end
        if (N > 4'd9) begin
            x_9 = 8'd9;
            y_9 = 8'd36;
        end
        if (N > 4'd10) begin
            x_10 = 8'd10;
            y_10 = 8'd45;
        end
        if (N > 4'd11) begin
            x_11 = 8'd11;
            y_11 = 8'd55;
        end
        if (N > 4'd12) begin
            x_12 = 8'd12;
            y_12 = 8'd66;
        end
        if (N > 4'd13) begin
            x_13 = 8'd13;
            y_13 = 8'd78;
        end
        if (N > 4'd14) begin
            x_14 = 8'd14;
            y_14 = 8'd91;
        end
        if (N > 4'd15) begin
            x_15 = 8'd15;
            y_15 = 8'd105;
        end
    end

endmodule