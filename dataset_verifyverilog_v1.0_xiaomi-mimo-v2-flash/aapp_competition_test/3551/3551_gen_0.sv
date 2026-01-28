module IceCreamTransferSolver(
    input clk,
    input rst_n,
    input start,
    input [7:0] vol_0,
    input [7:0] vol_1,
    input [7:0] vol_2,
    input [7:0] vol_3,
    input [7:0] target_t,
    output reg result,
    output reg done
);

    // State declarations for main FSM
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT_BFS    = 3'd1;
    localparam [2:0] PROCESS     = 3'd2;
    localparam [2:0] CHECK_MATCH = 3'd3;
    localparam [2:0] SET_RESULT  = 3'd4;
    localparam [2:0] SET_DONE    = 3'd5;
    localparam [2:0] RESET_OUT   = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // State encoding: [11:8] = bitmask of full bottles (4 bits), [7:0] = total amount (8 bits)
    // For simplicity, we represent state as [11:0]
    // Queue storage: max 256 states, each 12 bits
    reg [11:0] queue [0:255];
    reg [7:0] queue_head; // points to next state to process
    reg [7:0] queue_tail; // points to next free slot
    reg [7:0] queue_count; // number of states in queue

    // Parent pointers for path reconstruction (256 states, max 8 bits for parent index)
    reg [7:0] parent [0:255];

    // Visited tracking (using bitmask for 256 possible states)
    // Since we have 4 bits for full mask (16 combos) and 8 bits for amount (256 values), max 4096 states
    // But we're limited to 256 states in queue, so we use a simple visited flag array
    reg visited [0:4095];

    // Current state being processed
    reg [11:0] current_state;
    reg [3:0] current_full_mask;
    reg [7:0] current_amount;

    // Helper registers for transitions
    reg [3:0] transition_full_mask;
    reg [7:0] transition_amount;
    reg [3:0] bottle_idx;
    reg [11:0] new_state;
    reg state_found;
    reg [7:0] visited_idx;

    // BFS depth counter
    reg [8:0] step_counter; // 9 bits, max 512
    localparam [8:0] MAX_STEPS = 9'd256;

    // Transition states
    localparam [2:0] TRANS_IDLE    = 3'd0;
    localparam [2:0] TRANS_FILL     = 3'd1;
    localparam [2:0] TRANS_EMPTY    = 3'd2;
    localparam [2:0] TRANS_TRANSFER = 3'd3;
    localparam [2:0] TRANS_CHECK    = 3'd4;
    localparam [2:0] TRANS_ENQUEUE  = 3'd5;
    localparam [2:0] TRANS_DONE     = 3'd6;

    reg [2:0] trans_state;
    reg [2:0] trans_next_state;
    reg [3:0] from_bottle;
    reg [3:0] to_bottle;

    // Bottle volumes array (unpack into individual regs for Icarus compatibility)
    reg [7:0] volumes [0:3];

    integer i;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_count <= 8'd0;
            step_counter <= 9'd0;
            current_state <= 12'd0;
            current_full_mask <= 4'd0;
            current_amount <= 8'd0;
            trans_state <= TRANS_IDLE;
            for (i = 0; i < 256; i = i + 1) begin
                queue[i] <= 12'd0;
                parent[i] <= 8'd0;
            end
            for (i = 0; i < 4096; i = i + 1) begin
                visited[i] <= 1'b0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                volumes[i] <= 8'd0;
            end
            bottle_idx <= 4'd0;
            transition_full_mask <= 4'd0;
            transition_amount <= 8'd0;
            new_state <= 12'd0;
            state_found <= 1'b0;
            visited_idx <= 8'd0;
            from_bottle <= 4'd0;
            to_bottle <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    step_counter <= 9'd0;
                    if (start) begin
                        // Copy volumes to internal array
                        volumes[0] <= vol_0;
                        volumes[1] <= vol_1;
                        volumes[2] <= vol_2;
                        volumes[3] <= vol_3;
                    end
                end

                INIT_BFS: begin
                    // Initialize BFS structures
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    queue_count <= 8'd0;
                    // Clear visited array (partially)
                    for (i = 0; i < 256; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 256; i < 512; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 512; i < 768; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 768; i < 1024; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 1024; i < 1280; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 1280; i < 1536; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 1536; i < 1792; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 1792; i < 2048; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 2048; i < 2304; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 2304; i < 2560; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 2560; i < 2816; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 2816; i < 3072; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 3072; i < 3328; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 3328; i < 3584; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 3584; i < 3840; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    for (i = 3840; i < 4096; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    // Add initial state (all empty, 0 amount, full mask = 0)
                    queue[0] <= 12'd0;
                    parent[0] <= 8'd255; // 255 = no parent (invalid)
                    visited[0] <= 1'b1; // State index 0 (mask 0, amount 0)
                    queue_tail <= 8'd1;
                    queue_count <= 8'd1;
                end

                PROCESS: begin
                    // Process transitions for current_state
                    // Initialize transition state machine
                    trans_state <= TRANS_FILL;
                    bottle_idx <= 4'd0;
                    from_bottle <= 4'd0;
                    to_bottle <= 4'd0;
                end

                CHECK_MATCH: begin
                    // Check if we found target
                    if (current_amount == target_t) begin
                        state <= SET_RESULT;
                        result <= 1'b1;
                    end else begin
                        // Move to next state in queue
                        queue_head <= queue_head + 8'd1;
                        queue_count <= queue_count - 8'd1;
                        step_counter <= step_counter + 9'd1;
                        // Check if queue is empty or max steps reached
                        if ((queue_count == 8'd1) || (step_counter >= MAX_STEPS)) begin
                            state <= SET_RESULT;
                            result <= 1'b0;
                        end else begin
                            // Load next state to process
                            current_state <= queue[queue_head + 8'd1];
                            current_full_mask <= queue[queue_head + 8'd1][11:8];
                            current_amount <= queue[queue_head + 8'd1][7:0];
                            state <= PROCESS;
                        end
                    end
                end

                SET_RESULT: begin
                    // Result already set in previous state
                    state <= SET_DONE;
                end

                SET_DONE: begin
                    done <= 1'b1;
                    state <= RESET_OUT;
                end

                RESET_OUT: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Transition processing FSM (runs when in PROCESS state)
            if (state == PROCESS) begin
                case (trans_state)
                    TRANS_FILL: begin
                        if (bottle_idx < 4) begin
                            // Try to fill bottle_idx if not full
                            if (current_full_mask[bottle_idx] == 1'b0) begin
                                transition_full_mask <= current_full_mask | (1'b1 << bottle_idx);
                                transition_amount <= current_amount + volumes[bottle_idx];
                                trans_state <= TRANS_CHECK;
                            end else begin
                                // Already full, try next
                                bottle_idx <= bottle_idx + 4'd1;
                            end
                        end else begin
                            // Done all fills, move to empty
                            bottle_idx <= 4'd0;
                            trans_state <= TRANS_EMPTY;
                        end
                    end

                    TRANS_EMPTY: begin
                        if (bottle_idx < 4) begin
                            // Try to empty bottle_idx if full
                            if (current_full_mask[bottle_idx] == 1'b1) begin
                                transition_full_mask <= current_full_mask & ~(1'b1 << bottle_idx);
                                transition_amount <= current_amount - volumes[bottle_idx];
                                trans_state <= TRANS_CHECK;
                            end else begin
                                // Already empty, try next
                                bottle_idx <= bottle_idx + 4'd1;
                            end
                        end else begin
                            // Done all empties, move to transfer
                            from_bottle <= 4'd0;
                            to_bottle <= 4'd0;
                            trans_state <= TRANS_TRANSFER;
                        end
                    end

                    TRANS_TRANSFER: begin
                        if (from_bottle < 4) begin
                            if (to_bottle < 4) begin
                                if (from_bottle != to_bottle) begin
                                    // Try transfer from from_bottle to to_bottle
                                    // From must be full, to must be empty
                                    if ((current_full_mask[from_bottle] == 1'b1) && 
                                        (current_full_mask[to_bottle] == 1'b0)) begin
                                        // New state: from becomes empty, to becomes full
                                        transition_full_mask <= current_full_mask & ~(1'b1 << from_bottle);
                                        transition_full_mask <= transition_full_mask | (1'b1 << to_bottle);
                                        // Amount stays same (just moving liquid)
                                        transition_amount <= current_amount;
                                        trans_state <= TRANS_CHECK;
                                    end else begin
                                        to_bottle <= to_bottle + 4'd1;
                                    end
                                end else begin
                                    to_bottle <= to_bottle + 4'd1;
                                end
                            end else begin
                                from_bottle <= from_bottle + 4'd1;
                                to_bottle <= 4'd0;
                            end
                        end else begin
                            // Done all transitions
                            trans_state <= TRANS_DONE;
                        end
                    end

                    TRANS_CHECK: begin
                        // Check if new state is within limits and not visited
                        // State is valid if amount <= MAX_VOLUME*NUM_BOTTLES (16*4=64)
                        if (transition_amount <= 8'd64) begin
                            // Calculate visited index: full_mask * 256 + amount
                            visited_idx <= {transition_full_mask, transition_amount[7:0]};
                            state_found <= 1'b0;
                            // Check visited in next cycle
                        end else begin
                            // Invalid state, continue transition
                            if (trans_state == TRANS_FILL) begin
                                bottle_idx <= bottle_idx + 4'd1;
                                trans_state <= TRANS_FILL;
                            end else if (trans_state == TRANS_EMPTY) begin
                                bottle_idx <= bottle_idx + 4'd1;
                                trans_state <= TRANS_EMPTY;
                            end else if (trans_state == TRANS_TRANSFER) begin
                                to_bottle <= to_bottle + 4'd1;
                                trans_state <= TRANS_TRANSFER;
                            end
                        end
                        // Handle visited check separately
                    end

                    TRANS_ENQUEUE: begin
                        // Add new state to queue
                        if (queue_count < 8'd255) begin
                            new_state <= {transition_full_mask, transition_amount};
                            queue[queue_tail] <= {transition_full_mask, transition_amount};
                            parent[queue_tail] <= queue_head;
                            visited[visited_idx] <= 1'b1;
                            queue_tail <= queue_tail + 8'd1;
                            queue_count <= queue_count + 8'd1;
                        end
                        // Return to appropriate transition state
                        if (trans_state == TRANS_FILL) begin
                            bottle_idx <= bottle_idx + 4'd1;
                            trans_state <= TRANS_FILL;
                        end else if (trans_state == TRANS_EMPTY) begin
                            bottle_idx <= bottle_idx + 4'd1;
                            trans_state <= TRANS_EMPTY;
                        end else if (trans_state == TRANS_TRANSFER) begin
                            to_bottle <= to_bottle + 4'd1;
                            trans_state <= TRANS_TRANSFER;
                        end
                    end

                    TRANS_DONE: begin
                        // Finished processing current state
                        trans_state <= TRANS_IDLE;
                    end
                endcase
                // Second part: handle visited check
                if (trans_state == TRANS_CHECK && state_found == 1'b0) begin
                    // Check visited flag
                    if (!visited[visited_idx]) begin
                        trans_state <= TRANS_ENQUEUE;
                    end else begin
                        // Already visited, continue transition
                        if (trans_state == TRANS_FILL) begin
                            bottle_idx <= bottle_idx + 4'd1;
                            trans_state <= TRANS_FILL;
                        end else if (trans_state == TRANS_EMPTY) begin
                            bottle_idx <= bottle_idx + 4'd1;
                            trans_state <= TRANS_EMPTY;
                        end else if (trans_state == TRANS_TRANSFER) begin
                            to_bottle <= to_bottle + 4'd1;
                            trans_state <= TRANS_TRANSFER;
                        end
                    end
                end
            end
        end
    end

    // Combinational logic for next state
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_BFS;
            end
            INIT_BFS: begin
                // After init, load first state
                if (queue_count > 8'd0) begin
                    current_state = queue[queue_head];
                    current_full_mask = queue[queue_head][11:8];
                    current_amount = queue[queue_head][7:0];
                    next_state = PROCESS;
                end else begin
                    next_state = SET_RESULT;
                end
            end
            PROCESS: begin
                // Wait for transition FSM to complete
                if (trans_state == TRANS_DONE) begin
                    next_state = CHECK_MATCH;
                end
            end
            CHECK_MATCH: begin
                // Logic handled in sequential block
            end
            SET_RESULT: begin
                next_state = SET_DONE;
            end
            SET_DONE: begin
                next_state = RESET_OUT;
            end
            RESET_OUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule