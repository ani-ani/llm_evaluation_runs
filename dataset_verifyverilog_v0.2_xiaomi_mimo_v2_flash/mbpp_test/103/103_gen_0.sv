module eulerian_number(
    input [3:0] n,
    input [3:0] m,
    output reg [15:0] result
);

    always @(*) begin
        // Base cases and invalid inputs
        if (n > 8 || m >= n) begin
            result = 16'd0;
        end
        else if (n == 0) begin
            result = 16'd0;
        end
        else if (m == 0) begin
            result = 16'd1;
        end
        else begin
            // Recursive cases using full lookup table for n=1 to 8
            case (n)
                4'd1: begin
                    case (m)
                        4'd0: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd2: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd3: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd4;
                        4'd2: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd4: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd11;
                        4'd2: result = 16'd11;
                        4'd3: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd5: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd26;
                        4'd2: result = 16'd66;
                        4'd3: result = 16'd26;
                        4'd4: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd6: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd57;
                        4'd2: result = 16'd302;
                        4'd3: result = 16'd302;
                        4'd4: result = 16'd57;
                        4'd5: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd7: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd120;
                        4'd2: result = 16'd1191;
                        4'd3: result = 16'd2416;
                        4'd4: result = 16'd1191;
                        4'd5: result = 16'd120;
                        4'd6: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                4'd8: begin
                    case (m)
                        4'd0: result = 16'd1;
                        4'd1: result = 16'd247;
                        4'd2: result = 16'd4293;
                        4'd3: result = 16'd15619;
                        4'd4: result = 16'd15619;
                        4'd5: result = 16'd4293;
                        4'd6: result = 16'd247;
                        4'd7: result = 16'd1;
                        default: result = 16'd0;
                    endcase
                end
                default: result = 16'd0;
            endcase
        end
    end

endmodule
}