module TopModule(
    input clk,
    input reset,
    output [9:0] q
);
    reg [9:0] count;
    assign q = count;
    always @(posedge clk) begin
        if (reset) begin
            count <= 10'd0;
        end else begin
            if (count == 10'd999) begin
                count <= 10'd0;
            end else begin
                count <= count + 10'd1;
            end
        end
    end
endmodule