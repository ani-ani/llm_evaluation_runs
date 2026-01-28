module OptimalVector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    input wire [4:0] k_in,
    input wire [31:0] data_in,
    input wire data_valid,
    output reg [31:0] result,
    output reg done
);

    // Parameters for maximum sizes
    localparam integer N_MAX = 8;       // Maximum n for exhaustive search
    localparam integer K_MAX = 10;      // Maximum k (features)
    localparam integer MAX_VECTORS = 1 << K_MAX; // 2^10 = 1024 candidates

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] COLLECT_INPUT = 3'd1;
    localparam [2:0] INIT_SEARCH  = 3'd2;
    localparam [2:0] CHECK_CANDIDATE = 3'd3;
    localparam [2:0] COMPUTE_SIMILARITY = 3'd4;
    localparam [2:0] UPDATE_BEST = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] k_reg;                 // Actual k used (1 to K_MAX)
    reg [7:0] n_reg;                 // Actual n used (1 to N_MAX)
    reg [7:0] input_count;           // Counter for input vectors
    reg [9:0] candidate;             // Current candidate (up to 10 bits for K_MAX=10)
    reg [9:0] best_candidate;        // Best candidate found
    reg [15:0] best_max_sim;         // Minimum max similarity found (max is k)
    reg [15:0] current_max_sim;      // Current max similarity for candidate
    reg [15:0] current_similarity;   // Current similarity for one vector
    reg [7:0] vector_idx;            // Index of vector being compared
    reg [31:0] temp_v;               // Temporary storage for comparison
    reg [31:0] temp_c;               // Temporary storage for candidate (aligned)
    reg [31:0] xor_val;              // XOR result
    reg [7:0] popcount_val;          // Popcount result
    reg [7:0] hamming_dist;          // Hamming distance
    reg [15:0] sim_temp;             // Similarity temporary
    
    // Memory for input vectors (32 bits wide, N_MAX deep)
    reg [31:0] input_ram [0:N_MAX-1];
    
    // Combinational popcount logic (8-bit LUT-style or bitwise)
    // We implement a simple ripple counter style for popcount to avoid large LUTs
    // For simulation and small k, this is acceptable.
    reg [2:0] pop_idx;
    
    // Cycle counter to prevent infinite loops (safety)
    reg [15:0] cycle_counter;
    
    // Helper for candidate iteration limit
    wire [9:0] max_candidate;
    assign max_candidate = (1 << k_reg) - 1; // 2^k - 1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k_reg <= 5'd0;
            n_reg <= 8'd0;
            input_count <= 8'd0;
            candidate <= 10'd0;
            best_candidate <= 10'd0;
            best_max_sim <= 16'd0;
            current_max_sim <= 16'd0;
            current_similarity <= 16'd0;
            vector_idx <= 8'd0;
            temp_v <= 32'd0;
            temp_c <= 32'd0;
            xor_val <= 32'd0;
            popcount_val <= 8'd0;
            hamming_dist <= 8'd0;
            sim_temp <= 16'd0;
            pop_idx <= 3'd0;
            cycle_counter <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        k_reg <= k_in;
                        n_reg <= n_in;
                        input_count <= 8'd0;
                    end
                end

                COLLECT_INPUT: begin
                    if (data_valid && input_count < n_reg && input_count < N_MAX) begin
                        input_ram[input_count] <= data_in;
                        input_count <= input_count + 8'd1;
                    end
                end

                INIT_SEARCH: begin
                    candidate <= 10'd0;
                    best_candidate <= 10'd0;
                    best_max_sim <= 16'hFFFF; // Initialize to max value
                    cycle_counter <= 16'd0;
                end

                CHECK_CANDIDATE: begin
                    current_max_sim <= 16'd0;
                    vector_idx <= 8'd0;
                    temp_c <= {22'd0, candidate}; // Pack candidate into 32 bits
                end

                COMPUTE_SIMILARITY: begin
                    // Load vector from RAM
                    temp_v <= input_ram[vector_idx];
                    // Compute XOR
                    xor_val <= temp_v ^ temp_c;
                    // We need to compute popcount of lower k_reg bits of xor_val
                    // Reset popcount accumulator
                    popcount_val <= 8'd0;
                    pop_idx <= 3'd0;
                end
                
                // Note: We are compressing the popcount loop into the state machine
                // to avoid functions (which are tricky in Icarus Verilog with arrays).
                // We will do the popcount logic directly in the UPDATE_BEST state
                // or split states. Since timing is flexible, we can do sequential popcount.
                // For simplicity in this FSM, we compute hamming distance in UPDATE_BEST.
                
                UPDATE_BEST: begin
                    // We compute Hamming distance here by accumulating bit by bit
                    // This is a sequential implementation within the state
                    if (pop_idx < k_reg[2:0]) begin
                        pop_idx <= pop_idx + 3'd1;
                        popcount_val <= popcount_val + xor_val[pop_idx];
                    end else begin
                        // Popcount done for this vector
                        hamming_dist <= popcount_val;
                        // Similarity = k - Hamming distance
                        sim_temp <= k_reg - popcount_val;
                        
                        // Update max_sim for current candidate
                        if (vector_idx == 8'd0) begin
                            current_max_sim <= (k_reg - popcount_val);
                        end else if ((k_reg - popcount_val) > current_max_sim) begin
                            current_max_sim <= (k_reg - popcount_val);
                        end
                        
                        // Move to next vector or finalize candidate
                        if (vector_idx < n_reg - 8'd1 && vector_idx < N_MAX - 8'd1) begin
                            vector_idx <= vector_idx + 8'd1;
                            // Reset popcount for next iteration
                            popcount_val <= 8'd0;
                            pop_idx <= 3'd0;
                            // Trigger next similarity compute (loop back to COMPUTE_SIMILARITY implicitly)
                            // We handle this by state transition logic below
                        end else begin
                            // Done with all vectors for this candidate
                            // Compare to best
                            if (current_max_sim < best_max_sim) begin
                                best_max_sim <= current_max_sim;
                                best_candidate <= candidate;
                            end
                            // Next candidate
                            if (candidate < max_candidate) begin
                                candidate <= candidate + 10'd1;
                                // Transition back to CHECK_CANDIDATE via logic
                            end else begin
                                // All candidates checked
                                result <= {22'd0, best_candidate};
                                done <= 1'b1;
                                state <= FINISH;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b0; // Pulse done for 1 cycle
                end
            endcase
        end
    end

    // State Transition Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COLLECT_INPUT;
            end
            COLLECT_INPUT: begin
                // Wait until we have collected n_reg inputs or max limit
                if (input_count >= n_reg || input_count >= N_MAX) begin
                    next_state = INIT_SEARCH;
                end
            end
            INIT_SEARCH: begin
                next_state = CHECK_CANDIDATE;
            end
            CHECK_CANDIDATE: begin
                if (cycle_counter > 10000) next_state = IDLE; // Safety timeout
                else next_state = COMPUTE_SIMILARITY;
            end
            COMPUTE_SIMILARITY: begin
                // Wait one cycle for temp_v to load and xor to compute
                next_state = UPDATE_BEST;
            end
            UPDATE_BEST: begin
                // If popcount is running (pop_idx < k)
                if (pop_idx < k_reg[2:0]) begin
                    next_state = UPDATE_BEST; // Stay here to count bits
                end else if (vector_idx < n_reg - 8'd1 && vector_idx < N_MAX - 8'd1) begin
                    next_state = COMPUTE_SIMILARITY; // Next vector
                end else if (candidate < max_candidate) begin
                    next_state = CHECK_CANDIDATE; // Next candidate
                end else begin
                    next_state = FINISH; // Done
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule