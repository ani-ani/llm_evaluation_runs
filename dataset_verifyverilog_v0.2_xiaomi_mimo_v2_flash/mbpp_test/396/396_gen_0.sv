module check_string_char (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input last_in,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE        = 3'b000;
    localparam READ_FIRST  = 3'b001;
    localparam READ_MIDDLE = 3'b010;
    localparam READ_LAST   = 3'b011;
    localparam DONE        = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [7:0] start_char;
    
    // Combinational logic for next state and outputs
    reg [2:0] next_state;
    reg [7:0] next_start_char;
    reg next_result;
    reg next_done;

    // State Transition and Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_start_char = start_char;
        next_result = result;
        next_done = 1'b0;

        // Priority 1: Reset/Start Signal
        // "On start, reset internal state"
        // This forces the machine to restart regardless of current state.
        if (start) begin
            next_state = READ_FIRST;
            next_start_char = 8'h00;
            next_result = 1'b0;
            next_done = 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Wait for start signal (handled by if(start) above)
                    // If we are here without start, stay.
                    // But usually we go to IDLE from DONE if start is low.
                    // However, to be robust, if we fall into IDLE (e.g. reset), wait for start.
                    // Actually, on reset we go to IDLE. Start is needed to leave.
                    // The if(start) block covers this.
                    next_state = IDLE;
                end

                READ_FIRST: begin
                    if (valid_in) begin
                        // Capture first character
                        next_start_char = char_in;
                        
                        if (last_in) begin
                            // String length is 1. 
                            // Compute result now to be ready in READ_LAST next cycle.
                            next_result = (char_in == char_in); // Always true, but for logic consistency check against start_char (which is char_in)
                            // Actually, for length 1, it is always a match if we follow the logic strictly.
                            // But let's check: start_char = char_in. last_char = char_in. Result = 1.
                            // We can just set result = 1.
                            // Wait, prompt says "Compare stored start char with last character".
                            next_state = READ_LAST;
                            next_result = 1'b1; // Or (char_in == char_in)
                        end else begin
                            // More characters expected
                            next_state = READ_MIDDLE;
                        end
                    end else begin
                        // Wait for valid input
                        next_state = READ_FIRST;
                    end
                end

                READ_MIDDLE: begin
                    if (valid_in) begin
                        if (last_in) begin
                            // Last character detected.
                            // Compute result comparing stored start_char with current char_in.
                            next_result = (start_char == char_in);
                            next_state = READ_LAST;
                        end else begin
                            // Intermediate character, ignore value, just consume cycle
                            next_state = READ_MIDDLE;
                        end
                    end else begin
                        // Wait for valid input
                        next_state = READ_MIDDLE;
                    end
                end

                READ_LAST: begin
                    // This state exists to assert DONE and hold the result.
                    // Result was calculated in the previous cycle (READ_FIRST or READ_MIDDLE).
                    next_done = 1'b1;
                    next_state = DONE;
                end

                DONE: begin
                    // Computation complete. Hold result and done high until start.
                    next_done = 1'b1;
                    next_state = DONE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Sequential Logic (State Registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_char <= 8'h00;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            start_char <= next_start_char;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule
