module nudgemon_optimal_xp(
    input clk,
    input rst_n,
    input start,
    input [5:0] num_catches,
    input [5:0] num_families,
    input [31:0] catch_times [0:7],
    input [7:0] catch_family [0:7],
    input [3:0] family_evolution_cost [0:7],
    input [3:0] family_chain_length [0:7],
    output reg [31:0] max_xp,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam PARSE_INPUT = 3'b001;
    localparam EVALUATE_WINDOWS = 3'b010;
    localparam COMPUTE_XP = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal registers for storage
    reg [31:0] stored_catch_times [0:7];
    reg [7:0] stored_catch_family [0:7];
    reg [3:0] stored_evolution_cost [0:7];
    reg [3:0] stored_chain_length [0:7];
    
    // Window registers
    reg [31:0] window_start_times [0:3];
    reg [1:0] current_window;
    
    // XP calculation registers
    reg [31:0] temp_catch_xp;
    reg [31:0] temp_evolution_xp;
    reg [31:0] temp_total_xp;
    reg [31:0] best_xp;
    
    // Counters and indices
    reg [3:0] i; // loop index for catches
    reg [3:0] j; // loop index for families
    reg [3:0] k; // loop index for window evaluation
    reg [3:0] m; // loop index for catch counting in window
    
    // Intermediate computation registers
    reg [31:0] candies;
    reg [31:0] evolutions;
    reg [31:0] catch_count;
    reg [31:0] window_end;
    reg [31:0] current_catch_time;
    reg [31:0] current_catch_family_id;
    reg [31:0] current_cost;
    
    // Fixed point constants (Q16.16)
    localparam [31:0] XP_PER_CATCH = 32'h00640000;      // 100
    localparam [31:0] XP_PER_CATCH_BLESSED = 32'h00C80000; // 200
    localparam [31:0] XP_PER_EVO = 32'h01F40000;        // 500
    localparam [31:0] XP_PER_EVO_BLESSED = 32'h03E80000; // 1000
    localparam [31:0] BLESSED_DURATION = 32'h07080000;  // 1800
    localparam [31:0] CANDIES_PER_CATCH = 32'h00030000; // 3
    localparam [31:0] ONE = 32'h00010000;               // 1 in Q16.16
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            max_xp <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            m <= 0;
            current_window <= 0;
            temp_catch_xp <= 0;
            temp_evolution_xp <= 0;
            temp_total_xp <= 0;
            best_xp <= 0;
            candies <= 0;
            evolutions <= 0;
            catch_count <= 0;
            window_end <= 0;
            current_catch_time <= 0;
            current_catch_family_id <= 0;
            current_cost <= 0;
            // Clear arrays
            // Note: In synthesis, arrays should be initialized or cleared explicitly
            // but Verilog typically doesn't allow full array assignment in always block easily.
            // We manage them element by element if needed, or assume initial 0.
            // Here we reset indices and flags.
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    m <= 0;
                    best_xp <= 0;
                    if (start) begin
                        // Start parsing
                        // Initialize storage if needed (already cleared by reset logic implicitly if arrays are zero-initialized)
                        // We need to handle array clearing properly since standard reset block doesn't support full array assignment in all tools
                        // Let's rely on the PARSE_INPUT state to overwrite as we go, or reset index.
                    end
                end
                
                PARSE_INPUT: begin
                    // Store inputs into internal arrays
                    // 1. Store Family Data
                    if (j < num_families && j < 8) begin
                        stored_evolution_cost[j] <= family_evolution_cost[j];
                        stored_chain_length[j] <= family_chain_length[j];
                        j <= j + 1;
                    end
                    // 2. Store Catch Data
                    else if (i < num_catches && i < 8) begin
                        stored_catch_times[i] <= catch_times[i];
                        stored_catch_family[i] <= catch_family[i];
                        i <= i + 1;
                    end
                    // 3. Generate Candidate Windows
                    else if (num_catches > 0) begin
                        // Window 0: First catch
                        window_start_times[0] <= stored_catch_times[0];
                        // Window 1: Catch at num_catches/4 (rounded down index)
                        window_start_times[1] <= stored_catch_times[num_catches[5:2]]; // Divide by 4
                        // Window 2: Catch at num_catches/2
                        window_start_times[2] <= stored_catch_times[num_catches[5:1]]; // Divide by 2
                        // Window 3: Catch at 3*num_catches/4
                        // 3*num_catches/4 = (3 * num_catches) / 4. 
                        // Index calculation: (num_catches * 3) >> 2
                        window_start_times[3] <= stored_catch_times[((num_catches * 3) >> 2)];
                    end
                end
                
                EVALUATE_WINDOWS: begin
                    // Reset window-specific accumulators
                    catch_count <= 0;
                    candies <= 0;
                    // We need to reset the family usage for the window, 
                    // but simplified problem says "All evolutions in a family cost the same (use first cost value)"
                    // and "Maximum evolutions = floor(candies / family_evolution_cost)".
                    // Wait, the problem says "XP from evolutions = 500 * evolutions".
                    // It doesn't explicitly say we sum evolutions across families or if it's a global pool.
                    // "Maximum evolutions = floor(candies / family_evolution_cost)". 
                    // Implies we use the FIRST family's cost? Or are there multiple families?
                    // "Maximum 8 families". 
                    // The simplified rule "All evolutions in a family cost the same (use first cost value)"
                    // implies we might treat the cost as uniform for calculation? 
                    // Or we sum candies and divide by the average cost? 
                    // Given the constraint "Simplified: All evolutions in a family cost the same (use first cost value)"
                    // and the fact we have an array of costs, I will sum candies first, 
                    // then calculate evolutions for each family separately if we have specific family candies?
                    // But the problem says "Candies = 3 * count" (global count?).
                    // Then "Maximum evolutions = floor(candies / family_evolution_cost)". 
                    // If we have multiple families, which cost do we use?
                    // "Use first cost value". I will interpret this as: Sum candies, 
                    // divide by family_evolution_cost[0] for the calculation. 
                    // Or perhaps the prompt implies we assume one family for the benchmark? 
                    // Let's look at the loop structure. 
                    // We need to iterate through catches in the window to count them.
                    
                    if (m < num_catches && m < 8) begin
                        // Check if catch m is in current window
                        if (stored_catch_times[m] >= window_start_times[current_window] && 
                            stored_catch_times[m] < (window_start_times[current_window] + BLESSED_DURATION)) begin
                            catch_count <= catch_count + ONE;
                            candies <= candies + CANDIES_PER_CATCH;
                        end
                        m <= m + 1;
                    end else if (m == num_catches || m == 8) begin
                        // Done counting for this window, transition to compute
                        // Check if we need to reset m for next window (handled in compute state or here)
                        // Transition to compute state specifically for this window
                        m <= 0; // Reset for next window or next usage
                        // Jump to compute state implicitly? No, we need a separate state or handle here.
                        // The instruction says "Use state machine with states... EVALUATE_WINDOWS, COMPUTE_XP".
                        // So we will transition to COMPUTE_XP state.
                    end
                end
                
                COMPUTE_XP: begin
                    // Calculate XP for the current window
                    // 1. Catch XP
                    // 2. Evolution XP
                    // 3. Compare with best_xp
                    
                    // Logic for evolution calculation:
                    // "Maximum evolutions = floor(candies / family_evolution_cost)".
                    // "Use first cost value" -> I'll use family_evolution_cost[0].
                    // Note: candies is in Q16.16, cost is 4-bit integer (0-15).
                    // We need to convert cost to Q16.16 (cost << 16).
                    // Evolutions = candies / (cost << 16).
                    // Since cost is integer, and candies is Q16.16, the division result is integer (but represented in Q16.16).
                    // Example: Candies = 6 (0x00060000), Cost = 2. Evolutions = 3 (0x00030000).
                    // `evolutions = candies >> 16;` then `evolutions = evolutions / cost;`.
                    // Let's do it in registers.
                    
                    if (stored_evolution_cost[0] != 0) begin
                        // Integer division: (candies >> 16) / cost
                        // Note: In Verilog, integer division truncates.
                        evolutions <= ((candies >> 16) / stored_evolution_cost[0]) << 16;
                    end else begin
                        evolutions <= 0;
                    end
                    
                    // Calculate Total XP
                    // XP = (count * XP_PER_CATCH_BLESSED) + (evolutions * XP_PER_EVO_BLESSED)
                    // Note: catch_count is already Q16.16 (incremented by ONE).
                    // evolutions is Q16.16.
                    // Multiplication of Q16.16 * Q16.16 = Q32.32. We need to truncate/shift back to Q16.16.
                    
                    temp_catch_xp <= (catch_count * XP_PER_CATCH_BLESSED) >> 16;
                    temp_evolution_xp <= (evolutions * XP_PER_EVO_BLESSED) >> 16;
                    
                    // Sum and Compare
                    temp_total_xp <= ((catch_count * XP_PER_CATCH_BLESSED) >> 16) + ((evolutions * XP_PER_EVO_BLESSED) >> 16);
                    
                    if (temp_total_xp > best_xp) begin
                        best_xp <= temp_total_xp;
                    end
                    
                    // Prepare for next window or finish
                    if (current_window < 3) begin
                        current_window <= current_window + 1;
                        // Need to go back to EVALUATE_WINDOWS to count catches for next window
                        // Or we can handle the loop here if we manage indices carefully.
                        // Given state structure, going back to EVALUATE_WINDOWS is cleaner.
                    end else begin
                        // Done all windows
                        max_xp <= best_xp;
                        done <= 1;
                        // Go to DONE state
                    end
                end
                
                DONE: begin
                    // Wait for start to go low or next command
                    // Optional: if (!start) done <= 0;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PARSE_INPUT : IDLE;
            
            PARSE_INPUT: begin
                // Check if parsing is done
                if (j >= num_families && i >= num_catches) begin
                    next_state = EVALUATE_WINDOWS;
                end else begin
                    next_state = PARSE_INPUT;
                end
            end
            
            EVALUATE_WINDOWS: begin
                // Check if counting is done for current window
                if (m >= num_catches || m >= 8) begin
                    next_state = COMPUTE_XP;
                end else begin
                    next_state = EVALUATE_WINDOWS;
                end
            end
            
            COMPUTE_XP: begin
                // Check if all windows processed
                if (current_window == 3) begin
                    next_state = DONE;
                end else begin
                    next_state = EVALUATE_WINDOWS;
                end
            end
            
            DONE: next_state = start ? IDLE : DONE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule