typedef enum {RESET, SET_F, DETECT_X_0, DETECT_X_1, DETECT_X_2, SET_G, MONITOR_Y1, MONITOR_Y2, DONE_1, DONE_0} state_t;

module TopModule(
    input clk,
    input resetn,
    input x,
    input y,
    output reg f,
    output reg g
);
    state_t state, next_state;
    
    always @(posedge clk) begin
        if (~resetn)
            state <= RESET;
        else
            state <= next_state;
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            RESET: begin
                if (resetn) begin
                    next_state = SET_F;
                end
            end
            SET_F: begin
                next_state = DETECT_X_0;
            end
            DETECT_X_0: begin
                if (x == 1'b1)
                    next_state = DETECT_X_1;
                else
                    next_state = DETECT_X_0;
            end
            DETECT_X_1: begin
                if (x == 1'b0)
                    next_state = DETECT_X_2;
                else if (x == 1'b1)
                    next_state = DETECT_X_1;
                else
                    next_state = DETECT_X_0;
            end
            DETECT_X_2: begin
                if (x == 1'b1)
                    next_state = SET_G;
                else if (x == 1'b0)
                    next_state = DETECT_X_0;
                else
                    next_state = DETECT_X_1;
            end
            SET_G: begin
                next_state = MONITOR_Y1;
            end
            MONITOR_Y1: begin
                if (y)
                    next_state = DONE_1;
                else
                    next_state = MONITOR_Y2;
            end
            MONITOR_Y2: begin
                if (y)
                    next_state = DONE_1;
                else
                    next_state = DONE_0;
            end
            DONE_1: next_state = DONE_1;
            DONE_0: next_state = DONE_0;
            default: next_state = RESET;
        endcase
        
        f = 1'b0;
        g = 1'b0;
        case (state)
            SET_F: f = 1'b1;
            MONITOR_Y1, MONITOR_Y2, DONE_1: g = 1'b1;
        endcase
    end
endmodule