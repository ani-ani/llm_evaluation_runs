module matching_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0][15:0] tl_r_i,
    input wire [63:0][15:0] tl_c_i,
    input wire [63:0][15:0] br_r_i,
    input wire [63:0][15:0] br_c_i,
    output reg result_valid,
    output reg [63:0][7:0] match_index,
    output reg syntax_error
);

    // Constants
    localparam [7:0] MAX_N = 8'd64;
    localparam [6:0] TOTAL_CORNERS = 7'd128;
    localparam [10:0] MAX_CYCLES = 11'd1000;
    localparam [15:0] INVALID_COORD = 16'hFFFF;

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] READ_INPUT   = 3'd1;
    localparam [2:0] CHECK_VALID  = 3'd2;
    localparam [2:0] SORT_INIT    = 3'd3;
    localparam [2:0] SORT_PROCESS = 3'd4;
    localparam [2:0] VALIDATE     = 3'd5;
    localparam [2:0] OUTPUT_STATE = 3'd6;
    localparam [2:0] ERROR_STATE  = 3'd7;

    // Register arrays for corners: 128 entries, each {type[1:0], r[15:0], c[15:0], id[7:0]}
    // type: 2'b00 = TL, 2'b01 = BR
    reg [24:0] corners [0:127];
    reg [24:0] next_corners [0:127];
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] n, next_n;
    reg [7:0] i, next_i;  // Generic index
    reg [7:0] j, next_j;  // Generic index
    reg [7:0] k, next_k;  // Generic index
    reg [10:0] cycle_count, next_cycle_count;
    reg [7:0] stack [0:63];  // Nesting stack for validation
    reg [7:0] stack_ptr, next_stack_ptr;
    reg [7:0] temp_id, next_temp_id;
    reg [7:0] match_valid_count, next_match_valid_count;
    reg temp_valid, next_temp_valid;
    
    // Helper for comparator
    reg compare_result, next_compare_result;
    reg [1:0] type_a, type_b;
    reg [15:0] r_a, r_b;
    reg [15:0] c_a, c_b;
    reg [7:0] id_a, id_b;

    integer idx; // Loop variable for initialization

    // Combinational logic block for sorting and state transitions
    always @(*) begin
        // Default assignments
        next_state = state;
        next_n = n;
        next_i = i;
        next_j = j;
        next_k = k;
        next_cycle_count = cycle_count;
        next_stack_ptr = stack_ptr;
        next_temp_id = temp_id;
        next_match_valid_count = match_valid_count;
        next_temp_valid = temp_valid;
        next_compare_result = compare_result;
        result_valid = 1'b0;
        syntax_error = 1'b0;
        
        // Corner array default (preserves values unless updated)
        for (idx = 0; idx < 128; idx = idx + 1) begin
            next_corners[idx] = corners[idx];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_INPUT;
                    next_cycle_count = 11'd1;
                    next_n = 8'd0;
                    next_i = 8'd0;
                end
            end

            READ_INPUT: begin
                // Read input for n (count of TL corners)
                // We assume n is implicitly the number of valid entries (all up to 63 are used)
                // For simplicity, we process all 64 possible corners
                if (next_i < MAX_N) begin
                    // Read TL corner
                    next_corners[next_i * 2].type = 2'b00;
                    next_corners[next_i * 2].r = tl_r_i[next_i];
                    next_corners[next_i * 2].c = tl_c_i[next_i];
                    next_corners[next_i * 2].id = next_i;
                    
                    // Read BR corner
                    next_corners[next_i * 2 + 1].type = 2'b01;
                    next_corners[next_i * 2 + 1].r = br_r_i[next_i];
                    next_corners[next_i * 2 + 1].c = br_c_i[next_i];
                    next_corners[next_i * 2 + 1].id = next_i;
                    
                    next_i = next_i + 8'd1;
                    next_cycle_count = cycle_count + 11'd1;
                end else begin
                    next_state = CHECK_VALID;
                    next_i = 8'd0;
                end
            end

            CHECK_VALID: begin
                if (next_i < MAX_N) begin
                    // Check validity of rectangle: tl_r <= br_r and tl_c <= br_c
                    if ((tl_r_i[next_i] > br_r_i[next_i]) || (tl_c_i[next_i] > br_c_i[next_i])) begin
                        next_state = ERROR_STATE;
                    end else begin
                        next_i = next_i + 8'd1;
                    end
                    next_cycle_count = cycle_count + 11'd1;
                end else begin
                    next_state = SORT_INIT;
                    next_i = 8'd1;  // Start bubble sort outer loop
                    next_j = 8'd0;
                end
            end

            SORT_INIT: begin
                next_state = SORT_PROCESS;
                next_j = 8'd0;
            end

            SORT_PROCESS: begin
                // Bubble sort pass
                if (next_j < (TOTAL_CORNERS - 1 - next_i)) begin
                    // Extract fields for comparison
                    type_a = next_corners[next_j].type;
                    r_a = next_corners[next_j].r;
                    c_a = next_corners[next_j].c;
                    
                    type_b = next_corners[next_j + 1].type;
                    r_b = next_corners[next_j + 1].r;
                    c_b = next_corners[next_j + 1].c;
                    
                    // Compare: sort by r ascending, then c ascending, then type (TL before BR)
                    // Note: Standard nesting logic usually prefers processing TL before BR if same position
                    // However, standard stack validation requires TL encountered before BR for nesting
                    // Let's sort strictly by (r, c). If r and c are equal, TL (00) comes before BR (01) is typical but
                    // problem statement implies corners are distinct locations.
                    // If coordinates are distinct, type doesn't matter for order.
                    
                    if (r_a > r_b) begin
                        next_compare_result = 1'b1; // Swap needed
                    end else if (r_a == r_b) begin
                        if (c_a > c_b) begin
                            next_compare_result = 1'b1;
                        end else begin
                            next_compare_result = 1'b0;
                        end
                    end else begin
                        next_compare_result = 1'b0;
                    end
                    
                    if (next_compare_result) begin
                        // Swap
                        next_corners[next_j] = corners[next_j + 1];
                        next_corners[next_j + 1] = corners[next_j];
                    end
                    
                    next_j = next_j + 8'd1;
                    next_cycle_count = cycle_count + 11'd1;
                end else begin
                    next_i = next_i + 8'd1;
                    if (next_i >= TOTAL_CORNERS) begin
                        next_state = VALIDATE;
                        next_stack_ptr = 8'd0;
                        next_match_valid_count = 8'd0;
                        next_temp_valid = 1'b1;
                    end else begin
                        next_state = SORT_INIT;
                    end
                    next_j = 8'd0;
                end
            end

            VALIDATE: begin
                if (next_i < TOTAL_CORNERS && cycle_count < MAX_CYCLES) begin
                    // Process corners in sorted order
                    if (next_corners[next_i].type == 2'b00) begin
                        // TL: Push to stack
                        stack[next_stack_ptr] = next_corners[next_i].id;
                        next_stack_ptr = stack_ptr + 8'd1;
                    end else begin
                        // BR: Pop from stack
                        if (stack_ptr == 8'd0) begin
                            // Stack empty but we have a BR -> invalid
                            next_temp_valid = 1'b0;
                            next_state = ERROR_STATE;
                        end else begin
                            next_stack_ptr = stack_ptr - 8'd1;
                            // Check if popped ID matches current BR ID
                            if (stack[stack_ptr - 8'd1] != next_corners[next_i].id) begin
                                next_temp_valid = 1'b0;
                                next_state = ERROR_STATE;
                            end else begin
                                // Valid match found
                                // Record match: match_index[tl_id] = br_id
                                // Note: match_index array output needs to be populated here
                                // Since we are in combinational block, we can't directly assign to 'match_index' output reg array easily
                                // We will do it in the sequential block during state transition or dedicated output state
                                // Actually, let's verify logic first. If valid, we continue.
                                next_match_valid_count = match_valid_count + 8'd1;
                            end
                        end
                    end
                    next_i = next_i + 8'd1;
                    next_cycle_count = cycle_count + 11'd1;
                end else begin
                    // Finished iterating or timed out
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = ERROR_STATE;
                    end else if (stack_ptr != 8'd0) begin
                        // Stack not empty at end -> invalid
                        next_state = ERROR_STATE;
                    end else if (!next_temp_valid) begin
                        next_state = ERROR_STATE;
                    end else begin
                        // Valid match
                        // We need to construct the output. 
                        // The validation loop checked consistency.
                        // We need to run a second pass to actually build the match_index array.
                        // Or we can do it here: 
                        // The stack method validates nesting. It ensures that for every TL, 
                        // the corresponding BR is the one closing the innermost rectangle.
                        // However, the stack method validates the nesting structure but doesn't explicitly 
                        // assign TL IDs to BR IDs unless we track them carefully.
                        // Actually, if we assume the input is consistent (1 TL per BR per ID), 
                        // the validation confirms the nesting order is correct.
                        // But we need to output the permutation.
                        // Let's assume the input structure is:
                        // TL corners have IDs 0..N-1. BR corners have IDs 0..N-1.
                        // The problem says "match_index[i] = BR corner ID for TL corner i".
                        // This implies we need to pair them up.
                        // The sorting + stack validation is sufficient to check validity.
                        // To generate the output, we need to know which BR goes with which TL.
                        // If we assumed the ID fields in the corners array correspond to the input indices,
                        // then we just need to perform the pairing.
                        // However, the stack logic: 
                        // Push TL(0). Push TL(1). 
                        // Pop BR(1). Pop BR(0).
                        // This requires IDs to match stack order if strictly nested.
                        // If we just need *a* valid matching, we can construct it by matching sorted order.
                        // But we need to fill 'match_index'.
                        // Let's do a dedicated pass for output construction.
                        next_state = OUTPUT_STATE;
                        next_i = 8'd0;
                        next_stack_ptr = 8'd0;
                    end
                end
            end

            OUTPUT_STATE: begin
                // Construct match_index array
                // We re-simulate the stack logic to fill the array
                if (next_i < TOTAL_CORNERS) begin
                    if (corners[next_i].type == 2'b00) begin
                        stack[next_stack_ptr] = corners[next_i].id;
                        next_stack_ptr = stack_ptr + 8'd1;
                    end else begin
                        // BR corner
                        if (stack_ptr > 8'd0) begin
                            next_stack_ptr = stack_ptr - 8'd1;
                            temp_id = stack[stack_ptr - 8'd1]; // TL ID
                            // Assign match_index[temp_id] = BR ID
                            // We cannot assign to array directly in combinational block to reg output easily without slicing
                            // We handle this in the sequential block logic.
                            // For now, we just iterate. The actual assignment will happen in sequential logic based on flags.
                            // Or simpler: Set a "write_enable" and data to internal signals.
                            // But to keep it simple: We will just check validity here and set result_valid.
                            // The actual fill of 'match_index' is tricky in one pass combinational if we want to keep it clean.
                            // Let's assume for this specific "generation" task, we can fill it inside the FSM sequential block.
                            // To do that, we need to flag when a match occurs.
                            // Let's add logic to 'match_index' in the sequential block using 'state' == OUTPUT_STATE.
                        end else begin
                            // Should not happen if valid was checked
                        end
                    end
                    next_i = next_i + 8'd1;
                end else begin
                    result_valid = 1'b1;
                    next_state = IDLE;
                end
            end

            ERROR_STATE: begin
                syntax_error = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            cycle_count <= 11'd0;
            stack_ptr <= 8'd0;
            temp_id <= 8'd0;
            match_valid_count <= 8'd0;
            temp_valid <= 1'b0;
            compare_result <= 1'b0;
            
            // Initialize corners array to prevent X
            for (idx = 0; idx < 128; idx = idx + 1) begin
                corners[idx] <= 25'd0;
                next_corners[idx] <= 25'd0;
            end
            // Initialize match_index to 0
            for (idx = 0; idx < 64; idx = idx + 1) begin
                match_index[idx] <= 8'd0;
            end
            
        end else begin
            state <= next_state;
            n <= next_n;
            i <= next_i;
            j <= next_j;
            k <= next_k;
            cycle_count <= next_cycle_count;
            stack_ptr <= next_stack_ptr;
            temp_id <= next_temp_id;
            match_valid_count <= next_match_valid_count;
            temp_valid <= next_temp_valid;
            compare_result <= next_compare_result;
            
            // Update corners array
            for (idx = 0; idx < 128; idx = idx + 1) begin
                corners[idx] <= next_corners[idx];
            end
            
            // Handle match_index assignment during OUTPUT_STATE
            // We need to detect rising edge of matching logic or use combinational flag
            // Since the combinational block calculates the next stack operations,
            // we need to know if a match occurred in the current cycle.
            // This is hard to do purely logically without registers for the stack content.
            // Let's modify the approach: Do the matching logic entirely in sequential block for OUTPUT_STATE.
            // Reset stack in IDLE or OUTPUT_STATE entry.
            
            if (state == OUTPUT_STATE) begin
                // Re-implement the stack logic here to fill match_index
                if (i < TOTAL_CORNERS) begin
                    if (corners[i].type == 2'b00) begin
                        // TL: Push ID
                        stack[stack_ptr] <= corners[i].id;
                        stack_ptr <= stack_ptr + 8'd1;
                    end else begin
                        // BR: Pop ID and match
                        if (stack_ptr > 8'd0) begin
                            stack_ptr <= stack_ptr - 8'd1;
                            // TL ID is stack[stack_ptr-1], BR ID is corners[i].id
                            // We need to wait one cycle or use combinational output?
                            // Let's write to match_index directly.
                            match_index[stack[stack_ptr - 8'd1]] <= corners[i].id;
                        end
                    end
                end
            end else if (state == IDLE) begin
                stack_ptr <= 8'd0;
                for (idx = 0; idx < 64; idx = idx + 1) begin
                    match_index[idx] <= 8'd0;
                end
            end
        end
    end

endmodule