module TopModule(
    input clk,
    input reset,
    input in,
    output out
);

    reg current_state;
    parameter S_B = 1'b0;
    parameter S_A = 1'b1;

    always @(posedge clk) begin
        if (reset) begin
            current_state <= S_B;
        end else begin
            case (current_state)
                S_B: current_state <= (in == 1'b0) ? S_A : S_B;
                S_A: current_state <= (in == 1'b0) ? S_B : S_A;
            endcase
        end
    end

    assign out = (current_state == S_B) ? 1'b1 : 1'b0;

endmodule