module ParallelEvolutionSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] target [0:15],
    input wire [7:0] fossils [0:7][0:15],
    input wire [3:0] num_fossils,
    output reg result_valid,
    output reg [3:0] path1_len,
    output reg [3:0] path2_len,
    output reg [3:0] path1_idx [0:7],
    output reg [3:0] path2_idx [0:7],
    output reg [1:0] status
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_TARGET  = 3'd1;
    localparam [2:0] BUILD_MATRIX  = 3'd2;
    localparam [2:0] FIND_PARTITIONS = 3'd3;
    localparam [2:0] VERIFY_PATHS  = 3'd4;
    localparam [2:0] OUTPUT_RESULT = 3'd5;
    localparam [2:0] DONE_STATE    = 3'd6;

    // Status codes
    localparam [1:0] STATUS_SUCCESS  = 2'd0;
    localparam [1:0] STATUS_IMPOSSIBLE = 2'd1;
    localparam [1:0] STATUS_PROCESSING = 2'd2;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [7:0] temp_target_len;
    reg [7:0] temp_fossil_lens [0:7];
    reg adj [0:7][0:7];  // Adjacency matrix
    reg can_reach_target [0:7];  // Fossil can reach target
    reg [7:0] partition_mask;  // 8-bit mask for partition
    reg [2:0] temp_path1 [0:7];  // Temporary path storage
    reg [2:0] temp_path2 [0:7];
    reg [2:0] path1_count;
    reg [2:0] path2_count;
    reg valid_partition;
    reg [2:0] search_idx;
    reg [2:0] verify_idx;
    reg [2:0] path_idx;

    // String comparison intermediate
    reg [3:0] compare_i, compare_j;
    reg [3:0] skip_pos;
    reg is_insertion;

    integer i, j, k;

    // Helper function to compute string length (max 16)
    function [7:0] get_str_len;
        input [7:0] str [0:15];
        reg [7:0] len;
        begin
            len = 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (str[i] != 8'd0) begin
                    len = i + 8'd1;
                end
            end
            get_str_len = len;
        end
    endfunction

    // Combinational check: can src become dest with 1 insertion?
    // Assumes dest length = src length + 1
    reg can_insert_one;
    always @(*) begin
        can_insert_one = 1'b0;
        // Check if dest can be formed by inserting 1 char into src
        // Compare src[i] with dest[j], allowing one skip in dest
        if (temp_fossil_lens[search_idx] + 8'd1 == temp_target_len) begin
            // Check alignment
            is_insertion = 1'b1;
            skip_pos = 4'd0;
            for (j = 0; j < 16; j = j + 1) begin
                if (j == temp_fossil_lens[search_idx]) break;
                // Compare fossils[search_idx][j] with target[j+skip]
            end
            // Simplified: just check if strings are close enough
            // We'll use a simple pattern: find one mismatch that aligns
            is_insertion = 1'b1;
            for (j = 0; j < 16; j = j + 1) begin
                if (j >= temp_fossil_lens[search_idx]) begin
                    // End of src, rest of dest must be zero
                    for (k = j; k < 16; k = k + 1) begin
                        if (target[k] != 8'd0) is_insertion = 1'b0;
                    end
                    disable loop1;
                end
            end
            // Actually do proper check
            reg [3:0] src_idx, dst_idx;
            reg mismatch_found;
            src_idx = 4'd0;
            dst_idx = 4'd0;
            mismatch_found = 1'b0;
            for (j = 0; j < 16; j = j + 1) begin
                if (src_idx >= temp_fossil_lens[search_idx]) begin
                    // Source done, rest of target must match (should be only padding)
                    if (target[dst_idx] != 8'd0) is_insertion = 1'b0;
                end else if (dst_idx >= temp_target_len) begin
                    is_insertion = 1'b0;
                end else begin
                    if (fossils[search_idx][src_idx] == target[dst_idx]) begin
                        src_idx = src_idx + 4'd1;
                        dst_idx = dst_idx + 4'd1;
                    end else begin
                        if (mismatch_found) begin
                            is_insertion = 1'b0;
                        end else begin
                            mismatch_found = 1'b1;
                            dst_idx = dst_idx + 4'd1;  // Skip in destination
                        end
                    end
                end
            end
            // Check final condition
            if (is_insertion && !mismatch_found && (temp_target_len == temp_fossil_lens[search_idx])) begin
                // Actually must have one insertion, so mismatch_found should be true
                // But if lengths differ by 1, there MUST be a mismatch somewhere
            end
            can_insert_one = is_insertion && (temp_target_len == temp_fossil_lens[search_idx] + 8'd1);
        end
    end

    // Actually, implement proper combinational comparison
    reg is_valid_insertion;
    reg [3:0] skip_at;
    always @(*) begin
        is_valid_insertion = 1'b0;
        skip_at = 4'd15;  // Default invalid
        // Check if src can become dst with one insertion
        // dst length must be src length + 1
        if (temp_fossil_lens[search_idx] + 8'd1 == temp_target_len) begin
            // Try all possible skip positions
            for (skip_pos = 0; skip_pos <= temp_target_len; skip_pos = skip_pos + 1) begin
                reg valid_pos;
                valid_pos = 1'b1;
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < skip_pos) begin
                        if (fossils[search_idx][i] != target[i]) valid_pos = 1'b0;
                    end else if (i < temp_fossil_lens[search_idx]) begin
                        if (fossils[search_idx][i] != target[i+1]) valid_pos = 1'b0;
                    end
                end
                // Also check the rest of target after src
                for (i = temp_fossil_lens[search_idx]; i < 16; i = i + 1) begin
                    if (i + 1 < 16) begin
                        if (target[i+1] != 8'd0) valid_pos = 1'b0;
                    end
                end
                if (valid_pos) begin
                    is_valid_insertion = 1'b1;
                    skip_at = skip_pos;
                end
            end
        end
    end

    // Path verification check
    reg path_valid;
    always @(*) begin
        path_valid = 1'b1;
        // Check if temp_path forms a valid chain
        // Each consecutive pair must have adjacency
        for (i = 0; i < 7; i = i + 1) begin
            if (i + 1 < path_idx) begin
                if (!adj[temp_path1[i]][temp_path1[i+1]]) begin
                    path_valid = 1'b0;
                end
            end
        end
        // Last element must reach target
        if (path_idx > 0) begin
            if (!can_reach_target[temp_path1[path_idx - 1]]) begin
                path_valid = 1'b0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            status <= STATUS_SUCCESS;
            cycle_count <= 8'd0;
            path1_len <= 4'd0;
            path2_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                path1_idx[i] <= 4'd0;
                path2_idx[i] <= 4'd0;
                temp_fossil_lens[i] <= 8'd0;
                can_reach_target[i] <= 1'b0;
                for (j = 0; j < 8; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
            end
            temp_target_len <= 8'd0;
            partition_mask <= 8'd0;
            search_idx <= 3'd0;
            verify_idx <= 3'd0;
            path_idx <= 3'd0;
            valid_partition <= 1'b0;
            path1_count <= 3'd0;
            path2_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_TARGET;
                        status <= STATUS_PROCESSING;
                        search_idx <= 3'd0;
                    end
                end

                CHECK_TARGET: begin
                    // Compute lengths
                    temp_target_len <= get_str_len(target);
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_fossil_lens[i] <= get_str_len(fossils[i]);
                    end
                    state <= BUILD_MATRIX;
                    search_idx <= 3'd0;
                end

                BUILD_MATRIX: begin
                    // Build adjacency matrix and check reachability to target
                    if (search_idx < num_fossils[2:0]) begin
                        // Check if fossil can reach target
                        search_idx <= search_idx + 3'd1;
                        // Check reachability
                        if (temp_fossil_lens[search_idx] < temp_target_len) begin
                            // Simple check: could be valid
                            can_reach_target[search_idx] <= 1'b1;  // Assume yes for now, will verify later
                        end else begin
                            can_reach_target[search_idx] <= 1'b0;
                        end
                        // Check adjacency to other fossils
                        for (j = 0; j < 8; j = j + 1) begin
                            if (j != search_idx && j < num_fossils[2:0]) begin
                                // Check if fossil search_idx -> fossil j is valid insertion
                                // Only if lengths differ by 1
                                if (temp_fossil_lens[j] == temp_fossil_lens[search_idx] + 8'd1) begin
                                    adj[search_idx][j] <= 1'b1;  // Assume yes
                                end else begin
                                    adj[search_idx][j] <= 1'b0;
                                end
                            end
                        end
                    end else begin
                        state <= FIND_PARTITIONS;
                        partition_mask <= 8'd0;
                        search_idx <= 3'd0;
                    end
                end

                FIND_PARTITIONS: begin
                    // Try all partitions (2^num_fossils)
                    if (partition_mask < (8'd1 << num_fossils[2:0])) begin
                        partition_mask <= partition_mask + 8'd1;
                        state <= VERIFY_PATHS;
                        verify_idx <= 3'd0;
                        path_idx <= 3'd0;
                        path1_count <= 3'd0;
                        path2_count <= 3'd0;
                        valid_partition <= 1'b1;
                    end else begin
                        // No valid partition found
                        state <= OUTPUT_RESULT;
                        status <= STATUS_IMPOSSIBLE;
                    end
                end

                VERIFY_PATHS: begin
                    // Verify current partition
                    if (verify_idx < num_fossils[2:0]) begin
                        verify_idx <= verify_idx + 3'd1;
                        if (partition_mask[verify_idx]) begin
                            // Add to path 1
                            temp_path1[path1_count] <= verify_idx;
                            path1_count <= path1_count + 3'd1;
                        end else begin
                            // Add to path 2
                            temp_path2[path2_count] <= verify_idx;
                            path2_count <= path2_count + 3'd1;
                        end
                    end else begin
                        // Check if both paths are valid
                        // Path 1 check
                        if (path1_count > 0) begin
                            path_idx <= path1_count;
                            // Check adjacency chain
                            reg valid_path1;
                            valid_path1 = 1'b1;
                            for (i = 0; i < 7; i = i + 1) begin
                                if (i + 1 < path1_count) begin
                                    if (!adj[temp_path1[i]][temp_path1[i+1]]) begin
                                        valid_path1 = 1'b0;
                                    end
                                end
                            end
                            if (valid_path1 && can_reach_target[temp_path1[path1_count-1]]) begin
                                // Path 1 valid
                            end else begin
                                valid_partition <= 1'b0;
                            end
                        end
                        // Path 2 check
                        if (path2_count > 0 && valid_partition) begin
                            reg valid_path2;
                            valid_path2 = 1'b1;
                            for (i = 0; i < 7; i = i + 1) begin
                                if (i + 1 < path2_count) begin
                                    if (!adj[temp_path2[i]][temp_path2[i+1]]) begin
                                        valid_path2 = 1'b0;
                                    end
                                end
                            end
                            if (valid_path2 && can_reach_target[temp_path2[path2_count-1]]) begin
                                // Path 2 valid
                            end else begin
                                valid_partition <= 1'b0;
                            end
                        end
                        // Check empty path case
                        if (path1_count == 0 && path2_count == 0) begin
                            // No fossils - invalid
                            valid_partition <= 1'b0;
                        end
                        state <= OUTPUT_RESULT;
                        if (valid_partition) begin
                            status <= STATUS_SUCCESS;
                        end else begin
                            status <= STATUS_PROCESSING;
                            state <= FIND_PARTITIONS;
                        end
                    end
                end

                OUTPUT_RESULT: begin
                    if (status == STATUS_SUCCESS) begin
                        // Copy results
                        path1_len <= path1_count;
                        path2_len <= path2_count;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < path1_count) begin
                                path1_idx[i] <= temp_path1[i];
                            end else begin
                                path1_idx[i] <= 4'd0;
                            end
                            if (i < path2_count) begin
                                path2_idx[i] <= temp_path2[i];
                            end else begin
                                path2_idx[i] <= 4'd0;
                            end
                        end
                        result_valid <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        // Status is impossible or still searching
                        if (status == STATUS_IMPOSSIBLE) begin
                            result_valid <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            state <= FIND_PARTITIONS;
                        end
                    end
                end

                DONE_STATE: begin
                    // Hold done state
                    result_valid <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            // Cycle counter
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= OUTPUT_RESULT;
                status <= STATUS_IMPOSSIBLE;
            end
        end
    end

endmodule