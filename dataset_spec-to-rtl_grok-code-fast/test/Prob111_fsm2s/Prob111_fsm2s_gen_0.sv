module TopModule (
    input clk,
    input reset,
    input j,
    input k,
    output out
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
        next_state = current_state;
        case (current_state)
            OFF: begin
                if (j) next_state = ON;
            end
            ON: begin
                if (k) next_state = OFF;
            end
        endcase
    end

    assign out = (current_state == ON) ? 1'b1 : 1'b0;

import
endmodule