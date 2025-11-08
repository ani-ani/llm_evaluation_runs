module TopModule(
    input clk,
    input reset,
    input j,
    input k,
    output reg out
);
    typedef enum {OFF, ON} state_t;
    state_t current_state, next_state;

    always @(posedge clk) begin
        if (reset) begin
            current_state <= OFF;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            OFF: next_state = j ? ON : OFF;
            ON: next_state = k ? OFF : ON;
        endcase
    end

    always @(*) begin
        out = (current_state == ON);
    end
endmodule