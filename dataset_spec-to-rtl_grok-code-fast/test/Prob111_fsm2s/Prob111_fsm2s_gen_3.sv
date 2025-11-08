module TopModule(
    input clk,
    input reset,
    input j,
    input k,
    output out
);
    logic state;
    always_ff @(posedge clk) begin
        if (reset)
            state <= 0;
        else begin
            case (state)
                0: state <= j;
                1: state <= !k;
            endcase
        end
    end
    assign out = state;
endmodule