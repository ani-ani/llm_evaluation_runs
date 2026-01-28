module maze_isomorphism (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_rooms,
    input wire adjacency_valid,
    input wire [3:0] room_idx,
    input wire [3:0] degree,
    input wire [3:0] connections [0:7],
    output reg [3:0] result_room,
    output reg [3:0] result_match,
    output reg result_valid,
    output reg done,
    output reg none
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD          = 3'd1;
    localparam [2:0] COMPUTE_INIT  = 3'd2;
    localparam [2:0] COMPUTE_BFS   = 3'd3;
    localparam [2:0] COMPARE       = 3'd4;
    localparam [2:0] OUTPUT        = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, j, k, depth;
    reg [3:0] room_cnt_reg;
    
    // Adjacency storage: 16 rooms x 8 neighbors (each 4 bits)
    reg [3:0] stored_degrees [0:15];
    reg [3:0] stored_conns [0:15][0:7];
    
    // Signature storage
    reg [15:0] signatures [0:15];
    reg [15:0] temp_sig;
    
    // Match tracking
    reg match_found [0:15];
    reg [3:0] match_with [0:15];
    reg [3:0] output_idx;
    reg [3:0] output_ptr;
    reg [15:0] processed_sigs [0:15];
    
    // BFS buffer: signatures of neighbors at current depth
    reg [15:0] neighbor_sigs [0:7];
    reg [3:0] valid_neighbors;
    
    // Cycle counter for timeout
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_room <= 4'd0;
            result_match <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            none <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            depth <= 4'd0;
            room_cnt_reg <= 4'd0;
            temp_sig <= 16'd0;
            output_idx <= 4'd0;
            output_ptr <= 4'd0;
            cycle_count <= 12'd0;
            valid_neighbors <= 4'd0;
            
            // Reset arrays
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                stored_degrees[idx] <= 4'd0;
                match_found[idx] <= 1'b0;
                match_with[idx] <= 4'd0;
                processed_sigs[idx] <= 16'd0;
                signatures[idx] <= 16'd0;
                // Reset stored_conns
                for (int n = 0; n < 8; n = n + 1) begin
                    stored_conns[idx][n] <= 4'd0;
                end
            end
            // Reset neighbor_sigs
            for (int n = 0; n < 8; n = n + 1) begin
                neighbor_sigs[n] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            // Default outputs
            result_valid <= 1'b0;
            done <= 1'b0;
            none <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        depth <= 4'd0;
                        cycle_count <= 12'd0;
                        output_idx <= 4'd0;
                        output_ptr <= 4'd0;
                        // Clear previous matches
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            match_found[idx] <= 1'b0;
                            match_with[idx] <= 4'd0;
                            processed_sigs[idx] <= 16'd0;
                            signatures[idx] <= 16'd0;
                        end
                    end
                end

                LOAD: begin
                    if (adjacency_valid) begin
                        stored_degrees[room_idx] <= degree;
                        for (int idx = 0; idx < 8; idx = idx + 1) begin
                            stored_conns[room_idx][idx] <= connections[idx];
                        end
                        i <= i + 4'd1; // Count loaded rooms
                    end
                end

                COMPUTE_INIT: begin
                    // Initial signature: degree (shifted left by 8)
                    signatures[i] <= {stored_degrees[i], 8'd0};
                    i <= i + 4'd1;
                end

                COMPUTE_BFS: begin
                    // BFS expansion to depth 2 (d=0,1,2 -> compute d=1,2,3)
                    // For current room 'i', gather neighbor signatures at current 'depth'
                    
                    if (j < 4'd8 && j < stored_degrees[i]) begin
                        // Check if connection is valid (< n_rooms)
                        if (stored_conns[i][j] < room_cnt_reg) begin
                            neighbor_sigs[j] <= signatures[stored_conns[i][j]];
                        end else begin
                            neighbor_sigs[j] <= 16'd0;
                        end
                        j <= j + 4'd1;
                    end else if (j == 4'd8 || j == stored_degrees[i]) begin
                        // Now sort neighbor_sigs (bubble sort for max 8 elements)
                        // We'll perform 7 passes of sorting
                        // Use k as pass counter
                        if (k < 4'd7 && valid_neighbors > 4'd1) begin
                            if (k < valid_neighbors - 4'd1) begin
                                if (neighbor_sigs[k] > neighbor_sigs[k+1]) begin
                                    // Swap
                                    neighbor_sigs[k] <= neighbor_sigs[k+1];
                                    neighbor_sigs[k+1] <= neighbor_sigs[k];
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            // Hash sorted neighbors into new signature
                            temp_sig <= signatures[i];
                            k <= 4'd0; // Reset k for hash loop
                            j <= 4'd0; // Reset j to indicate hash stage
                            // Determine valid neighbors count
                            if (depth == 4'd0) valid_neighbors <= stored_degrees[i];
                            else valid_neighbors <= (stored_degrees[i] < 8'd8) ? stored_degrees[i] : 8'd8;
                        end
                    end else if (j == 4'd8 && k < 4'd7 && valid_neighbors > 4'd1) begin
                         // Sorting continued (safety)
                         if (k < valid_neighbors - 4'd1) begin
                             if (neighbor_sigs[k] > neighbor_sigs[k+1]) begin
                                 neighbor_sigs[k] <= neighbor_sigs[k+1];
                                 neighbor_sigs[k+1] <= neighbor_sigs[k];
                             end
                         end
                         k <= k + 4'd1;
                    end else if (j == 4'd8 && k >= 4'd7) begin
                         // Hash
                         temp_sig <= ((temp_sig << 1) ^ neighbor_sigs[k]) + 16'h9e37;
                         k <= k + 4'd1;
                         if (k >= valid_neighbors - 4'd1) begin
                             // Done hashing this depth
                             signatures[i] <= temp_sig;
                             depth <= depth + 4'd1;
                             j <= 4'd0;
                             k <= 4'd0;
                             // Check if depth limit reached (depth 2 -> 3 passes)
                             if (depth >= 4'd2) begin
                                 i <= i + 4'd1; // Move to next room
                                 depth <= 4'd0;
                             end
                         end
                    end else if (valid_neighbors <= 4'd1 && j == 4'd8) begin
                         // No neighbors or 1 neighbor, signature stays or simple combine
                         // For 1 neighbor: shift current sig, add neighbor
                         if (valid_neighbors == 4'd1) begin
                            signatures[i] <= (signatures[i] << 1) ^ neighbor_sigs[0];
                         end
                         depth <= depth + 4'd1;
                         j <= 4'd0;
                         if (depth >= 4'd2) begin
                             i <= i + 4'd1;
                             depth <= 4'd0;
                         end
                    end
                end

                COMPARE: begin
                    // Compare signatures[i] with signatures[j] (j > i)
                    if (i < room_cnt_reg) begin
                        if (j < room_cnt_reg) begin
                            if (j > i) begin
                                if (signatures[i] == signatures[j]) begin
                                    // Match found
                                    if (!match_found[j]) begin
                                        match_found[j] <= 1'b1;
                                        match_with[j] <= i;
                                    end
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                end

                OUTPUT: begin
                    // Output matches sequentially
                    if (output_ptr < room_cnt_reg) begin
                        if (match_found[output_ptr]) begin
                            result_room <= output_ptr;
                            result_match <= match_with[output_ptr];
                            result_valid <= 1'b1;
                            output_ptr <= output_ptr + 4'd1;
                        end else begin
                            output_ptr <= output_ptr + 4'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Check if any matches found
                    none <= 1'b1;
                    for (int idx = 0; idx < 16; idx = idx + 1) begin
                        if (match_found[idx]) begin
                            none <= 1'b0;
                        end
                    end
                end
            endcase
            
            // Cycle counter
            if (state != IDLE && !done) begin
                cycle_count <= cycle_count + 12'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default hold
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                // Load until i reaches n_rooms
                // External logic drives adjacency_valid, so we just wait/count
                if (i >= n_rooms && !adjacency_valid) next_state = COMPUTE_INIT;
                else if (i >= n_rooms) next_state = COMPUTE_INIT; // Simplified check
                else if (i >= n_rooms) next_state = COMPUTE_INIT;
                else next_state = LOAD;
                // Wait for start to be low or count up
                // In real implementation, external bus sends data for room 0..n-1
                // We assume sequential loading triggered by adjacency_valid
                // If we loaded all rooms (i == n_rooms), move on
            end
            
            COMPUTE_INIT: begin
                if (i >= n_rooms) next_state = COMPUTE_BFS;
                else next_state = COMPUTE_INIT;
            end
            
            COMPUTE_BFS: begin
                // Complex logic inside always block handles transitions
                // We need a signal to know when done with a room
                // Let's use 'depth' and 'i' state
                if (i >= n_rooms) next_state = COMPARE;
                else next_state = COMPUTE_BFS;
                // Note: The internal logic uses i, depth, j to flow.
            end
            
            COMPARE: begin
                if (i >= n_rooms) next_state = OUTPUT;
                else next_state = COMPARE;
            end
            
            OUTPUT: begin
                if (output_ptr >= n_rooms) next_state = FINISH;
                else next_state = OUTPUT;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout override
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule