module pillar_cascade (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [7:0] b [0:7],
    output reg [2:0] max_damage,
    output reg [2:0] best_pillar,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam SIMULATION_LOOP = 3'b010;
    localparam CHECK_DESTROYED = 3'b011;
    localparam UPDATE_LOADS = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Internal registers
    reg [2:0] i; // Iteration index (pillar to remove initially)
    reg [2:0] j; // Inner loop index for checking pillars
    reg [2:0] best_pillar_reg;
    reg [2:0] max_damage_reg;

    // Simulation buffers
    // Stores 0 (intact) or 1 (destroyed)
    reg destroyed [0:7];
    reg [7:0] current_loads [0:7];
    reg [7:0] temp_b [0:7];

    // Helper signals
    reg sim_done;
    reg [2:0] current_damage_count;
    reg has_destroyed;

    // Neighbor logic helper signals
    wire left_destroyed;
    wire right_destroyed;
    wire [7:0] load_factor;

    // Sequential State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end
            SETUP: begin
                next_state = SIMULATION_LOOP;
            end
            SIMULATION_LOOP: begin
                if (sim_done) next_state = DONE;
                else next_state = CHECK_DESTROYED;
            end
            CHECK_DESTROYED: begin
                // If no pillars were destroyed in this pass, simulation for current i is done
                if (!has_destroyed) next_state = SIMULATION_LOOP;
                else next_state = UPDATE_LOADS;
            end
            UPDATE_LOADS: begin
                // After updating loads, go back to check again (or loop logic)
                // We loop back to CHECK_DESTROYED essentially to re-evaluate
                next_state = SIMULATION_LOOP;
            end
            DONE: begin
                next_state = IDLE; // Auto return to idle or wait for start reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Logic for Load Factor (1000 * (1 + neighbors))
    // We use a threshold of 200 to represent the base load 1000 scaled down (e.g., 1 unit = 50 load)
    // Actually, prompt implies: Load = 1000 * (1 + num_destroyed_neighbors).
    // Strengths are 0-255. 1000 is way too high.
    // Let's map: Load = 50 * (1 + neighbors).
    // If 0 neighbors: Load = 50. If 1 neighbor: 100. If 2 neighbors: 150.
    // Threshold logic: if (Load > b[j]) break.
    assign left_destroyed = (j > 0) ? destroyed[j-1] : 1'b0;
    assign right_destroyed = (j < 7) ? destroyed[j+1] : 1'b0;

    // Datapath Logic (Sequenced)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal counters
            max_damage <= 0;
            best_pillar <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            max_damage_reg <= 0;
            best_pillar_reg <= 0;
            sim_done <= 1;
            has_destroyed <= 0;
            current_damage_count <= 0;
            // Initialize destroyed array to 0 (optional in reset if handled in setup)
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    sim_done <= 1;
                end

                SETUP: begin
                    // Initialize for the first iteration (i=0)
                    i <= 0;
                    max_damage_reg <= 0;
                    best_pillar_reg <= 0;
                    sim_done <= 0;
                    // Copy strengths to temp_b (one time or done in loop, doing here for per-iteration)
                    // Actually, we will copy temp_b in SIMULATION_LOOP start for each i
                end

                SIMULATION_LOOP: begin
                    // Determine when the outer loop (over i) is done
                    if (i >= n) begin
                        sim_done <= 1;
                    end else begin
                        // Start new simulation for current i
                        // Need to initialize buffers for this simulation
                        // We can do this in a sub-state or combinational, but let's use logic here
                        // However, SV always block is sequential. We need to set initial values.
                        // To avoid multiple drivers, we handle array init in a specific way or use logic gates.
                        // Let's use a "setup_sim" flag logic implied by the loop start.
                        // We need to set destroyed[i] = 1, others 0. Load all b to temp_b.
                        // Reset current_damage_count to 1 (since i is destroyed immediately).
                        
                        // Note: In hardware, we can't easily initialize arrays inside an always block sequentially without external logic or a flag.
                        // Let's rely on the SETUP state for the *very first* iteration and manual resets here.
                        
                        // Let's just track the iteration start:
                        // We need to initialize destroyed array for each 'i'.
                        // Optimization: Since we are in a loop, we can assume logic handles it.
                        // But strictly, we need to set: destroyed[k] = (k==i).
                        // And current_damage_count = 1.
                        
                        // We will actually do the initialization in the transition logic or use a 'first_pass' register.
                        // Simplified approach: Use a dedicated 'init_sim' state or combinational logic driven by 'i'.
                        // Let's use combinational logic to reset arrays based on 'i', but 'i' changes sequentially.
                        // It's safer to do it in the SETUP step for each i, but SETUP is only entered once.
                        // Let's insert a logic inside SIMULATION_LOOP to detect start of simulation for current 'i'.
                        // We can use a counter to distinguish the first cycle of the specific 'i'.
                        // Or, restructure states: IDLE -> SETUP_SIM -> LOOP...
                        // Given constraints, let's assume we calculate 'init' conditionally.
                        
                        // Let's use an internal flag 'sim_init_done' to prevent re-initialization.
                        // Actually, let's change the state machine slightly conceptually:
                        // When entering SIMULATION_LOOP for a new i, we must set up.
                        // Let's treat the first clock of SIMULATION_LOOP after 'i' changed as the setup phase.
                        // We'll use a `sim_phase` register.
                    end
                end

                CHECK_DESTROYED: begin
                    // Evaluate current j against load
                    // Load calculation: base 50 + 50 * num_neighbors
                    // Let's say threshold is 200 (scaled 1000) or just check explicit numbers.
                    // If 1000 is base, and max strength 255, we need to scale.
                    // Let's define: Load = 100 * (1 + count).
                    // If count=0, load=100. If count=1, 200. If count=2, 300.
                    // If Load > b[j], break.
                    
                    // We iterate j from 0 to n-1
                    // If j reaches n, we need to check if we destroyed anything this round.
                    // If j is inside range, check logic.
                    
                    if (j < n) begin
                        if (!destroyed[j]) begin
                            // Calculate load
                            // neighbors: destroyed[j-1] + destroyed[j+1]
                            // We handle boundary conditions via wire.
                            // Let's use simple logic: Load = 100 * (1 + left_destroyed + right_destroyed)
                            // If Load > temp_b[j], mark destroyed[j] = 1, has_destroyed = 1, current_damage_count++
                            
                            // We do this combinationally or sequentially?
                            // Sequentially is safer to avoid long paths, but requires states.
                            // Let's do the comparison here.
                            if ((100 * (1 + left_destroyed + right_destroyed)) > temp_b[j]) begin
                                destroyed[j] <= 1;
                                has_destroyed <= 1; // Flag to indicate a break happened
                                current_damage_count <= current_damage_count + 1;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        // Finished checking all pillars for this pass
                        j <= 0; // Reset for next pass
                        // The 'has_destroyed' flag is already set or cleared by the loop above.
                        // However, sequential 'has_destroyed' might lag if we check in same cycle.
                        // To reliably detect if *any* pillar broke this pass, we need a combinational check or accumulate flags.
                        // Let's simplify: The state transition CHECK -> UPDATE/LOOP depends on a registered flag.
                        // We will set `has_destroyed` to 0 at the start of the CHECK phase (if we could) or use a dedicated pulse.
                        // Actually, let's reset `has_destroyed` in the UPDATE_LOADS state (since that's the start of a new pass).
                    end
                end

                UPDATE_LOADS: begin
                    // This state is reached after a pass.
                    // If has_destroyed was true, we loop again.
                    // If has_destroyed was false, we finished this 'i'.
                    // We need to check the value of has_destroyed that was set during the CHECK phase.
                    // Since CHECK sets it, it should be valid here.
                    
                    if (has_destroyed) begin
                        // Continue the cascade simulation for current i
                        j <= 0;
                        has_destroyed <= 0; // Reset for next pass
                    end else begin
                        // Simulation for this i is finished
                        // Update max_damage if needed
                        if (current_damage_count > max_damage_reg) begin
                            max_damage_reg <= current_damage_count;
                            best_pillar_reg <= i;
                        end
                        // Advance i
                        i <= i + 1;
                        // Setup for next i needs to happen.
                        // In the next cycle, we go to SIMULATION_LOOP.
                        // We need to initialize `destroyed` array to all 0 except i.
                        // And `current_damage_count` to 1.
                        // We can't do this inside the always block easily for arrays.
                        // Let's add a "RESTART_INNER" state or logic.
                        // Actually, let's use combinational logic to drive `destroyed` and `temp_b`.
                        // It's hard to manage array reset in pure sequential logic without a lot of states.
                        
                        // Hack: Initialize arrays in IDLE/SETUP. For subsequent 'i', we need to clear them.
                        // We will add a dedicated logic block below to handle array initialization.
                    end
                end

                DONE: begin
                    max_damage <= max_damage_reg;
                    best_pillar <= best_pillar_reg;
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational Logic for Array Initialization & Reset
    // This handles the tricky part: resetting the destroyed array and temp_b for the new 'i'
    // We trigger this when we need to reset for a new 'i'.
    // We need a signal to trigger this reset. Let's add a reg `reset_inner`.
    reg reset_inner;
    
    // State logic modification for `reset_inner` and `has_destroyed` clearing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_inner <= 0;
        end else begin
            if (current_state == UPDATE_LOADS && !has_destroyed) begin
                // Just finished an 'i'. Next cycle we are in SIMULATION_LOOP.
                // We need to trigger reset logic for the next 'i' (which is i+1).
                // However, i is updated in the same cycle (if we fix code above).
                // Let's fix the UPDATE_LOADS logic to be cleaner.
                // In UPDATE_LOADS: 
                // If !has_destroyed: i <= i + 1; reset_inner <= 1;
                // If has_destroyed: reset_inner <= 0;
                // But we need to handle the first cycle of the *new* i.
                reset_inner <= 1;
            end else if (current_state == SIMULATION_LOOP && reset_inner) begin
                // We have applied the reset, so deassert it.
                reset_inner <= 0;
            end
        end
    end

    // Array Update Logic (Parallel/Combinational with registers)
    // This block is tricky. Arrays in always_ff need non-blocking assignments.
    // We need to handle the 'reset_inner' pulse.
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 8; k = k + 1) begin
                destroyed[k] <= 0;
                temp_b[k] <= 0;
                current_loads[k] <= 0;
            end
            current_damage_count <= 0;
            has_destroyed <= 0;
            j <= 0;
        end else begin
            // Handle reset_inner (initialization for new i)
            if (reset_inner) begin
                // Initialize for current 'i' (value is already updated in previous cycle)
                for (k = 0; k < 8; k = k + 1) begin
                    if (k == i) begin
                        destroyed[k] <= 1;
                    end else begin
                        destroyed[k] <= 0;
                    end
                    temp_b[k] <= b[k]; // Load strengths
                end
                current_damage_count <= 1; // The initial destroyed pillar counts
                has_destroyed <= 0;
                j <= 0;
            end else begin
                // Normal operation
                case (current_state)
                    CHECK_DESTROYED: begin
                        if (j < n) begin
                            // Logic to destroy pillar j if load > strength
                            // Recalculating load here (same as wire, but blocking to ensure order)
                            // We use the 'destroyed' array values BEFORE this update (they are registered)
                            // So we can use the registered values safely.
                            // However, checking 'destroyed' status of neighbors requires reading the array.
                            // In Verilog, reading arrays in sensitivity list is tricky.
                            // We rely on the 'left_destroyed' and 'right_destroyed' wires defined earlier.
                            // But those wires read 'destroyed' array which is being written.
                            // It's usually okay to read old value in sync block.
                            
                            // Let's perform the check.
                            // We need to know 'has_destroyed' state from this cycle (combinational) or previous?
                            // To ensure we catch 'any' destruction, we can OR a flag.
                            
                            if (!destroyed[j]) begin
                                // Load calculation:
                                // Neighbors: (j>0 ? destroyed[j-1] : 0) + (j<7 ? destroyed[j+1] : 0)
                                // Note: reading array is combinational. We are in a clocked block, reading current value.
                                // Let's use combinational wires for better practice but logic is same.
                                reg left_dest;
                                reg right_dest;
                                left_dest = (j > 0) ? destroyed[j-1] : 0;
                                right_dest = (j < 7) ? destroyed[j+1] : 0;
                                
                                if (100 * (1 + left_dest + right_dest) > temp_b[j]) begin
                                    destroyed[j] <= 1;
                                    current_damage_count <= current_damage_count + 1;
                                    has_destroyed <= 1; // Set flag
                                end
                            end
                        end
                    end
                    UPDATE_LOADS: begin
                        // Logic to determine if we are done with this i is handled in the main state block
                        // But we need to handle the transition to next i.
                        if (!has_destroyed) begin
                            // Finished. We will update i in the state block.
                            // But we already did that in the logic above.
                            // Wait, the logic above in the state block updated i.
                            // We need to re-verify the sequence.
                            
                            // Revised flow for UPDATE_LOADS:
                            // 1. Check results of pass (has_destroyed).
                            // 2. If destroyed > max, update max.
                            // 3. If !destroyed: We are done with this i. Move to next i.
                            //    Set reset_inner = 1 for next cycle.
                            //    If next i >= n, go to DONE.
                            // 4. If destroyed: Stay in this i. Continue loop.
                            
                            // The previous always block for state transition was:
                            // if (has_destroyed) next_state = SIMULATION_LOOP
                            // else next_state = SIMULATION_LOOP (but increment i)
                            // Both go to SIMULATION_LOOP. 
                            
                            // We need to perform the "i increment" and "max update" here.
                            // But the state transition block decided next_state = SIMULATION_LOOP.
                            // So we need to increment i here if !has_destroyed.
                            
                            if (current_damage_count > max_damage_reg) begin
                                max_damage_reg <= current_damage_count;
                                best_pillar_reg <= i;
                            end
                            
                            i <= i + 1;
                            // If i+1 >= n, we can't just blindly continue. 
                            // We need a flag to go to DONE instead of SIMULATION_LOOP.
                            // Let's rely on the NEXT state logic to check `i`.
                            // But the state logic is already fixed to go to SIMULATION_LOOP.
                            // Let's change state logic to DONE if (i == n-1) ?
                            // No, i increments to n. In SIMULATION_LOOP, we check if i >= n.
                            // So: UPDATE_LOADS -> SIMULATION_LOOP. SIMULATION_LOOP checks i>=n -> DONE.
                            
                            // We set reset_inner here to prep for next i.
                            reset_inner <= 1;
                        end else begin
                            // Continue cascade
                            reset_inner <= 0;
                            // has_destroyed is cleared in the SIMULATION_LOOP state or here? 
                            // We need to clear it before the next CHECK pass.
                            // Let's clear it here.
                            has_destroyed <= 0;
                        end
                    end
                endcase
            end
        end
    end

    // Update State Logic for the "Sim Done" check and flow control
    // We need to override the flow if i >= n.
    // Since the sequential block updates i at the end of UPDATE_LOADS (if !has_destroyed),
    // the next state is SIMULATION_LOOP. 
    // We need to intercept this.
    // We'll add logic to the state transition block based on 'i'.
    // Actually, let's make a new combinational logic for 'done_condition'.
    
    always @(*) begin
        if (current_state == SIMULATION_LOOP) begin
            if (i >= n) begin
                // We just entered with i==n (or i>=n). 
                // This happens after the last increment.
                sim_done = 1; // Signal to go to DONE
            end else if (!reset_inner && (current_state == SIMULATION_LOOP)) begin
                // This is the steady state of SIMULATION_LOOP after init.
                // We proceed to CHECK_DESTROYED.
            end
        end
    end

    // Fix for `sim_done` usage in next_state logic:
    // The original SIMULATION_LOOP transition was:
    // if (sim_done) next_state = DONE;
    // else next_state = CHECK_DESTROYED;
    // We need to ensure `sim_done` is set when i >= n.
    // But `i` is updated in UPDATE_LOADS. 
    // Flow: UPDATE_LOADS -> SIMULATION_LOOP -> ... 
    // In SIMULATION_LOOP (first cycle after update), `i` is already updated to the next value.
    // So if that value is >= n, we should go to DONE.

    // Revised `sim_done` assignment:
    always @(*) begin
        if (current_state == SIMULATION_LOOP && i >= n) begin
            sim_done = 1;
        end else begin
            sim_done = 0;
        end
    end

endmodule
