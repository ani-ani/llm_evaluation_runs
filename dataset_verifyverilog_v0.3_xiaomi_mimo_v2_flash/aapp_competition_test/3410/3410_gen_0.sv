module score_calculator (
    input [3:0] N,
    input [63:0] x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7,
    input [63:0] y_0, y_1, y_2, y_3, y_4, y_5, y_6, y_7,
    output reg [63:0] result
);

    reg [2:0] i, j, k;
    reg [63:0] temp_area;
    reg [63:0] x1, y1, x2, y2, x3, y3;
    reg signed [63:0] signed_x1, signed_y1, signed_x2, signed_y2, signed_x3, signed_y3;
    reg signed [63:0] signed_area;
    reg [63:0] abs_area;
    reg [63:0] temp_result;

    always @(*) begin
        temp_result = 64'd0;
        if (N >= 3'd3) begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = i + 1; j < N; j = j + 1) begin
                    for (k = j + 1; k < N; k = k + 1) begin
                        // Select points based on indices
                        case (i)
                            3'd0: begin x1 = x_0; y1 = y_0; end
                            3'd1: begin x1 = x_1; y1 = y_1; end
                            3'd2: begin x1 = x_2; y1 = y_2; end
                            3'd3: begin x1 = x_3; y1 = y_3; end
                            3'd4: begin x1 = x_4; y1 = y_4; end
                            3'd5: begin x1 = x_5; y1 = y_5; end
                            3'd6: begin x1 = x_6; y1 = y_6; end
                            3'd7: begin x1 = x_7; y1 = y_7; end
                            default: begin x1 = 64'd0; y1 = 64'd0; end
                        endcase

                        case (j)
                            3'd0: begin x2 = x_0; y2 = y_0; end
                            3'd1: begin x2 = x_1; y2 = y_1; end
                            3'd2: begin x2 = x_2; y2 = y_2; end
                            3'd3: begin x2 = x_3; y2 = y_3; end
                            3'd4: begin x2 = x_4; y2 = y_4; end
                            3'd5: begin x2 = x_5; y2 = y_5; end
                            3'd6: begin x2 = x_6; y2 = y_6; end
                            3'd7: begin x2 = x_7; y2 = y_7; end
                            default: begin x2 = 64'd0; y2 = 64'd0; end
                        endcase

                        case (k)
                            3'd0: begin x3 = x_0; y3 = y_0; end
                            3'd1: begin x3 = x_1; y3 = y_1; end
                            3'd2: begin x3 = x_2; y3 = y_2; end
                            3'd3: begin x3 = x_3; y3 = y_3; end
                            3'd4: begin x3 = x_4; y3 = y_4; end
                            3'd5: begin x3 = x_5; y3 = y_5; end
                            3'd6: begin x3 = x_6; y3 = y_6; end
                            3'd7: begin x3 = x_7; y3 = y_7; end
                            default: begin x3 = 64'd0; y3 = 64'd0; end
                        endcase

                        // Convert to signed for arithmetic
                        signed_x1 = {1'b0, x1[62:0]};
                        signed_y1 = {1'b0, y1[62:0]};
                        signed_x2 = {1'b0, x2[62:0]};
                        signed_y2 = {1'b0, y2[62:0]};
                        signed_x3 = {1'b0, x3[62:0]};
                        signed_y3 = {1'b0, y3[62:0]};

                        // Compute signed area (twice the area)
                        signed_area = (signed_x2 - signed_x1) * (signed_y3 - signed_y1) - 
                                     (signed_x3 - signed_x1) * (signed_y2 - signed_y1);

                        // Get absolute value
                        if (signed_area < 0)
                            abs_area = -signed_area;
                        else
                            abs_area = signed_area;

                        // Add to total with modulo
                        temp_result = (temp_result + abs_area) % 1000003;
                    end
                end
            end
        end
        result = temp_result;
    end

endmodule