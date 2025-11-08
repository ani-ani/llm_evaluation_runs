module TopModule (
    input clk,
    input reset,
    input in,
    output out
);

    localparam A = 0;
    localparam B = 1;
    logic state;

    always @(posedge clk) begin
        if (reset) begin
            state <= B;
        end else begin
            state <= in ? state : (state == B ? A : B);
        end
    end

    assign out = (state == B);

endmodule