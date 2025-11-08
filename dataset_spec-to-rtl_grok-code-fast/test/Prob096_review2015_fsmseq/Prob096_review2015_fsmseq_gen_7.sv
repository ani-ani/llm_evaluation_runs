module TopModule (
    input clk,
    input reset,
    input data,
    output reg start_shifting
);
    typedef enum logic [2:0] {
        S0 = 3'b000,
        S1 = 3'b001,
        S11 = 3'b011,
        S110 = 3'b110,
        DONE = 3'b111
    } state_t;

    reg [2:0] state = S0, next_state;
    reg found = 0;

    always_comb begin
        case (state)
            S0: next_state = (data == 1'b1) ? S1 : S0;
            S1: next_state = (data == 1'b1) ? S11 : S0;
            S11: next_state = (data == 1'b0) ? S110 : S11;
            S110: next_state = (data == 1'b1) ? DONE : S0;
            DONE: next_state = DONE;
            default: next_state = S0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S0;
            found <= 0;
        end else begin
            state <= next_state;
            if (state == S110 && data == 1'b1) begin
                found <= 1;
            end
        end
    end

    assign start_shifting = found;
endmodule