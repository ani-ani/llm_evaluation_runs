module maze_isomorphism(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_rooms,
    input adjacency_valid,
    input [3:0] room_idx,
    input [3:0] degree,
    input [3:0] connections [0:7],
    output reg [3:0] result_room,
    output reg [3:0] result_match,
    output reg result_valid,
    output reg done,
    output reg none
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Internal storage for adjacency data
    reg [3:0] degrees [0:15];
    reg [3:0] conn [0:15][0:7];

    // Loading phase counters
    reg [3:0] load_counter;
    reg [3:0] current_room;

    // Computation phase
    reg [3:0] compute_room;
    reg [31:0] signatures [0:15];

    // Output phase
    reg [3:0] output_room;
    reg [3:0] output_match;
    reg [3:0] output_counter;
    reg [3:0] match_index;

    // Match tracking
    reg [3:0] match_sets [0:15][0:15];
    reg [3:0] set_sizes [0:15];
    reg [3:0] set_count;

    // Cycle counter for safety
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1900;

    // BFS computation
    reg [3:0] bfs_depth;
    reg [3:0] bfs_current [0:15];
    reg [3:0] bfs_next [0:15];
    reg [3:0] bfs_count;
    reg [3:0] bfs_temp_sig;

    // Sorting network for neighbor signatures (bubble sort for small arrays)
    reg [31:0] sort_array [0:7];
    reg [3:0] sort_i, sort_j;
    reg sort_swapped;

    // Hash computation
    reg [31:0] hash_temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            load_counter <= 4'd0;
            current_room <= 4'd0;
            compute_room <= 4'd0;
            output_room <= 4'd0;
            output_match <= 4'd0;
            output_counter <= 4'd0;
            match_index <= 4'd0;
            set_count <= 4'd0;
            cycle_count <= 11'd0;
            bfs_depth <= 4'd0;
            bfs_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_swapped <= 1'b0;
            result_room <= 4'd0;
            result_match <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            none <= 1'b0;

            // Initialize storage
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                degrees[i] <= 4'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    conn[i][j] <= 4'd0;
                end
            end

            // Initialize signatures
            for (i = 0; i < 16; i = i + 1) begin
                signatures[i] <= 32'd0;
            end

            // Initialize match tracking
            for (i = 0; i < 16; i = i + 1) begin
                set_sizes[i] <= 4'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    match_sets[i][j] <= 4'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 11'd1;

            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    none <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        load_counter <= 4'd0;
                        current_room <= 4'd0;
                    end
                end

                LOAD: begin
                    if (adjacency_valid) begin
                        degrees[current_room] <= degree;
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            conn[current_room][j] <= connections[j];
                        end
                        load_counter <= load_counter + 4'd1;
                        current_room <= current_room + 4'd1;
                    end

                    if (load_counter >= n_rooms) begin
                        next_state <= COMPUTE;
                        compute_room <= 4'd0;
                    end
                end

                COMPUTE: begin
                    // Compute signature for current room
                    if (bfs_depth == 4'd0) begin
                        // Depth 0: just the degree
                        signatures[compute_room] <= {28'd0, degrees[compute_room]};
                        bfs_depth <= 4'd1;
                        bfs_count <= degrees[compute_room];
                        // Initialize BFS queue
                        integer j;
                        for (j = 0; j < 15; j = j + 1) begin
                            bfs_current[j] <= 4'd0;
                        end
                        for (j = 0; j < degrees[compute_room]; j = j + 1) begin
                            bfs_current[j] <= conn[compute_room][j];
                        end
                    end else if (bfs_depth == 4'd1) begin
                        // Depth 1: collect neighbor degrees
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            sort_array[j] <= 32'd0;
                        end
                        for (j = 0; j < bfs_count; j = j + 1) begin
                            sort_array[j] <= {28'd0, degrees[bfs_current[j]]};
                        end
                        // Sort the array
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        sort_swapped <= 1'b1;
                        next_state <= COMPUTE;
                    end else if (bfs_depth == 4'd2) begin
                        // Depth 2: collect neighbor-of-neighbor degrees
                        integer j, k;
                        for (j = 0; j < 8; j = j + 1) begin
                            sort_array[j] <= 32'd0;
                        end
                        for (j = 0; j < bfs_count; j = j + 1) begin
                            reg [3:0] neighbor = bfs_current[j];
                            for (k = 0; k < degrees[neighbor]; k = k + 1) begin
                                if (k < 8) begin
                                    sort_array[k] <= sort_array[k] + {28'd0, degrees[conn[neighbor][k]]};
                                end
                            end
                        end
                        // Sort the array
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        sort_swapped <= 1'b1;
                        next_state <= COMPUTE;
                    end else if (bfs_depth == 4'd3) begin
                        // Compute hash
                        hash_temp <= 32'd0;
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            hash_temp <= hash_temp ^ (sort_array[j] << (j * 4));
                        end
                        signatures[compute_room] <= hash_temp;
                        // Move to next room
                        compute_room <= compute_room + 4'd1;
                        bfs_depth <= 4'd0;
                        if (compute_room >= n_rooms) begin
                            next_state <= OUTPUT;
                            output_room <= 4'd0;
                            output_match <= 4'd0;
                            output_counter <= 4'd0;
                            match_index <= 4'd0;
                            set_count <= 4'd0;
                        end
                    end

                    // Sorting network
                    if (sort_swapped) begin
                        if (sort_j < 7) begin
                            if (sort_array[sort_j] > sort_array[sort_j + 1]) begin
                                reg [31:0] temp = sort_array[sort_j];
                                sort_array[sort_j] <= sort_array[sort_j + 1];
                                sort_array[sort_j + 1] <= temp;
                                sort_swapped <= 1'b1;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            if (sort_i < 6) begin
                                sort_i <= sort_i + 4'd1;
                            end else begin
                                sort_swapped <= 1'b0;
                                bfs_depth <= bfs_depth + 4'd1;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    // Find matches
                    if (output_counter == 4'd0) begin
                        // Find next room with matches
                        integer i, j;
                        reg found = 1'b0;
                        for (i = output_room; i < n_rooms; i = i + 1) begin
                            for (j = i + 1; j < n_rooms; j = j + 1) begin
                                if (signatures[i] == signatures[j] && signatures[i] != 32'd0) begin
                                    output_room <= i;
                                    output_match <= j;
                                    found = 1'b1;
                                    break;
                                end
                            end
                            if (found) break;
                        end
                        if (!found) begin
                            none <= 1'b1;
                            next_state <= DONE_STATE;
                        end else begin
                            result_room <= output_room;
                            result_match <= output_match;
                            result_valid <= 1'b1;
                            output_counter <= 4'd1;
                        end
                    end else begin
                        result_valid <= 1'b0;
                        output_counter <= 4'd0;
                        output_room <= output_room + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Safety: timeout
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
            end
        end
    end

endmodule