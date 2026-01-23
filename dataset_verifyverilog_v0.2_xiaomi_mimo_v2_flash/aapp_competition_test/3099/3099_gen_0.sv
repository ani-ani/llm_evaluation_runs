module spy_network (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_spies,
    input [7:0] enemy_mask,
    input [7:0] adj_matrix [0:7],
    output reg [3:0] min_messages,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam REACHABILITY = 3'b010;
    localparam GREEDY_SETUP = 3'b011;
    localparam GREEDY_SELECT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Internal registers
    reg [7:0] reachability [0:7]; // Transitive closure matrix
    reg [7:0] safe_nodes;          // Bitmask of safe nodes
    reg [7:0] covered_nodes;       // Bitmask of covered nodes

    // Counters and indices
    reg [2:0] i, j, k; // Loop variables
    reg [2:0] safe_idx [0:7]; // Map logical safe index to node index (0-7)
    reg [2:0] safe_count;     // Number of safe nodes
    reg [2:0] best_node;      // Node index with max coverage
    reg [3:0] max_coverage;   // Coverage count of best node
    reg [3:0] current_coverage; // Temp coverage counter
    reg [2:0] candidate_idx;  // Current candidate index in safe_nodes loop

    // Helper wires for combinational logic
    reg [7:0] candidate_mask;
    reg [7:0] new_covered;
    reg candidate_valid;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = REACHABILITY;
            REACHABILITY: begin
                if (k == 3'd7 && i == 3'd7 && j == 3'd7) next_state = GREEDY_SETUP;
            end
            GREEDY_SETUP: next_state = GREEDY_SELECT;
            GREEDY_SELECT: begin
                if (safe_count == 4'd0) next_state = DONE; // No safe nodes
                else if (covered_nodes == safe_nodes) next_state = DONE;
                else if (candidate_idx == safe_count) next_state = GREEDY_SELECT; // Wait for calculation?
            end
            DONE: if (!start) next_state = IDLE; // Wait for start low to reset logic if needed, or just stay
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_messages <= 0;
            done <= 0;
            i <= 0; j <= 0; k <= 0;
            safe_count <= 0;
            candidate_idx <= 0;
            covered_nodes <= 0;
            safe_nodes <= 0;
            // Clear reachability
            for (int idx = 0; idx < 8; idx++) reachability[idx] <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    min_messages <= 0;
                end

                INIT: begin
                    // Compute safe nodes
                    safe_nodes <= (~enemy_mask) & (8'hFF >> (3'd8 - num_spies));
                    // Create mapping array for iteration later
                    safe_count <= 0;
                    // We will populate safe_idx in GREEDY_SETUP or here
                    // We need to populate reachability with adj_matrix initially
                    for (int idx = 0; idx < 8; idx++) begin
                        if (idx < num_spies) 
                            reachability[idx] <= adj_matrix[idx];
                        else 
                            reachability[idx] <= 0;
                    end
                    i <= 0; j <= 0; k <= 0;
                    covered_nodes <= 0;
                end

                REACHABILITY: begin
                    // Floyd-Warshall Sequential
                    if (reachability[i][k] && reachability[k][j]) begin
                        reachability[i][j] <= 1'b1;
                    end

                    // Increment counters
                    if (j < 3'd7) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < 3'd7) begin
                            i <= i + 1;
                        end else begin
                            i <= 0;
                            if (k < 3'd7) begin
                                k <= k + 1;
                            end else begin
                                k <= 0; // Done
                            end
                        end
                    end
                end

                GREEDY_SETUP: begin
                    // Populate safe_idx array for easy iteration
                    safe_count <= 0;
                    for (int idx = 0; idx < 8; idx++) begin
                        if (safe_nodes[idx]) begin
                            safe_count <= safe_count + 1;
                            safe_idx[safe_count] <= idx[2:0]; // This is race condition if unrolled.
                        end
                    end
                    k <= 0;
                    covered_nodes <= 0;
                    min_messages <= 0;
                end

                GREEDY_SELECT: begin
                    // Logic:
                    if (j == 0) begin // Scanning Phase
                        if (i < 8) begin
                            if (safe_nodes[i]) begin
                                if (k < 8) begin
                                    if (reachability[i][k] && !covered_nodes[k]) begin
                                        current_coverage <= current_coverage + 1;
                                    end
                                    k <= k + 1;
                                end else begin
                                    if (current_coverage > max_coverage) begin
                                        max_coverage <= current_coverage;
                                        candidate_idx <= i; // Store best node index
                                    end
                                    current_coverage <= 0;
                                    k <= 0;
                                    i <= i + 1;
                                end
                            end else begin
                                i <= i + 1;
                            end
                        end else begin
                            if (max_coverage > 0) begin
                                j <= 1; // Switch to Update phase
                                i <= 0; // Reset i for next loop (or reuse)
                                k <= 0; // Reset k
                            end else begin
                                // No more coverage possible, done
                            end
                        end
                    end else if (j == 1) begin // Update Phase
                        covered_nodes <= covered_nodes | reachability[candidate_idx];
                        min_messages <= min_messages + 1;
                        i <= 0;
                        k <= 0;
                        max_coverage <= 0;
                        current_coverage <= 0;
                        j <= 0; // Back to scan
                    end
                end

                DONE: begin
                    done <= 1;
                    // Hold min_messages
                end
            endcase
        end
    end

    // Correction for GREEDY_SETUP:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // ...
        end else begin
            if (current_state == INIT) begin
                // ... (existing INIT logic)
            end else if (current_state == GREEDY_SETUP) begin
                i <= 0;
                k <= 0;
                j <= 0; // Phase 0: Scan
                max_coverage <= 0;
                current_coverage <= 0;
            end
        end
    end

endmodule