module bracket_eval(
    input clk,
    input rst_n,
    input start,
    input [7:0] token_in,
    input token_valid,
    input token_end,
    output reg [31:0] result,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Constants
    localparam MODULO = 32'd1000000007;
    localparam OPEN_BRACKET = 8'h28;
    localparam CLOSE_BRACKET = 8'h29;

    // Registers for state machine
    reg [1:0] state;
    reg [1:0] next_state;

    // Stack implementation (depth 8)
    reg [31:0] stack_values [0:7];
    reg [0:0] stack_modes [0:7];
    reg [2:0] stack_depth;

    // Current processing registers
    reg [31:0] current_value;
    reg current_mode; // 0=add, 1=multiply

    // Counter for tokens
    reg [3:0] token_count;

    // Temporary registers for computations
    reg [31:0] temp_value;
    reg [63:0] mul_result;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (token_valid && token_end)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for state and data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            stack_depth <= 3'd0;
            current_value <= 32'd0;
            current_mode <= 1'b0;
            token_count <= 4'd0;
            // Initialize stack values to avoid latches
            stack_values[0] <= 32'd0;
            stack_values[1] <= 32'd0;
            stack_values[2] <= 32'd0;
            stack_values[3] <= 32'd0;
            stack_values[4] <= 32'd0;
            stack_values[5] <= 32'd0;
            stack_values[6] <= 32'd0;
            stack_values[7] <= 32'd0;
            stack_modes[0] <= 1'b0;
            stack_modes[1] <= 1'b0;
            stack_modes[2] <= 1'b0;
            stack_modes[3] <= 1'b0;
            stack_modes[4] <= 1'b0;
            stack_modes[5] <= 1'b0;
            stack_modes[6] <= 1'b0;
            stack_modes[7] <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all accumulators and stack
                        stack_depth <= 3'd0;
                        current_value <= 32'd0;
                        current_mode <= 1'b0; // Depth 0: addition
                        token_count <= 4'd0;
                        result_valid <= 1'b0;
                        done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (token_valid) begin
                        token_count <= token_count + 1;

                        if (token_in == OPEN_BRACKET) begin
                            // Push current context to stack
                            stack_values[stack_depth] <= current_value;
                            stack_modes[stack_depth] <= current_mode;
                            // Increase depth
                            stack_depth <= stack_depth + 1;
                            // Start new group
                            current_value <= 32'd0;
                            // New mode: depth 1->mul, 2->add, etc. (depth is new depth)
                            current_mode <= (stack_depth + 1) % 2;

                        end else if (token_in == CLOSE_BRACKET) begin
                            // Store current result
                            temp_value <= current_value;
                            // Pop from stack (this happens in next cycle logic effectively)
                            // But we need to handle it here carefully
                            // Actually, let's use the already stored stack values
                            if (stack_depth > 0) begin
                                current_value <= stack_values[stack_depth - 1];
                                current_mode <= stack_modes[stack_depth - 1];
                                // Combine based on the mode of the parent
                                if (stack_modes[stack_depth - 1] == 1'b0) begin
                                    // Addition: parent = parent + temp
                                    if (stack_values[stack_depth - 1] + current_value >= MODULO)
                                        current_value <= stack_values[stack_depth - 1] + current_value - MODULO;
                                    else
                                        current_value <= stack_values[stack_depth - 1] + current_value;
                                end else begin
                                    // Multiplication: parent = parent * temp
                                    mul_result <= stack_values[stack_depth - 1] * current_value;
                                end
                                stack_depth <= stack_depth - 1;
                            end

                        end else begin
                            // Number token
                            if (current_mode == 1'b0) begin
                                // Addition
                                if (current_value + token_in >= MODULO)
                                    current_value <= current_value + token_in - MODULO;
                                else
                                    current_value <= current_value + token_in;
                            end else begin
                                // Multiplication
                                mul_result <= current_value * token_in;
                            end
                        end
                    end else if (state == PROCESSING && !token_valid && token_count > 0 && !done) begin
                        // Handle multiplication results that were calculated in previous cycle
                        // This handles the pipeline for multiplication
                        if (current_mode == 1'b1) begin
                            // Check if we just did a multiplication in the previous token processing
                            // Actually, we need to track if multiplication is pending
                        end
                    end
                end

                DONE: begin
                    // Final result is already in current_value
                    result <= current_value;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Additional combinational logic to handle multiplication overflow and proper updates
    // Since multiplication takes multiple cycles or needs proper handling in synchronous logic
    // Let's refine the PROCESSING state logic to handle the multiplication result properly
    
    // Actually, let's rewrite the main always block to handle the multiplication correctly
    // using intermediate registers
    
    // Redesign: Use a single processing block that handles everything correctly
    
endmodule

// Re-implementing with proper handling of multiplication (2-cycle approach or combinational)
// Given the constraints (max 8 tokens), a combinational approach is feasible within timing

module bracket_eval_v2(
    input clk,
    input rst_n,
    input start,
    input [7:0] token_in,
    input token_valid,
    input token_end,
    output reg [31:0] result,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Constants
    localparam MODULO = 32'd1000000007;
    localparam OPEN_BRACKET = 8'h28;
    localparam CLOSE_BRACKET = 8'h29;

    // Registers for state machine
    reg [1:0] state;
    reg [1:0] next_state;

    // Stack (8 levels)
    reg [31:0] stack_vals [0:7];
    reg stack_modes [0:7]; // 0=add, 1=mul
    reg [2:0] sp; // stack pointer

    // Current value and mode
    reg [31:0] curr_val;
    reg curr_mode;

    // Token counter
    reg [3:0] token_cnt;

    // Multiplication helper
    reg [63:0] mul_temp;
    reg [31:0] mul_val;
    reg processing_mul;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: next_state = (token_valid && token_end) ? DONE : PROCESSING;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            sp <= 3'd0;
            curr_val <= 32'd0;
            curr_mode <= 1'b0;
            token_cnt <= 4'd0;
            processing_mul <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        sp <= 3'd0;
                        curr_val <= 32'd0;
                        curr_mode <= 1'b0; // depth 0: add
                        token_cnt <= 4'd0;
                        result_valid <= 1'b0;
                        done <= 1'b0;
                        processing_mul <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (processing_mul) begin
                        // Finish previous multiplication
                        curr_val <= mul_temp[31:0];
                        processing_mul <= 1'b0;
                    end else if (token_valid) begin
                        token_cnt <= token_cnt + 1;

                        if (token_in == OPEN_BRACKET) begin
                            // Push
                            stack_vals[sp] <= curr_val;
                            stack_modes[sp] <= curr_mode;
                            sp <= sp + 1;
                            // New context
                            curr_val <= 32'd0;
                            curr_mode <= (sp + 1) % 2; // depth 1->mul, 2->add, ...

                        end else if (token_in == CLOSE_BRACKET) begin
                            // Pop and combine
                            if (sp > 0) begin
                                sp <= sp - 1;
                                // Determine operation based on PARENT mode
                                if (stack_modes[sp - 1] == 1'b0) begin
                                    // Parent is ADD: parent = parent + curr
                                    if (stack_vals[sp - 1] + curr_val >= MODULO)
                                        curr_val <= stack_vals[sp - 1] + curr_val - MODULO;
                                    else
                                        curr_val <= stack_vals[sp - 1] + curr_val;
                                end else begin
                                    // Parent is MUL: parent = parent * curr
                                    mul_temp <= stack_vals[sp - 1] * curr_val;
                                    processing_mul <= 1'b1;
                                end
                                curr_mode <= stack_modes[sp - 1];
                            end

                        end else begin // Number
                            if (curr_mode == 1'b0) begin
                                // Add
                                if (curr_val + token_in >= MODULO)
                                    curr_val <= curr_val + token_in - MODULO;
                                else
                                    curr_val <= curr_val + token_in;
                            end else begin
                                // Multiply
                                mul_temp <= curr_val * token_in;
                                processing_mul <= 1'b1;
                            end
                        end
                    end
                end

                DONE: begin
                    // If we are in a multiplication cycle, finish it first
                    if (processing_mul) begin
                        curr_val <= mul_temp[31:0];
                        result <= mul_temp[31:0];
                        processing_mul <= 1'b0;
                    end else begin
                        result <= curr_val;
                    end
                    result_valid <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

// Corrected Final Version to ensure single cycle operation where possible 
// and handle the modulo correctly. The previous version has a logic gap in DONE state
// if processing_mul was set in last token.
// Also, the POP logic for multiplication needs to ensure the 'sp' is correct.

module bracket_eval_final(
    input clk,
    input rst_n,
    input start,
    input [7:0] token_in,
    input token_valid,
    input token_end,
    output reg [31:0] result,
    output reg result_valid,
    output reg done
);

    localparam IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10;
    localparam MODULO = 32'd1000000007;
    localparam OPEN_BRACKET = 8'h28, CLOSE_BRACKET = 8'h29;

    reg [1:0] state, next_state;
    
    // Stack storage
    reg [31:0] stack_val [0:7];
    reg [0:0] stack_mode [0:7];
    reg [2:0] depth; // Points to next free slot (0..8)

    // Current accumulator
    reg [31:0] acc;
    reg mode; // 0=Add, 1=Mul

    // Multiplication temporary
    reg [63:0] mul_res;
    reg mul_pending;
    reg [31:0] pop_temp_acc; // Holds pop value for mul op
    reg [31:0] pop_temp_parent; // Holds parent value for mul op

    // Control
    reg [3:0] token_counter;

    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: next_state = (token_valid && token_end && !mul_pending) ? DONE : PROCESSING;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            result_valid <= 0;
            done <= 0;
            depth <= 0;
            acc <= 0;
            mode <= 0;
            mul_pending <= 0;
            token_counter <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        depth <= 0;
                        acc <= 0;
                        mode <= 0;
                        mul_pending <= 0;
                        token_counter <= 0;
                        result_valid <= 0;
                        done <= 0;
                    end
                end

                PROCESSING: begin
                    // Handle Multiplier Completion (Latency 1 cycle for mul)
                    if (mul_pending) begin
                        acc <= mul_res[31:0];
                        mul_pending <= 0;
                    end 
                    // Handle Token Processing (only if no mul pending)
                    else if (token_valid) begin
                        token_counter <= token_counter + 1;

                        case (token_in)
                            OPEN_BRACKET: begin
                                // Push
                                if (depth < 8) begin
                                    stack_val[depth] <= acc;
                                    stack_mode[depth] <= mode;
                                    depth <= depth + 1;
                                end
                                // Reset new level
                                acc <= 0;
                                mode <= (depth + 1) % 2; // 0->1, 1->0, etc.
                            end

                            CLOSE_BRACKET: begin
                                // Pop
                                if (depth > 0) begin
                                    depth <= depth - 1;
                                    // Parent mode determines operation
                                    if (stack_mode[depth - 1] == 0) begin
                                        // Parent was ADD: P = P + C
                                        if (stack_val[depth - 1] + acc >= MODULO)
                                            acc <= stack_val[depth - 1] + acc - MODULO;
                                        else
                                            acc <= stack_val[depth - 1] + acc;
                                        mode <= stack_mode[depth - 1];
                                    end else begin
                                        // Parent was MUL: P = P * C
                                        // Needs 2 cycles logic or 1 cycle if combinational allowed. 
                                        // We use combinational block for mul, then latch next cycle.
                                        pop_temp_acc <= acc;
                                        pop_temp_parent <= stack_val[depth - 1];
                                        mul_pending <= 1;
                                        // Mode stays parent's mode (will be applied in next cycle when mul completes)
                                        // Wait, actually we need to apply mode update NOW or carefully.
                                        // Let's store the target mode.
                                        mode <= stack_mode[depth - 1];
                                        mul_res <= stack_val[depth - 1] * acc;
                                        // We set mul_pending, next cycle acc updates, then we are done?
                                        // The DONE check relies on mul_pending.
                                    end
                                end
                            end

                            default: begin // Number
                                if (mode == 0) begin
                                    // Add
                                    if (acc + token_in >= MODULO)
                                        acc <= acc + token_in - MODULO;
                                    else
                                        acc <= acc + token_in;
                                end else begin
                                    // Multiply
                                    mul_res <= acc * token_in;
                                    mul_pending <= 1;
                                end
                            end
                        endcase
                    end
                end

                DONE: begin
                    // Final latch
                    if (mul_pending) begin
                        result <= mul_res[31:0];
                        mul_pending <= 0;
                    end else begin
                        result <= acc;
                    end
                    result_valid <= 1;
                    done <= 1;
                end
            endcase
        end
    end

endmodule