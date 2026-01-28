module ArrayRemovalGame (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_STACK    = 3'd1;
    localparam [2:0] PROCESS_LOOP  = 3'd2;
    localparam [2:0] CALC_SCORE    = 3'd3;
    localparam [2:0] FINISH        = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, next_i;          // Input array index
    reg [3:0] sp, next_sp;        // Stack pointer
    reg [31:0] result_reg, next_result;
    reg [31:0] stack_vals [0:15]; // Stack values
    reg [3:0] stack_ptr;          // Current stack size
    reg [3:0] j, next_j;          // Loop index for final scoring
    reg [3:0] saved_n, next_saved_n;
    reg processing_done, next_processing_done;
    
    // Temporary calculation variables
    reg [31:0] temp_min;
    reg [31:0] temp_score;

    integer k;

    // State transition logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_sp = sp;
        next_result = result_reg;
        next_j = j;
        next_saved_n = saved_n;
        next_processing_done = processing_done;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_STACK;
                    next_i = 4'd0;
                    next_sp = 4'd0;
                    next_result = 32'd0;
                    next_saved_n = n;
                    next_j = 4'd0;
                    next_processing_done = 1'b0;
                end
            end

            LOAD_STACK: begin
                // Push first element (or all elements if n=1)
                if (i < saved_n) begin
                    if (sp < 4'd16) begin
                        next_sp = sp + 4'd1;
                        // Stack_vals will be updated in sequential block
                    end
                    next_i = i + 4'd1;
                    if (next_i >= saved_n) begin
                        next_state = PROCESS_LOOP;
                        next_i = 4'd1; // Start processing from index 1
                    end
                end
            end

            PROCESS_LOOP: begin
                if (i < saved_n) begin
                    // While condition: sp > 1 AND stack[sp-1] <= min(arr[i], stack[sp-2])
                    if (sp > 4'd1) begin
                        // Check if stack[sp-1] is "removable"
                        // Calculate min(arr[i], stack[sp-2])
                        if (arr[i] < stack_vals[sp-2]) begin
                            temp_min = {16'd0, arr[i]};
                        end else begin
                            temp_min = stack_vals[sp-2];
                        end
                        
                        if (stack_vals[sp-1] <= temp_min) begin
                            // Add score: min(arr[i], stack[sp-2])
                            next_result = result_reg + temp_min;
                            // Pop stack (decrement sp)
                            next_sp = sp - 4'd1;
                            // Stay at same i to re-evaluate
                        end else begin
                            // Push arr[i] onto stack
                            next_state = LOAD_STACK; // Reuse LOAD_STACK state logic
                            next_sp = sp; // Don't change sp yet, will be incremented
                            // In LOAD_STACK we handle the push
                        end
                    end else begin
                        // Push arr[i] onto stack
                        next_state = LOAD_STACK;
                        next_sp = sp;
                    end
                end else begin
                    // All elements processed
                    next_state = CALC_SCORE;
                    next_j = 4'd1; // Start from stack index 1
                end
            end

            CALC_SCORE: begin
                // Add min(stack[j-1], stack[j+1]) for j = 1 to sp-2
                if (j < sp - 4'd1) begin
                    if (stack_vals[j-1] < stack_vals[j+1]) begin
                        temp_score = stack_vals[j-1];
                    end else begin
                        temp_score = stack_vals[j+1];
                    end
                    next_result = result_reg + temp_score;
                    next_j = j + 4'd1;
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            sp <= 4'd0;
            result_reg <= 32'd0;
            j <= 4'd0;
            saved_n <= 4'd0;
            processing_done <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            stack_ptr <= 4'd0;
            // Initialize stack array
            for (k = 0; k < 16; k = k + 1) begin
                stack_vals[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            i <= next_i;
            sp <= next_sp;
            result_reg <= next_result;
            j <= next_j;
            saved_n <= next_saved_n;
            processing_done <= next_processing_done;
            stack_ptr <= next_sp;
            
            // Handle stack updates
            if (state == LOAD_STACK) begin
                if (i < saved_n && sp < 4'd16) begin
                    stack_vals[sp] <= {16'd0, arr[i]};
                end
            end
            
            // Handle output
            if (state == FINISH) begin
                result <= result_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule