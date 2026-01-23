module score_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [2:0] index_in,
    input input_valid,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter IDLE = 3'b000;
    parameter LOAD = 3'b001;
    parameter SORTING = 3'b010;
    parameter CALCULATING = 3'b011;
    parameter FINISHED = 3'b100;

    // Internal Registers and Wires
    reg [7:0] arr [0:N-1]; // Array to store inputs
    reg [2:0] current_state, next_state;
    reg [2:0] i, j; // Loop counters
    reg [7:0] temp_swap; // Temporary register for swapping
    reg swap_needed;
    
    // Calculation specific registers
    reg [31:0] weighted_sum;
    reg [3:0] calc_idx; // Can go up to 8
    reg [31:0] weight_val; // Weight to multiply

    // State Transition and Datapath Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            // Reset array content is not strictly necessary but good practice
            // We will clear 'done' and 'result'
        end else begin
            current_state <= next_state;
            
            // Sequential Logic per state
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize indices for loading if needed, 
                        // but LOAD state handles specific logic
                    end
                end

                LOAD: begin
                    // Data loading happens combinationaly or on specific triggers.
                    // Here we assume the external logic holds data valid while in LOAD state
                    // or we latch it when valid is high.
                    if (input_valid) begin
                        arr[index_in] <= data_in;
                    end
                end

                SORTING: begin
                    // Bubble Sort Logic
                    // Outer loop (j) controls number of passes
                    // Inner loop (i) compares adjacent elements
                    // To make it efficient in hardware, we execute one comparison/swa per cycle
                    
                    if (i < N - 1 - j) begin
                        if (arr[i] > arr[i+1]) begin
                            // Swap
                            arr[i] <= arr[i+1];
                            arr[i+1] <= arr[i];
                        end
                        i <= i + 1;
                    end else begin
                        // End of inner loop
                        i <= 0;
                        j <= j + 1;
                    end
                end

                CALCULATING: begin
                    // result = sum(a[i] * (i+2)) - a[n-1]
                    // Weight starts at 2 for index 0
                    // We accumulate into result register
                    
                    if (calc_idx < N) begin
                        // Multiply current element by weight and add
                        result <= result + (arr[calc_idx] * weight_val);
                        calc_idx <= calc_idx + 1;
                        weight_val <= weight_val + 1; // Increment weight
                    end 
                end

                FINISHED: begin
                    // Subtract the largest element (which is now at index N-1)
                    // Note: result currently holds sum(a[i]*(i+2)). We need to subtract a[N-1].
                    // If N=1, the formula is just a[0].
                    if (N > 1) begin
                        // Ensure we subtract only once. 
                        // The state transition to FINISHED happens once calculation loop finishes.
                        result <= result - arr[N-1];
                    end
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                // Heuristic: If start is deasserted, we assume loading is done.
                // Alternatively, could use a 'load_done' input, but we follow the prompt's implicit flow.
                if (!start) next_state = SORTING;
            end
            
            SORTING: begin
                // Check termination condition: j >= N-1
                // If j reaches N-1, sorting is complete
                if (j >= N - 1) next_state = CALCULATING;
            end
            
            CALCULATING: begin
                // Loop runs N times (indices 0 to N-1)
                // We check if we have processed the last element.
                // Since calc_idx increments at end of cycle, check if calc_idx == N (meaning we did N iterations)
                if (calc_idx >= N) next_state = FINISHED;
            end
            
            FINISHED: begin
                // Wait for reset or restart. 
                // To allow restart, we might go back to IDLE after some time or wait for start to go low.
                // Let's go to IDLE if start goes low to allow a new cycle.
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Helper Logic for Sorting and Calculation loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            calc_idx <= 0;
            weight_val <= 2;
        end else begin
            // Reset counters when entering relevant states
            if (current_state == IDLE && start) begin
                // Initialize counters for next states
                // j for sorting loop needs to be 0
                j <= 0;
                i <= 0;
                calc_idx <= 0;
                weight_val <= 2;
                result <= 0; // Clear result accumulator
            end
            
            // Reset result in CALCULATING if just entering (handled by above reset on start, 
            // but strictly we might want to clear it specifically if we re-enter)
            // However, the prompt implies sequential flow IDLE -> ... -> CALCULATING.
            // We clear result inside CALCULATING state logic if calc_idx==0 to be safe against restarts,
            // but typically the IDLE->LOAD transition sets up the environment.
            
            if (current_state == CALCULATING && calc_idx == 0) begin
                 result <= 0; // Ensure clean start for accumulation
            end
        end
    end

endmodule
