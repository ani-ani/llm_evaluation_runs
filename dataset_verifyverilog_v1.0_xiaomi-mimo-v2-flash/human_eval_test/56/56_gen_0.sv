module BracketChecker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire str_valid,
    input wire [7:0] str_data,
    input wire str_last,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // ASCII constants
    localparam [7:0] OPEN_BRACKET  = 8'h3C; // '<'
    localparam [7:0] CLOSE_BRACKET = 8'h3E; // '>'

    // State registers
    reg [1:0] state, next_state;
    
    // Stack control registers
    reg [3:0] sp;              // Stack pointer (0-15)
    reg [3:0] next_sp;
    reg [15:0] stack;          // 16-entry stack (1 bit per entry)
    reg [15:0] next_stack;
    
    // Processing registers
    reg error_flag;
    reg next_error_flag;
    
    // Timing control
    reg process_last;
    reg next_process_last;
    reg [4:0] cycle_count;     // Up to 20 cycles
    reg [4:0] next_cycle_count;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sp <= 4'd0;
            stack <= 16'd0;
            error_flag <= 1'b0;
            process_last <= 1'b0;
            cycle_count <= 5'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            sp <= next_sp;
            stack <= next_stack;
            error_flag <= next_error_flag;
            process_last <= next_process_last;
            cycle_count <= next_cycle_count;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_sp = sp;
        next_stack = stack;
        next_error_flag = error_flag;
        next_process_last = process_last;
        next_cycle_count = cycle_count;
        result = result; // Keep previous value unless explicitly changed
        done = 1'b0;

        case (state)
            IDLE: begin
                next_sp = 4'd0;
                next_stack = 16'd0;
                next_error_flag = 1'b0;
                next_process_last = 1'b0;
                next_cycle_count = 5'd0;
                result = 1'b0;
                
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Process character if valid
                if (str_valid) begin
                    if (str_data == OPEN_BRACKET) begin
                        // Push onto stack
                        if (sp < 4'd15) begin
                            next_sp = sp + 4'd1;
                            next_stack[sp] = 1'b1;
                        end else begin
                            // Stack overflow - invalid
                            next_error_flag = 1'b1;
                        end
                    end else if (str_data == CLOSE_BRACKET) begin
                        // Pop from stack
                        if (sp > 4'd0 && stack[sp - 4'd1] == 1'b1) begin
                            next_sp = sp - 4'd1;
                        end else begin
                            // Mismatch or empty stack - invalid
                            next_error_flag = 1'b1;
                        end
                    end
                    // Other characters are ignored
                    
                    // Check if this is the last character
                    if (str_last) begin
                        next_process_last = 1'b1;
                    end
                end
                
                // After processing (or if no valid input), check completion
                if (next_process_last && !str_valid) begin
                    // Start completion countdown
                    next_cycle_count = cycle_count + 5'd1;
                    
                    if (cycle_count >= 5'd19) begin
                        // Complete after 20 cycles from str_last
                        next_state = DONE_STATE;
                    end
                end
                
                // Check error conditions that trigger immediate error
                if (error_flag || next_error_flag) begin
                    // If error detected, still need to wait for str_last to finish processing
                    if (str_last) begin
                        next_process_last = 1'b1;
                    end
                    
                    if (next_process_last && !str_valid) begin
                        next_cycle_count = cycle_count + 5'd1;
                        if (cycle_count >= 5'd19) begin
                            next_state = DONE_STATE;
                        end
                    end
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                // Determine result
                if (error_flag || sp > 4'd0) begin
                    result = 1'b0;
                end else begin
                    result = 1'b1;
                end
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                next_sp = 4'd0;
                next_stack = 16'd0;
                next_error_flag = 1'b0;
                next_process_last = 1'b0;
                next_cycle_count = 5'd0;
                result = 1'b0;
                done = 1'b0;
            end
        endcase
    end

endmodule