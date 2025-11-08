module TopModule(
    input  clk,
    input  reset,
    input  in,
    output reg out
);

    reg state, next_state;

    parameter A = 1'b0;
    parameter B = 1'b1;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= B;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            B: begin
                next_state = (in == 1'b0) ? A : B;
            end
            A: begin
                next_state = (in == 1'b0) ? B : A;
            end
            default: begin
                next_state = B;
            end
        endcase
    end

    always_comb begin
        out = (state == B) ? 1'b1 : 1'b0;
    end

endmodule