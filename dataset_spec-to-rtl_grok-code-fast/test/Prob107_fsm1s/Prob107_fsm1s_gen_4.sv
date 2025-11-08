module TopModule(
    input clk,
    input reset,
    input in,
    output out
);

    reg state;

    always @(posedge clk) begin
        if (reset) begin
            state <= 1'b1; // B
        end else begin
            case (state)
                1'b1: // B
                    if (in == 1'b0) state <= 1'b0; // to A
                    else state <= 1'b1; // stay B
                1'b0: // A
                    if (in == 1'b0) state <= 1'b1; // to B
                    else state <= 1'b0; // stay A
            endcase
        end
    end

    assign out = state; // out=1 for B, out=0 for A

endmodule