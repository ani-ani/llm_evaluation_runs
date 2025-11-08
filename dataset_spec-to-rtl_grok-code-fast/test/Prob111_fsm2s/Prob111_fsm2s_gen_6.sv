module TopModule(
    input clk,
    input reset,
    input j,
    input k,
    output out
);
    localparam OFF = 1'b0;
    localparam ON  = 1'b1;
    reg state;
    assign out = state;
    always @(posedge clk) begin
        if (reset) state <= OFF;
        else begin
            case (state)
                OFF: state <= j ? ON : OFF;
                ON: state <= k ? OFF : ON;
            endcase
        end
    end
endmodule