module trope_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] cmd_type,
    input [23:0] event_hash,
    input [2:0] dream_count,
    input [2:0] scenario_count,
    input [23:0] scenario_event_hash_0,
    input scenario_event_negate_0,
    input [23:0] scenario_event_hash_1,
    input scenario_event_negate_1,
    input [23:0] scenario_event_hash_2,
    input scenario_event_negate_2,
    input [23:0] scenario_event_hash_3,
    input scenario_event_negate_3,
    input [23:0] scenario_event_hash_4,
    input scenario_event_negate_4,
    output reg result_valid,
    output reg [1:0] result_code,
    output reg [2:0] dream_amount
);

    // Parameters
    parameter MAX_HISTORY = 4;
    parameter MAX_SCENARIO = 5;
    parameter EVENT_HASH_WIDTH = 24;

    // Internal Registers and Wires
    reg [1:0] stack_depth; // Current number of valid events in stack
    reg [EVENT_HASH_WIDTH-1:0] history_stack [0:MAX_HISTORY-1];

    // Stack Management (Combinational Next State Logic)
    reg [EVENT_HASH_WIDTH-1:0] next_stack [0:MAX_HISTORY-1];
    reg [1:0] next_depth;

    // FSM State Definition
    reg [2:0] current_state, next_state;
    localparam IDLE = 3'b000;
    localparam PROCESS_CMD = 3'b001;
    localparam SCENARIO_CHECK_0 = 3'b010;
    localparam SCENARIO_CHECK_1 = 3'b011;
    localparam UPDATE_STACK = 3'b100;
    localparam FINISH = 3'b101;

    // Scenario Processing Variables
    reg [2:0] sc_count;
    reg [23:0] sc_hashes [0:4];
    reg [4:0] sc_negates; // Concatenated negate flags

    // Check Variables
    reg [2:0] r; // Rollback amount
    reg [2:0] r_check; // Current r being checked
    reg match_found; // Flag for consistency
    reg partial_match; // Flag for dream scenario

    // --- State Machine Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            stack_depth <= 0;
            // Initialize stack content (optional but good practice)
            // history_stack content doesn't strictly need reset as stack_depth manages validity
        end else begin
            current_state <= next_state;

            // Update Stack Registers (only when needed or reset)
            // We update stack content in UPDATE_STACK state, or clear in IDLE (if we wanted to clear on reset)
            // Actually, we should update stack content when we transition to IDLE from PROCESS_CMD or UPDATE_STACK
            // But to ensure we don't lose data during multi-cycle logic, we update on the transition out of processing.
            if (next_state == IDLE && current_state != IDLE) begin
                // Update physical registers from combinational logic
                history_stack[0] <= next_stack[0];
                history_stack[1] <= next_stack[1];
                history_stack[2] <= next_stack[2];
                history_stack[3] <= next_stack[3];
                stack_depth <= next_depth;
            end
        end
    end

    // --- Combinational Logic ---
    always @(*) begin
        // Default assignments
        next_state = current_state;

        // Default stack output (pass through)
        integer i;
        for (i = 0; i < MAX_HISTORY; i = i + 1) begin
            next_stack[i] = history_stack[i];
        end
        next_depth = stack_depth;

        // Output defaults
        result_valid = 1'b0;
        result_code = 2'b00;
        dream_amount = 3'b000;

        // Logic variables defaults
        match_found = 1'b0;
        partial_match = 1'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS_CMD;
                end
            end

            PROCESS_CMD: begin
                // Decode cmd_type
                case (cmd_type)
                    3'd0: begin // Event: Push
                        // Shift stack and add new event
                        if (stack_depth < MAX_HISTORY) begin
                            // Simply append to the end (treating stack as simple array)
                            // Let's treat index 0 as oldest, 3 as newest
                            // Push: shift existing, add new at end
                            next_stack[0] = history_stack[1];
                            next_stack[1] = history_stack[2];
                            next_stack[2] = history_stack[3];
                            next_stack[3] = event_hash;
                            next_depth = stack_depth + 1;
                        end else begin
                            // Full: Discard oldest (shift out index 0)
                            next_stack[0] = history_stack[1];
                            next_stack[1] = history_stack[2];
                            next_stack[2] = history_stack[3];
                            next_stack[3] = event_hash;
                            next_depth = MAX_HISTORY;
                        end
                        next_state = FINISH;
                    end

                    3'd1: begin // Dream: Pop
                        // Remove dream_count events
                        // If dream_count > stack_depth, empty the stack
                        if (dream_count >= stack_depth) begin
                            next_depth = 0;
                            // Stack content becomes irrelevant when depth is 0
                        end else begin
                            next_depth = stack_depth - dream_count;
                            // Shift remaining elements to the beginning
                            // We need to move indices [dream_count : depth-1] to [0 : new_depth-1]
                            // Verilog shift register logic
                            for (i = 0; i < MAX_HISTORY; i = i + 1) begin
                                if (i + dream_count < MAX_HISTORY) begin
                                    next_stack[i] = history_stack[i + dream_count];
                                end else begin
                                    next_stack[i] = 24'h000000; // Invalidate
                                end
                            end
                        end
                        next_state = FINISH;
                    end

                    3'd2: begin // Scenario
                        // Latch inputs into local arrays
                        sc_count = scenario_count;
                        sc_hashes[0] = scenario_event_hash_0;
                        sc_hashes[1] = scenario_event_hash_1;
                        sc_hashes[2] = scenario_event_hash_2;
                        sc_hashes[3] = scenario_event_hash_3;
                        sc_hashes[4] = scenario_event_hash_4;
                        sc_negates = {scenario_event_negate_4, scenario_event_negate_3, scenario_event_negate_2, scenario_event_negate_1, scenario_event_negate_0};

                        // Start Check Logic
                        // Step 1: Check against current stack (r=0)
                        // Step 2: If fail, check r=1,2,3,4

                        next_state = SCENARIO_CHECK_0;
                    end
                endcase
            end

            // --- Scenario Consistency Check Logic ---
            // We implement a loop using states.
            // SCENARIO_CHECK_0: Check current stack (r=0)
            // SCENARIO_CHECK_1: Check if current stack failed. If so, try r=1.
            // SCENARIO_CHECK_2: Try r=2.
            // SCENARIO_CHECK_3 (embedded logic) or state cycling.

            // To meet latency requirement and keep logic simple, we can do:
            // State 0: Verify current stack (r=0)
            // State 1: Loop 1..4 for rollbacks

            SCENARIO_CHECK_0: begin
                // Perform check for r=0 (current stack)
                // We need to iterate through scenario events and match with stack
                // Assume chronological order: Event 0 (oldest scenario event) must match or not match relative to stack
                // Stack: history_stack[0] is oldest.

                // Let's run a check loop logic here (combinational block)
                // Since Verilog is parallel, we need to unroll or use a flag.
                // Let's create a combinational check task logic inline.

                // Check with r_check = 0
                match_found = check_consistency(0, stack_depth, history_stack, sc_count, sc_hashes, sc_negates);

                if (match_found) begin
                    result_valid = 1'b1;
                    result_code = 2'b01; // Yes
                    next_state = IDLE;
                end else begin
                    // Try rollbacks
                    r_check = 1;
                    next_state = SCENARIO_CHECK_1;
                end
            end

            SCENARIO_CHECK_1: begin
                // Try rollback r_check
                match_found = check_consistency(r_check, stack_depth, history_stack, sc_count, sc_hashes, sc_negates);

                if (match_found) begin
                    result_valid = 1'b1;
                    result_code = 2'b10; // Just A Dream
                    dream_amount = r_check;
                    next_state = IDLE;
                end else begin
                    r_check = r_check + 1;
                    if (r_check > 4) begin
                        // All failed
                        result_valid = 1'b1;
                        result_code = 2'b00; // Plot Error
                        next_state = IDLE;
                    end else begin
                        next_state = SCENARIO_CHECK_1; // Stay in this state to check next r
                    end
                end
            end

            // We need a specific state to handle the transition from UPDATE logic or other flows
            // Actually, we can optimize.
            // We have SCENARIO_CHECK_0 for r=0.
            // We have SCENARIO_CHECK_1 to iterate r=1..4.
            // This covers the logic.
            // However, the instructions say "If mismatch, calculate minimal rollback r".
            // The logic in SCENARIO_CHECK_1 iterates r=1,2,3,4 sequentially. Since we update r_check, it finds the minimal one naturally.

            // Wait, I used SCENARIO_CHECK_1 in a loop fashion.
            // But what if we fall through from SCENARIO_CHECK_0? We set next_state to SCENARIO_CHECK_1.
            // Inside SCENARIO_CHECK_1, if we match, we go IDLE. If we fail, we increment r_check.
            // Since next_state is SCENARIO_CHECK_1 again, it loops.
            // This works.

            FINISH: begin
                // This state was added for Event/Dream processing to complete the cycle
                // Transition back to IDLE
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // --- Helper Function for Consistency Check ---
    // Verilog 2001 allows functions to be declared inside the module
    // Note: Functions can't have time controls (like @(posedge clk)), they are combinational.
    function automatic logic check_consistency;
        input [2:0] rollback; // Number of popped events
        input [1:0] cur_depth;
        input [EVENT_HASH_WIDTH-1:0] stack [0:MAX_HISTORY-1];
        input [2:0] scen_count;
        input [EVENT_HASH_WIDTH-1:0] scen_hashes [0:4];
        input [4:0] scen_negates;

        integer i, stack_idx;
        logic valid;
        logic cur_check;
        logic [EVENT_HASH_WIDTH-1:0] s_hash;
        logic s_neg;
        logic stack_event_found;

        begin
            valid = 1'b1;

            // Loop through all scenario events
            for (i = 0; i < 5; i = i + 1) begin
                if (i < scen_count) begin
                    // Get scenario event
                    s_hash = scen_hashes[i];
                    s_neg = scen_negates[i]; // Check bit i

                    // Search in stack
                    // Effective depth after rollback
                    logic effective_empty;
                    effective_empty = (cur_depth <= rollback);

                    if (effective_empty) begin
                        // Stack is empty
                        if (s_neg == 0) begin
                            // Required to be present -> Fail
                            valid = 1'b0;
                        end
                        // If negative (must not be present) -> OK
                    end else begin
                        // Stack has events. Check from [rollback] to [cur_depth-1]
                        stack_event_found = 1'b0;
                        for (stack_idx = rollback; stack_idx < MAX_HISTORY; stack_idx = stack_idx + 1) begin
                            if (stack_idx < cur_depth) begin
                                if (stack[stack_idx] == s_hash) begin
                                    stack_event_found = 1'b1;
                                end
                            end
                        end

                        // Validate
                        if (s_neg == 0 && !stack_event_found) valid = 1'b0; // Required, not found
                        if (s_neg == 1 && stack_event_found) valid = 1'b0; // Forbidden, found
                    end
                end
            end

            check_consistency = valid;
        end
    endfunction

endmodule