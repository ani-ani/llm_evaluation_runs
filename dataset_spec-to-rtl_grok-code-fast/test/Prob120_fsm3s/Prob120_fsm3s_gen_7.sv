module TopModule (
    input clk,
    input reset,
    input in,
    output logic out
);
    typedef enum logic [1:0] {A, B, C, D} state_t;
    state_t current_state, next_state;
    
    always_ff @(posedge clk) begin
        if (reset)
            current_state <= A;
        else
            current_state <= next_state;
    end
    
    always_comb begin
        case (current_state)
            A: next_state = (in) ? B : A;
            B: next_state = (in) ? B : C;
            C: next_state = (in) ? D : A;
            D: next_state = (in) ? B : C;
            default: next_state = A;
        endcase
    end
    
    always_comb begin
        case (current_state)
            A: out = 1'b0;
            B: out = 1'b0;
            C: out = 1'b0;
            D: out = 1'b1;
            default: out = 1'b0;
        endcase
    end
endmodule