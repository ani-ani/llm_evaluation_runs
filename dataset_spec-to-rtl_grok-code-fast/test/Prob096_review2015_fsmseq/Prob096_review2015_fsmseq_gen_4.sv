module TopModule(
    input clk,
    input reset,
    input data,
    output reg start_shifting
);

    typedef enum reg [2:0] {
        S0 = 3'b000,
        S1 = 3'b001,
        S2 = 3'b010,
        S3 = 3'b011,
        S4 = 3'b100
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            S0: next_state = (data) ? S1 : S0;
            S1: next_state = (data) ? S2 : S0;
            S2: next_state = (data) ? S2 : S3;
            S3: next_state = (data) ? S4 : S0;
            S4: next_state = S4;
            default: next_state = S0;
        endcase
    end

    always_comb begin
        start_shifting = (state == S4) ? 1'b1 : 1'b0;
    end

endmodule