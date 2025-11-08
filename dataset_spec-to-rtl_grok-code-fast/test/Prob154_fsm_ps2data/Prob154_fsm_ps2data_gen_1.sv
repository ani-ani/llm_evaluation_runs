module TopModule(
    input clk,
    input reset,
    input [7:0] in,
    output [23:0] out_bytes,
    output done
);

    // FSM states
    typedef enum logic [1:0] {
        IDLE,
        BYTE0,
        BYTE1,
        BYTE2
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    logic [7:0] byte0, byte1, byte2;

    // FSM implementation
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            byte0 <= 0;
            byte1 <= 0;
            byte2 <= 0;
            out_bytes <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (in[3]) begin
                        byte0 <= in;
                        next_state = BYTE0;
                    end else begin
                        next_state = IDLE;
                    end
                end
                BYTE0: begin
                    byte1 <= in;
                    next_state = BYTE1;
                end
                BYTE1: begin
                    byte2 <= in;
                    next_state = BYTE2;
                end
                BYTE2: begin
                    out_bytes <= {byte0, byte1, byte2};
                    done <= 1;
                    next_state = IDLE;
                end
            endcase
        end
    end

    // Output assignment
    assign done = (current_state == BYTE2);

endmodule