module max_sum_dp(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // Parameters for States
    parameter IDLE = 3'b000;
    parameter INIT = 3'b001;
    parameter PROCESSING = 3'b010;
    parameter DONE = 3'b011;

    // Registers for State Machine
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Registers for iteration index
    reg [4:0] i; // Index from 0 to 16 (5 bits)
    
    // LUT: dp array [0:16] of 16-bit values
    reg [15:0] dp [0:16];

    // Intermediate calculation registers (pipelined for timing)
    reg [15:0] sum_part;
    reg [15:0] term2, term3, term4, term5;
    
    // Combinational logic for division/multiplication by reciprocal (shifts)
    // Since N <= 16, integer division is simple.
    wire [4:0] i_div_2 = i >> 1;
    wire [4:0] i_div_3 = i / 3; // Integer division requires a divider, but with small logic or constant division it infers logic
    wire [4:0] i_div_4 = i >> 2;
    wire [4:0] i_div_5 = i / 5;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                // Check if n is 0 or 1, skip processing if so
                if (n < 2)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            PROCESSING: begin
                // Process until i > n. 
                // We start with i=2. If i <= n, we calc. 
                // When i becomes n+1, we are done.
                if (i > n)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                // Stay in DONE until reset or start low (depending on spec, usually wait for reset or new start)
                // Assuming return to IDLE when start goes low to allow re-trigger
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
            i <= 5'd0;
            sum_part <= 16'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    // Initialize LUT base cases
                    dp[0] <= 16'd0;
                    dp[1] <= 16'd1;
                    i <= 5'd2; // Start calculation from index 2
                    // Pre-fetch terms for i=2 if needed, but here we just set i
                    if (n < 2) begin
                        result <= dp[n]; // Result is already 0 or 1 (though dp[0/1] just written, read happens next cycle in hardware or handles it)
                        // Actually, if n<2, we are going to DONE state. 
                        // We need to output dp[n] immediately if n is 0 or 1.
                        if (n == 0) result <= 16'd0;
                        else if (n == 1) result <= 16'd1;
                    end
                end

                PROCESSING: begin
                    if (i <= n) begin
                        // Calculate sum_part = dp[i/2] + dp[i/3] + dp[i/4] + dp[i/5]
                        // We use the values stored in dp array.
                        // Note: Read operations are combinational from the array, but we are updating dp[i] here.
                        // Since we iterate sequentially, dp[k] for k < i is valid.
                        
                        term2 <= dp[i_div_2];
                        term3 <= dp[i_div_3];
                        term4 <= dp[i_div_4];
                        term5 <= dp[i_div_5];
                        
                        // Accumulate next cycle to balance pipeline or combinational
                        // To fit latency requirement, we can do this calculation in one state or split.
                        // Let's use combinational logic for the sum to avoid extra states, 
                        // but strictly following the "2 cycles per index" requirement suggests a pipeline.
                        // However, standard Verilog infers logic for this.
                        // Let's add 1 cycle delay for calculation to be safe.
                        
                        // Wait, the spec asks for states IDLE, INIT, PROCESSING, DONE. 
                        // It says "In processing state, it iterates".
                        // We will use the PROCESSING state to perform the read/calc and write back in the same cycle or next.
                        // To keep it simple and correct:
                        // Step 1: Read neighbors. 
                        // Step 2: Add and Max. 
                        // Step 3: Store.
                        // Since N=16 is small, we can actually unroll this or do it in fewer states.
                        // Let's assume 2 clock cycles per index as requested.
                        // Cycle A: Read neighbors. Cycle B: Sum, Max, Write.
                        // We need a sub-state or just use the counter i to track phases.
                        
                        // Implementation choice: Since we need approx 50-60 cycles for 16 items, 2 cycles/item is fine.
                        // Let's use a phase toggle.
                    end
                    // Note: We need a local counter for phases since 'i' only increments when done.
                end

                DONE: begin
                    done <= 1'b1;
                    if (n >= 2) begin // Only update result if it was computed (or was valid)
                        result <= dp[n];
                    end
                    // For n=0,1, result was set in INIT
                end
            endcase
        end
    end

    // Helper logic for the 2-cycle processing logic
    reg process_phase; // 0: read/calc, 1: store
    
    // Update process_phase inside the always block above or separate?
    // Let's integrate it into the main FSM block for clarity and proper reset.
    // Actually, I need to rewrite the PROCESSING block to handle the 2-cycle requirement explicitly.

    // Revised Datapath for Process State
    // We need to separate the PROCESSING state into sub-steps or handle it with a flag.
    // Given the strict state list (IDLE, INIT, PROCESSING, DONE), we must use variables inside PROCESSING.

    // Reset logic for the refined FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
            i <= 5'd2;
            process_phase <= 1'b0;
            // Clear dp array not strictly necessary but good practice, omitting to save gates
        end else begin
            done <= 1'b0; // Default done low unless in DONE state
            
            case (current_state)
                IDLE: begin
                    // Wait for start
                    i <= 5'd2;
                    process_phase <= 1'b0;
                end
                
                INIT: begin
                    dp[0] <= 16'd0;
                    dp[1] <= 16'd1;
                    i <= 5'd2;
                    process_phase <= 1'b0;
                    // Pre-calc n<2 result
                    if (n == 0) result <= 16'd0;
                    else if (n == 1) result <= 16'd1;
                end

                PROCESSING: begin
                    if (!process_phase) begin
                        // Phase 0: Read neighbors and accumulate
                        // We need to calculate sum = dp[i/2] + dp[i/3] + dp[i/4] + dp[i/5]
                        // Since dp is a register array, reading takes the current values.
                        // We perform the addition logic here. 
                        // Since combinational adders take logic levels, we register the partial sum if needed,
                        // but for N=16, we can probably fit the full adder in one cycle if the clock is slow.
                        // However, to be robust (and meet the "2 cycles per index" hint), let's assume 1 cycle for read/sum.
                        
                        sum_part <= dp[i>>1] + dp[i/3] + dp[i>>2] + dp[i/5];
                        process_phase <= 1'b1; // Go to phase 1
                    end else begin
                        // Phase 1: Compute Max and Store
                        if (sum_part > i) 
                            dp[i] <= sum_part;
                        else
                            dp[i] <= i;
                        
                        // Increment index
                        i <= i + 1;
                        process_phase <= 1'b0; // Back to phase 0 for next index
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Output result
                    result <= dp[n];
                end
            endcase
        end
    end

endmodule
