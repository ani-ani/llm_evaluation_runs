module fluttershy_scheduling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [M-1:0][31:0] config_p_in,
    input wire [M-1:0][31:0] config_r_in,
    input wire [4:0] customer_type_in,
    input wire [31:0] customer_time_in,
    input wire in_valid,
    output logic in_ready,
    output logic [31:0] result,
    output logic result_valid
);

    // Parameters
    parameter int N = 16;      // Max Customers
    parameter int M = 4;       // Max Clothing Types
    localparam int NONE = M;   // Index for 'no clothing' state
    localparam int NUM_STATES = M + 1;
    localparam logic [31:0] INF = 32'hFFFF_FFFF;

    // State Enumeration
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    // Internal Registers and Wires
    state_t current_state, next_state;
    logic [31:0] dp_state_reg [0:NUM_STATES-1];
    logic [31:0] dp_state_next [0:NUM_STATES-1];
    logic [31:0] served_cnt_reg, served_cnt_next;
    logic [4:0] current_cust_type_reg, current_cust_type_next;
    logic [31:0] current_cust_time_reg, current_cust_time_next;
    logic in_ready_reg, in_ready_next;
    logic result_valid_reg, result_valid_next;
    logic [31:0] result_reg, result_next;

    // Internal control signals
    logic processing_en;
    logic is_final_customer;
    logic [31:0] min_time;
    logic valid_transition_found;

    // Sequential Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            in_ready_reg <= 1'b0;
            result_valid_reg <= 1'b0;
            served_cnt_reg <= 0;
            result_reg <= 0;
            current_cust_type_reg <= 0;
            current_cust_time_reg <= 0;
            for (int i = 0; i < NUM_STATES; i++) dp_state_reg[i] <= INF;
        end else begin
            current_state <= next_state;
            in_ready_reg <= in_ready_next;
            result_valid_reg <= result_valid_next;
            served_cnt_reg <= served_cnt_next;
            result_reg <= result_next;
            current_cust_type_reg <= current_cust_type_next;
            current_cust_time_reg <= current_cust_time_next;
            // Update DP state array
            if (processing_en) begin
                dp_state_reg <= dp_state_next;
            end else if (start) begin
                // Initialize on start
                for (int i = 0; i < NUM_STATES; i++) dp_state_reg[i] <= INF;
                dp_state_reg[NONE] <= 0;
            end
        end
    end

    // Combinational Logic - Next State & Outputs
    always_comb begin
        // Default assignments
        next_state = current_state;
        in_ready_next = in_ready_reg;
        result_valid_next = result_valid_reg;
        result_next = result_reg;
        served_cnt_next = served_cnt_reg;
        current_cust_type_next = current_cust_type_reg;
        current_cust_time_next = current_cust_time_reg;
        dp_state_next = dp_state_reg;
        processing_en = 1'b0;
        is_final_customer = 1'b0;

        unique case (current_state)
            IDLE: begin
                in_ready_next = 1'b0;
                result_valid_next = 1'b0;
                if (start) begin
                    // Wait for next clock cycle to let initialization happen
                    in_ready_next = 1'b1;
                    // We assume dp_state_reg is initialized by reset/seq logic
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Handshake logic: ready to accept data if we are not waiting for calc latency
                // The prompt says 1 clock cycle for calculation per customer.
                // We can accept a new customer immediately if we process the previous one this cycle.
                // To be safe and simple: We process 'in_valid' in this state.
                // We pipeline the input data and valid flag.
                
                // Let's define the logic:
                // We are in PROCESSING. If we have stored data (from previous cycle), we calculate next state for DP.
                // Wait. The prompt says "Allow 1 clock cycle for calculation".
                // Handshake: in_ready high when ready to accept.
                // Let's assume the pipeline is:
                // Cycle N: Input Valid -> Capture Input -> in_ready low (if backpressure needed) or high (if pipelined).
                // Cycle N+1: Calculate -> Update DP.
                // Prompt says "Wait for in_valid high... Use combinational block to calculate...".
                // This implies we need to decide immediately if we can take the input, then calculate, then update.
                // However, calculating min time over M+1 states takes logic depth. 
                // A simple pipelined approach:
                // 1. Capture input when valid.
                // 2. In next cycle, calculate min time.
                // 3. In next cycle, update.
                // But prompt says "Latency: 1 clock cycle for calculation per customer".
                // This usually means processing one customer takes 1 cycle.
                // Let's try a 2-stage pipeline for processing one customer to ensure timing:
                // Stage 1: Input & Fetch Config.
                // Stage 2: Compute Min Time & Update.
                // However, to meet the handshake requirement efficiently:
                // We accept input when ready. If we accept, we move to a temporary state or latch valid.
                // Let's use a flag 'data_valid_latch' to indicate we have data to process.

                // Logic re-evaluation based on "1 clock cycle" and "Handshake":
                // It is difficult to do full DP update in one cycle if M is large, but M=4 is small.
                // Let's try to do it in one cycle: 
                // Cycle 0: in_valid=1, in_ready=1. Capture input to 'next' registers.
                // Cycle 1: Use 'next' registers to compute. Update DP.
                // This means in_ready must be high in Cycle 0, low in Cycle 1 (or buffered).
                // But the prompt says: "Move to WAIT_FOR_NEXT or stay in PROCESSING depending on handshake."
                // It also says "Latency: 1 clock cycle for calculation per customer".
                // Let's assume the 'in_ready' can toggle. 
                
                // Let's implement the Control Logic:
                logic input_taken;
                input_taken = 1'b0;

                // Check if input is available
                if (in_valid) begin
                    // Latch input for calculation (Pipeline Stage 1 -> Stage 2)
                    current_cust_type_next = customer_type_in;
                    current_cust_time_next = customer_time_in;
                    
                    // Logic to handle "completion". If type is 0 (invalid/end), we are done.
                    if (customer_type_in == 0) begin
                        is_final_customer = 1'b1;
                        next_state = DONE;
                        in_ready_next = 1'b0;
                        result_valid_next = 1'b1;
                        result_next = served_cnt_reg; // Output count of previously served
                    end else begin
                        // We accept the input. 
                        // However, we cannot process it in THIS cycle if we need to calculate DP.
                        // The prompt says "1 clock cycle for calculation". 
                        // Let's create a state to indicate we are calculating.
                        // Or, we can calculate combinationaly now if inputs are ready, but the inputs are just captured?
                        // No, we need to use 'dp_state_reg' which is available now.
                        // The calculation uses: dp_state_reg, P, R, customer_type_in.
                        // 'customer_type_in' is valid on this cycle.
                        // So we CAN calculate combinationaly in this cycle.
                        // Then we update registers at the end of cycle.
                        // BUT, the update to dp_state_reg will be delayed by 1 cycle (clocked).
                        // So if we calculate now, the result is correct.
                        // The only issue is 'in_ready'. 
                        // If we accept input now, and process it, we might be ready for the next one immediately.
                        // But we need to update the DP state.
                        // If the next customer arrives in the same cycle (impossible in synchronous logic usually) or next cycle,
                        // we want to use the *updated* DP state.
                        // Since DP state updates at posedge, we cannot use it for the next customer in the same cycle.
                        // So, we should NOT accept new input immediately after processing one.
                        // We should wait for the DP update to take effect.
                        // The prompt says "Allow 1 clock cycle for calculation".
                        // This implies: 
                        // 1. Cycle: Input Ready. Input Valid. Calculation starts/finishes.
                        // 2. Cycle: Update State. Ready for next?
                        // To be safe and correct:
                        // State PROCESSING:
                        //   if (in_valid && !calculating_latch) begin
                        //      latch input -> calculating_latch = 1; in_ready = 0;
                        //   end
                        //   if (calculating_latch) begin
                        //      perform calc; update dp; 
                        //      if (was_last) -> DONE else -> calculating_latch = 0; in_ready = 1;
                        //   end
                        // Let's refine this.
                    end
                end 
                // Wait, the prompt has a specific flow: 
                // "Use a combinational block to calculate new costs"
                // "Find minimum time"
                // "Update... Increment served counter"
                // This looks like a single-cycle combinational calculation followed by a register update.
                // The issue is the loop "Iterate through all previous states". 
                // For M=4, this is small. 
                // Let's implement the combinational block *outside* the always_comb for state control.
            end

            DONE: begin
                in_ready_next = 1'b0;
                result_valid_next = 1'b1;
                result_next = served_cnt_reg;
            end
        endcase
    end

    // --- Combinational Calculation Block (The Engine) ---
    logic [31:0] calc_dp_next [0:NUM_STATES-1];
    logic [31:0] calc_served_cnt_next;
    logic calc_valid;
    logic [31:0] calc_min_time;
    logic [31:0] time_options [0:NUM_STATES-1]; // Intermediate times for each transition
    logic [31:0] trans_cost;

    always_comb begin
        // Defaults
        calc_dp_next = dp_state_reg; // Keep existing values unless updated
        calc_served_cnt_next = served_cnt_reg;
        calc_valid = 1'b0;

        // Only perform calculation if we are in PROCESSING state and have valid input to process
        // We need a way to know if we are in the processing phase for the current customer.
        // Let's introduce a flag 'process_trigger'.
        // Since the input was latched in 'current_cust_type_reg' in the previous cycle (or same cycle if we can),
        // we need to distinguish between "waiting for input" and "processing latched input".
        
        // Let's use the latched registers 'current_cust_type_reg' etc.
        // If we are in PROCESSING state and 'current_cust_type_reg' is not 0 (and presumably valid), 
        // we perform the calculation.
        // But we need to ensure we don't re-calculate on the same customer.
        // We can use a 'processed_flag' or rely on the fact that 'current_cust_type_reg' only updates when in_valid is high.
        
        // Revised Pipeline Strategy for State PROCESSING:
        // 1. Wait for in_valid. When high, capture inputs to 'current_cust...' registers. 
        //    Set 'input_pending' flag. Set in_ready low.
        // 2. In next cycle (or same if logic allows), if 'input_pending', do calc, update DP, clear 'input_pending'.
        //    Set in_ready high.
        
        // Let's implement this control explicitly in the combinational block.
        
        logic start_processing;
        logic finish_processing;
        
        start_processing = (current_state == PROCESSING) && in_valid && in_ready_reg;
        
        // Wait, the seq logic handles 'in_ready_next'.
        // Let's create a temporary state or use the 'current_cust_type_reg' as the indicator.
        // If 'current_cust_type_reg' != 0 and 'current_cust_type_reg' is valid (e.g., we just loaded it), then calc.
        // We need a 'valid_latch' to trigger calculation exactly once per customer.
        
        // Let's assume a helper signal 'process_latch' is set in seq logic.
        // But we want to keep logic together.
        
        // Alternative: The prompt asks for a "combinational block". 
        // Let's define inputs to this block: 
        //   dp_state (current), P, R, customer_type, customer_time.
        //   trigger (valid signal).
        // Output: new_dp_state, new_served_cnt, ready_for_next.
        
        // Let's look at the timing constraints again.
        // If we have 1 cycle latency, and we stream customers:
        // Cycle 0: Input A valid. in_ready=1. Process A.
        // Cycle 1: Update DP for A. Input B valid. in_ready=1. Process B.
        // This implies B uses the OLD DP state (before A updated it) ?
        // No, "Update... Find minimum". This updates the state for the *current* customer.
        // If we process B in Cycle 1, we should use the state updated by A (which finished at end of Cycle 0).
        // So B needs to wait until Cycle 1 to be processed if A was processed in Cycle 0.
        // So Cycle 0: Process A. 
        // Cycle 1: A updates. B comes in. Process B? No, B comes in *while* A is processing?
        // If A takes 1 cycle, A is done at the end of Cycle 0. 
        // So B can be processed in Cycle 1.
        // This means we can accept a new customer every cycle, provided we have the logic speed.
        // BUT we need to update the DP array. 
        // The DP array is updated at the end of the cycle. 
        // If we use `dp_state_reg` for calculation in the cycle, we are using the state from the PREVIOUS customer.
        // 
        // Scenario: 
        // Start: dp_state[None] = 0. served=0.
        // Customer 1 arrives. 
        // Cycle 1: Calc using dp_state (None=0). Find time. Check against arrival time. Update dp_state_next (Type 1).
        // Cycle 2: dp_state_reg updates. 
        // Customer 2 arrives (could arrive in Cycle 1 or 2). 
        // If Customer 2 arrives in Cycle 2: We use updated dp_state. Correct.
        // If Customer 2 arrives in Cycle 1: We use old dp_state. Incorrect if we want sequential processing.
        // However, the problem says "processes customers one by one in arrival order".
        // If the external source sends them rapidly (every cycle), we need to pipeline correctly.
        // 
        // Let's assume the following Pipeline for the PROCESSING state:
        // We have a 'busy' flag indicating a customer is being processed.
        // We accept a customer only when 'busy' is low.
        // When we accept (in_valid & in_ready), we latch data, set 'busy' high.
        // In the same cycle (or next), we calculate the result for the latched customer using the *current* dp_state_reg.
        // At the end of the cycle, we update dp_state_next.
        // In the next cycle, 'busy' goes low (or we wait for update), and we are ready for the next customer.
        // 
        // So, the logic flow in PROCESSING state:
        // If !busy: in_ready = 1. If in_valid: latch input, set busy = 1, in_ready = 0. Trigger Calculation.
        // If busy: in_ready = 0. Perform Calculation (using latched input and dp_state_reg). Update dp_state_next. Clear busy.
        // 
        // To implement this in the existing code structure:
        // We need a 'busy' register.
        
        // Let's define the helper logic inside the combinational block.
        // We will assume 'current_cust_type_reg' holds the data of the customer we are CURRENTLY processing.
        // 'current_cust_time_reg' holds the time.
        // If 'current_cust_type_reg' is valid and we haven't processed it yet (need a flag), we process.
        
        // Let's add a 'processing_customer' flag in the seq logic.
    end

    // Re-structuring the module to handle the pipeline cleanly.
    // We need a flag to indicate we have captured a customer and are processing it.
    logic processing_customer_latch;
    logic processing_customer_latch_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_customer_latch <= 1'b0;
        end else begin
            processing_customer_latch <= processing_customer_latch_next;
        end
    end

    always_comb begin
        // Default
        processing_customer_latch_next = processing_customer_latch;
        
        // The core combinational processing logic
        // Inputs: dp_state_reg, config_p_in, config_r_in, customer_type_reg, customer_time_reg
        // Outputs: dp_state_next, served_cnt_next
        
        // Initialize dp_state_next to hold current value unless updated
        dp_state_next = dp_state_reg;
        served_cnt_next = served_cnt_reg;
        
        logic [31:0] best_time;
        logic [31:0] cand_time;
        logic can_serve;
        
        // Default state transitions and handshake control
        in_ready_next = 1'b0;
        result_valid_next = 1'b0;
        result_next = result_reg;
        next_state = current_state;
        
        // Handling State Specific Logic
        case (current_state)
            IDLE: begin
                if (start) begin
                    // Wait one cycle for reset/initialization to propagate (if not already handled)
                    // Actually, reset logic handles initialization. 
                    // We can go to PROCESSING and be ready immediately.
                    next_state = PROCESSING;
                    in_ready_next = 1'b1;
                end
            end

            PROCESSING: begin
                // If we are NOT currently holding a customer to process, we are ready for input
                if (!processing_customer_latch) begin
                    in_ready_next = 1'b1;
                    if (in_valid) begin
                        // Capture Input
                        // Check for End of Stream (type 0)
                        if (customer_type_in == 0) begin
                            // Just finish
                            next_state = DONE;
                            result_valid_next = 1'b1;
                            result_next = served_cnt_reg;
                            in_ready_next = 1'b0;
                        end else begin
                            // Latch the customer data for processing next cycle
                            // We set the latch flag. 
                            processing_customer_latch_next = 1'b1;
                            // We also need to store the data, or assume it's available on next cycle? 
                            // Input signals are valid for 1 cycle. 
                            // We must latch them now if we want to use them next cycle.
                            // But the code above latches into 'current_cust_type_reg' in the seq block.
                            // So we need to trigger that latch.
                            // We can do this by enabling the write to those registers.
                            // Since the seq block always updates them, we need to provide values.
                            // So we need to assign current_cust_type_next = customer_type_in here.
                            current_cust_type_next = customer_type_in;
                            current_cust_time_next = customer_time_in;
                            
                            in_ready_next = 1'b0; // Stall input while processing
                        end
                    end
                end 
                else begin
                    // We have a customer latched (current_cust_type_reg is valid).
                    // Perform Calculation and Update DP.
                    
                    // 1. Calculate Best Time
                    best_time = INF;
                    can_serve = 1'b0;
                    
                    // Iterate through all states j (0 to M)
                    for (int j = 0; j < NUM_STATES; j++) begin
                        if (dp_state_reg[j] != INF) begin // Only consider reachable states
                            // Calculate transition cost
                            if (j == current_cust_type_reg) begin
                                // Case 1: Already wearing correct clothes
                                cand_time = dp_state_reg[j];
                            end else if (j == NONE) begin
                                // Case 2: From None to C
                                cand_time = dp_state_reg[NONE] + config_p_in[current_cust_type_reg];
                            end else begin
                                // Case 3: From j to C (Remove j, Put C)
                                cand_time = dp_state_reg[j] + config_r_in[j] + config_p_in[current_cust_type_reg];
                            end
                            
                            // Check validity (must be ready before arrival)
                            if (cand_time <= current_cust_time_reg) begin
                                if (cand_time < best_time) begin
                                    best_time = cand_time;
                                end
                            end
                        end
                    end
                    
                    // 2. Update State
                    if (best_time != INF) begin
                        // Valid transition found
                        if (best_time < dp_state_reg[current_cust_type_reg]) begin
                            dp_state_next[current_cust_type_reg] = best_time;
                        end
                        served_cnt_next = served_cnt_reg + 1;
                    end
                    
                    // 3. Cleanup
                    processing_customer_latch_next = 1'b0; // Done with this customer
                    
                    // 4. Check if we can accept next customer immediately?
                    // Yes, if we are still in PROCESSING state and we are ready.
                    // We just set latch to 0. So in_ready should become 1 in this cycle (combinational output).
                    // However, we are inside the combinational block logic for 'PROCESSING'.
                    // We need to set 'in_ready_next' correctly.
                    in_ready_next = 1'b1;
                    
                    // Edge case: What if next customer arrives NOW? 
                    // The input signals in_valid/customer_type_in are valid now (if external source pushes).
                    // Since we just finished processing, we can check in_valid NOW to latch the next one.
                    // But wait, we are in the combinational block. 
                    // The 'in_ready_next' is set to 1. This allows the external logic to drive data.
                    // But we can't capture it in the same cycle unless we add complex logic.
                    // Standard practice: 
                    // Cycle 0: Process A. in_ready=0.
                    // Cycle 1: Update DP. in_ready=1. B arrives. Capture B.
                    // Cycle 2: Process B.
                    // 
                    // To optimize throughput (one per cycle):
                    // Cycle 0: A arrives. in_ready=1. Capture A.
                    // Cycle 1: Process A (calc). Update DP. in_ready=1. B arrives. Capture B.
                    // Cycle 2: Process B. Update DP.
                    // This requires 2 registers: 'pending_A', 'pending_B'.
                    // Since we only have one latch ('processing_customer_latch'), we can accept B only if we are done with A.
                    // In the code above, we set `processing_customer_latch_next = 0`.
                    // So for the next cycle, `processing_customer_latch` will be 0, and we can accept B.
                    // However, B arrives *in this cycle* (Cycle 1). 
                    // To capture B in Cycle 1, we need `in_ready_next` to be 1.
                    // We set it to 1. 
                    // But we must also latched B's data. 
                    // `current_cust_type_next` is currently driven by the calculation logic (or defaults).
                    // We need to check `in_valid` here:
                    if (in_valid) begin
                        // B arrived while we finished A.
                        // We must capture B's data to process in Cycle 2.
                        // Note: We are still in the always_comb block. We can check `in_valid`.
                        if (customer_type_in == 0) begin
                            // End of stream detected during pipelining
                            next_state = DONE;
                            result_valid_next = 1'b1;
                            result_next = served_cnt_next; // Use the incremented count
                            in_ready_next = 1'b0;
                        end else begin
                            // Capture B
                            current_cust_type_next = customer_type_in;
                            current_cust_time_next = customer_time_in;
                            processing_customer_latch_next = 1'b1; // We now have B pending
                            in_ready_next = 1'b0; // Don't accept C yet
                        end
                    end else begin
                        // No B arrived. We go to idle/wait state (ready for input)
                        // in_ready_next is already 1.
                        // processing_customer_latch_next is 0.
                    end
                end
            end

            DONE: begin
                in_ready_next = 1'b0;
                result_valid_next = 1'b1;
                result_next = served_cnt_reg;
            end
        endcase
    end

    // Output assignments
    assign in_ready = in_ready_reg;
    assign result_valid = result_valid_reg;
    assign result = result_reg;

endmodule
