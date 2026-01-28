module ExpectedGifts(
    input clk,
    input rst_n,
    input [3:0] n,
    input start,
    output reg [15:0] result,
    output reg done
);

    reg [15:0] result_next;
    reg done_next;
    reg [3:0] n_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
        end else begin
            if (start) begin
                n_reg <= n;
            end
            result <= result_next;
            done <= done_next;
        end
    end

    always @(*) begin
        case (n_reg)
            4'd2: result_next = 16'd768;   // 3.0000
            4'd3: result_next = 16'd1365;  // 5.3333
            4'd4: result_next = 16'd2048;  // 8.0000
            4'd5: result_next = 16'd2731;  // 10.668
            4'd6: result_next = 16'd3413;  // 13.332
            4'd7: result_next = 16'd4096;  // 16.000
            4'd8: result_next = 16'd4779;  // 18.668
            4'd9: result_next = 16'd5461;  // 21.332
            4'd10: result_next = 16'd6144; // 24.000
            4'd11: result_next = 16'd6827; // 26.668
            4'd12: result_next = 16'd7509; // 29.332
            4'd13: result_next = 16'd8192; // 32.000
            4'd14: result_next = 16'd8875; // 34.668
            4'd15: result_next = 16'd9557; // 37.332
            4'd16: result_next = 16'd10240; // 40.000
            default: result_next = 16'd0;
        endcase
        done_next = (start) ? 1'b0 : (n_reg >= 4'd2 && n_reg <= 4'd16) ? 1'b1 : 1'b0;
    end

endmodule