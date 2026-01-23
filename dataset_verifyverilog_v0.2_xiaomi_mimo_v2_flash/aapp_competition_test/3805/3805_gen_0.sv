module wire_untangle(
    input clk,
    input rst_n,
    input start,
    input [5:0] char_in,
    input valid_in,
    input end_in,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam RECV = 2'b01;
    localparam PROCESS = 2'b10;
    localparam COMPLETE = 2'b11;

    reg [1:0] state, next_state;
    reg [4:0] sp, next_sp; // Stack pointer (0 to 32)
    reg [5:0] stack [0:31]; // 32 deep stack, 6-bit wide
    reg result_reg, next_result;
    reg done_reg, next_done;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sp <= 5'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            sp <= next_sp;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_sp = sp;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = RECV;
                    next_sp = 5'b0;
                end
            end

            RECV: begin
                if (valid_in) begin
                    if (sp == 5'b0) begin
                        // Stack empty, push
                        next_sp = sp + 1'b1;
                        stack[sp] = char_in; // Note: stack[0] is updated when sp=0, but we treat it as push to 0
                    end else begin
                        // Check top element. sp points to next empty slot, so top is at sp-1
                        if (stack[sp - 1] == char_in) begin
                            // Match found, pop
                            next_sp = sp - 1'b1;
                        end else begin
                            // No match, push
                            next_sp = sp + 1'b1;
                            stack[sp] = char_in;
                        end
                    end
                end

                if (end_in) begin
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                // Check if stack is empty
                if (sp == 5'b0) begin
                    next_result = 1'b1; // Can be untangled
                end else begin
                    next_result = 1'b0; // Cannot be untangled
                end
                next_state = COMPLETE;
            end

            COMPLETE: begin
                // Stay in COMPLETE until reset or start (handled in IDLE on next start)
                // Note: done is already high from the cycle we entered COMPLETE
            end

            default: next_state = IDLE;
        endcase
    end

endmodule