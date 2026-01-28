module TournamentRanking(
    input clk,
    input rst_n,
    input start,
    input [255:0] adj,
    input [15:0] S_mask,
    input [3:0] k,
    output reg [3:0] result,
    output reg found,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] ITER_SIZE = 3'd2;
    localparam [2:0] ITER_COMB = 3'd3;
    localparam [2:0] CHECK_CYCLE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] current_size;
    reg [15:0] current_comb;
    reg [15:0] active_mask;
    reg [15:0] in_degree [0:15];
    reg [15:0] zero_degree_mask;
    reg [15:0] processed_mask;
    reg [7:0] cycle_count;
    reg [15:0] temp_mask;
    reg [3:0] i, j, m;
    reg [15:0] U_mask;
    reg [15:0] S_prime_mask;
    reg [15:0] remaining_mask;
    reg [3:0] node_count;
    reg [3:0] processed_count;
    reg is_acyclic;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_size <= 4'd0;
            current_comb <= 16'd0;
            active_mask <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                in_degree[i] <= 16'd0;
            end
            zero_degree_mask <= 16'd0;
            processed_mask <= 16'd0;
            cycle_count <= 8'd0;
            temp_mask <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            m <= 4'd0;
            U_mask <= 16'd0;
            S_prime_mask <= 16'd0;
            remaining_mask <= 16'd0;
            node_count <= 4'd0;
            processed_count <= 4'd0;
            is_acyclic <= 1'b0;
            result <= 4'd0;
            found <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Compute U_mask = all players not in S
                U_mask = ~S_mask & 16'hFFFF;
                current_size = 4'd0;
                next_state = ITER_SIZE;
            end

            ITER_SIZE: begin
                if (current_size < k - 4'd1) begin
                    // Initialize combination counter
                    current_comb = 16'd0;
                    next_state = ITER_COMB;
                end else begin
                    // No valid S' found
                    result = 4'd15;
                    found = 1'b0;
                    done = 1'b1;
                    next_state = DONE_STATE;
                end
            end

            ITER_COMB: begin
                // Generate next combination
                S_prime_mask = current_comb & U_mask;
                if (count_bits(S_prime_mask) == current_size) begin
                    // Valid combination, check cycle
                    next_state = CHECK_CYCLE;
                end else begin
                    // Move to next combination
                    current_comb = current_comb + 16'd1;
                    if (current_comb > 16'hFFFF) begin
                        // All combinations checked for this size
                        current_size = current_size + 4'd1;
                        next_state = ITER_SIZE;
                    end
                end
            end

            CHECK_CYCLE: begin
                // Compute active_mask = players not in S or S'
                active_mask = ~S_mask & ~S_prime_mask & 16'hFFFF;
                
                // Initialize in_degree for active nodes
                for (i = 0; i < 16; i = i + 1) begin
                    if (active_mask[i]) begin
                        in_degree[i] = 16'd0;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (active_mask[j] && adj[i*16 + j]) begin
                                in_degree[i] = in_degree[i] + 16'd1;
                            end
                        end
                    end
                end

                // Initialize Kahn's algorithm
                zero_degree_mask = 16'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if (active_mask[i] && in_degree[i] == 16'd0) begin
                        zero_degree_mask[i] = 1'b1;
                    end
                end
                processed_mask = 16'd0;
                processed_count = 4'd0;
                node_count = count_bits(active_mask);
                is_acyclic = 1'b1;
                next_state = CHECK_CYCLE;
            end

            CHECK_CYCLE: begin
                if (zero_degree_mask == 16'd0) begin
                    // No zero-degree nodes left
                    if (processed_count == node_count) begin
                        // All nodes processed - acyclic
                        is_acyclic = 1'b1;
                    end else begin
                        // Cycle detected
                        is_acyclic = 1'b0;
                    end
                    
                    if (is_acyclic) begin
                        // Found valid S'
                        result = current_size;
                        found = 1'b1;
                        done = 1'b1;
                        next_state = DONE_STATE;
                    end else begin
                        // Try next combination
                        current_comb = current_comb + 16'd1;
                        next_state = ITER_COMB;
                    end
                end else begin
                    // Process a zero-degree node
                    for (i = 0; i < 16; i = i + 1) begin
                        if (zero_degree_mask[i]) begin
                            // Remove this node
                            processed_mask[i] = 1'b1;
                            processed_count = processed_count + 4'd1;
                            zero_degree_mask[i] = 1'b0;
                            
                            // Update in_degree for neighbors
                            for (j = 0; j < 16; j = j + 1) begin
                                if (active_mask[j] && adj[i*16 + j] && !processed_mask[j]) begin
                                    in_degree[j] = in_degree[j] - 16'd1;
                                    if (in_degree[j] == 16'd0) begin
                                        zero_degree_mask[j] = 1'b1;
                                    end
                                end
                            end
                            break;
                        end
                    end
                end
            end

            DONE_STATE: begin
                done = 1'b0;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Helper function to count bits
    function [3:0] count_bits;
        input [15:0] mask;
        integer i;
        begin
            count_bits = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (mask[i]) begin
                    count_bits = count_bits + 4'd1;
                end
            end
        end
    endfunction

endmodule