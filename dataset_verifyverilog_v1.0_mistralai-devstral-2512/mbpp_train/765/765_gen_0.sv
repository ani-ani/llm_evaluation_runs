module PoliteNumber(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] n,
    output reg [15:0] result,
    output reg done
);

    reg [15:0] result_next;
    reg done_next;
    reg start_delayed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            start_delayed <= 1'b0;
        end else begin
            start_delayed <= start;
            
            if (start_delayed) begin
                if (n == 12'd0) begin
                    result_next = 16'd1;
                end else begin
                    result_next = {1'b0, n[11:1], 1'b1};
                end
                done_next = 1'b1;
            end else begin
                result_next = 16'd0;
                done_next = 1'b0;
            end
            
            result <= result_next;
            done <= done_next;
        end
    end
endmodule