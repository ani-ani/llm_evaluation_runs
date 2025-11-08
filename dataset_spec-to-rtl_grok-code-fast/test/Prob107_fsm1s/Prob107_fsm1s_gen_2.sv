module TopModule(
    input clk,
    input reset,
    input in,
    output logic out
);
    typedef enum {A, B} state_t;
    state_t current_state, next_state;

    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= B;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        case (current_state)
            B: next_state = (in == 1'b0) ? A : B;
            A: next_state = (in == 1'b0) ? B : A;
            default: next_state = B;
        endcase
    end

    always_comb begin
        case (current_state)
            B: out = 1'b1;
            A: out = 1'b0;
            default: out = 1'b1;
        endcase
    end
endmodule