module pillar_cascade (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] b [0:7],
    output reg [2:0] max_damage,
    output reg [2:0] best_pillar,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        SIMULATION_LOOP,
        CHECK_DESTROYED,
        UPDATE_LOADS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] pillar_idx; // Current pillar being removed
    reg [2:0] sim_iter; // Simulation iteration counter
    reg [2:0] destroyed_count; // Count of destroyed pillars in current simulation
    reg [2:0] max_destroyed; // Max destroyed count across all simulations
    reg [2:0] best_idx; // Best pillar index
    reg [7:0] temp_strength [0:7]; // Temporary strength array
    reg [7:0] load [0:7]; // Load on each pillar
    reg [7:0] destroyed [0:7]; // Destroyed status (1=destroyed)
    reg [2:0] check_idx; // Index for checking destroyed pillars
    reg [2:0] update_idx; // Index for updating loads
    reg [2:0] neighbor_count; // Count of destroyed neighbors

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            pillar_idx <= 0;
            sim_iter <= 0;
            destroyed_count <= 0;
            max_destroyed <= 0;
            best_idx <= 0;
            done <= 0;
            max_damage <= 0;
            best_pillar <= 0;
            for (int i = 0; i < 8; i++) begin
                temp_strength[i] <= 0;
                load[i] <= 0;
                destroyed[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end
            SETUP: begin
                next_state = SIMULATION_LOOP;
            end
            SIMULATION_LOOP: begin
                if (sim_iter == 7) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_DESTROYED;
                end
            end
            CHECK_DESTROYED: begin
                if (check_idx == 7) begin
                    next_state = UPDATE_LOADS;
                end
            end
            UPDATE_LOADS: begin
                if (update_idx == 7) begin
                    next_state = SIMULATION_LOOP;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
        end else begin
            case (current_state)
                SETUP: begin
                    // Initialize for new simulation
                    pillar_idx <= 0;
                    sim_iter <= 0;
                    destroyed_count <= 0;
                    max_destroyed <= 0;
                    best_idx <= 0;
                    // Copy strengths to temp array
                    for (int i = 0; i < 8; i++) begin
                        temp_strength[i] <= b[i];
                    end
                    // Mark first pillar as destroyed
                    destroyed[pillar_idx] <= 1;
                    destroyed_count <= 1;
                end
                SIMULATION_LOOP: begin
                    // Move to next pillar
                    pillar_idx <= pillar_idx + 1;
                    sim_iter <= sim_iter + 1;
                    check_idx <= 0;
                    update_idx <= 0;
                    // Reset destroyed array except current pillar
                    for (int i = 0; i < 8; i++) begin
                        if (i == pillar_idx) begin
                            destroyed[i] <= 1;
                        end else begin
                            destroyed[i] <= 0;
                        end
                    end
                    destroyed_count <= 1;
                end
                CHECK_DESTROYED: begin
                    // Check if current pillar is destroyed
                    if (destroyed[check_idx]) begin
                        check_idx <= check_idx + 1;
                    end else begin
                        // Calculate load
                        neighbor_count = 0;
                        if (check_idx > 0 && destroyed[check_idx - 1]) begin
                            neighbor_count = neighbor_count + 1;
                        end
                        if (check_idx < 7 && destroyed[check_idx + 1]) begin
                            neighbor_count = neighbor_count + 1;
                        end
                        load[check_idx] = 1000 * (1 + neighbor_count);
                        // Check if load exceeds strength
                        if (load[check_idx] > temp_strength[check_idx]) begin
                            destroyed[check_idx] <= 1;
                            destroyed_count <= destroyed_count + 1;
                        end
                        check_idx <= check_idx + 1;
                    end
                end
                UPDATE_LOADS: begin
                    // Update loads for next iteration
                    if (update_idx == 7) begin
                        // Check if this simulation has max damage
                        if (destroyed_count > max_destroyed) begin
                            max_destroyed <= destroyed_count;
                            best_idx <= pillar_idx;
                        end
                        update_idx <= 0;
                    end else begin
                        update_idx <= update_idx + 1;
                    end
                end
                DONE: begin
                    // Output results
                    max_damage <= max_destroyed;
                    best_pillar <= best_idx;
                    done <= 1;
                end
            endcase
        end
    end

endmodule