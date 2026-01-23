module complex_angle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] a,
    input wire signed [15:0] b,
    output reg [15:0] angle,
    output reg done
);

    reg [2:0] state;
    reg signed [15:0] abs_a;
    reg signed [15:0] abs_b;
    reg [15:0] temp_angle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 3'd0;
            angle <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                3'd0: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= 3'd1;
                    end
                end

                3'd1: begin
                    abs_a <= (a[15] ? -a : a);
                    abs_b <= (b[15] ? -b : b);
                    state <= 3'd2;
                end

                3'd2: begin
                    temp_angle <= 16'd0;
                    state <= 3'd3;
                end

                3'd3: begin
                    if (a == 16'd0 && b == 16'd0) begin
                        angle <= 16'd0;
                        state <= 3'd4;
                    end else if (a == 16'd0) begin
                        if (b[15]) angle <= 16'hFE6E;
                        else angle <= 16'h0192;
                        state <= 3'd4;
                    end else if (b == 16'd0) begin
                        if (a[15]) angle <= 16'h0324;
                        else angle <= 16'd0;
                        state <= 3'd4;
                    end else begin
                        if (abs_b > abs_a) begin
                            temp_angle <= 16'h00C8;
                        end else begin
                            temp_angle <= 16'h00C8;
                        end
                        state <= 3'd5;
                    end
                end

                3'd5: begin
                    if (!a[15] && !b[15]) begin
                        angle <= temp_angle;
                    end else if (a[15] && !b[15]) begin
                        angle <= 16'h0324 - temp_angle;
                    end else if (a[15] && b[15]) begin
                        angle <= 16'hFCDc + temp_angle;
                    end else begin
                        angle <= 16'd0 - temp_angle;
                    end
                    state <= 3'd4;
                end

                3'd4: begin
                    done <= 1'b1;
                    state <= 3'd0;
                end

                default: state <= 3'd0;
            endcase
        end
    end

endmodule