module TopModule(
    input clk,
    input reset,
    output reg shift_ena
);
    reg [3:0] cnt;
    always @(posedge clk) begin
        if (reset) begin
            cnt <= 4'd1;
            shift_ena <= 1'b1;
        end else begin
            if (cnt < 4'd4) begin
                cnt <= cnt + 1;
                shift_ena <= 1'b1;
            end else begin
                shift_ena <= 1'b0;
            end
        end
    end
endmodule