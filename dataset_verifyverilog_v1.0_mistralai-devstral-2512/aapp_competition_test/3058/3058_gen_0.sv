module ParallelEvolution(
    input clk,
    input rst_n,
    input start,
    input [7:0] target [0:15],
    input [7:0] fossils [0:7] [0:15],
    input [3:0] num_fossils,
    output reg result_valid,
    output reg [3:0] path1_len,
    output reg [3:0] path2_len,
    output reg [3:0] path1_idx [0:7],
    output reg [3:0] path2_idx [0:7],
    output reg [1:0] status
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ADJ = 3'd1;
    localparam [2:0] CHECK_TARGET = 3'd2;
    localparam [2:0] PARTITION_SEARCH = 3'd3;
    localparam [2:0] PATH_VALIDATION = 3'd4;
    localparam [2:0] OUTPUT_RESULT = 3'd5;
    localparam [2:0] IMPOSSIBLE = 3'd6;

    // Control signals
    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1023;

    // Adjacency matrix (8x8)
    reg [7:0] adj [0:7];
    integer i, j, k;

    // Path storage
    reg [3:0] current_path1 [0:7];
    reg [3:0] current_path2 [0:7];
    reg [3:0] current_path1_len;
    reg [3:0] current_path2_len;

    // Partition tracking
    reg [7:0] partition_mask;
    reg [7:0] partition_idx;

    // String comparison helper
    function automatic [1:0] can_insert;
        input [7:0] src [0:15];
        input [7:0] dest [0:15];
        integer src_idx, dest_idx;
        reg [1:0] result;
        begin
            result = 2'd0;
            src_idx = 0;
            dest_idx = 0;
            while (src_idx < 16 && dest_idx < 16) begin
                if (src[src_idx] == dest[dest_idx]) begin
                    src_idx = src_idx + 1;
                    dest_idx = dest_idx + 1;
                end else begin
                    dest_idx = dest_idx + 1;
                    if (result == 2'd0) begin
                        result = 2'd1;
                    end else begin
                        result = 2'd2;
                        return result;
                    end
                end
            end
            if (src_idx == 16 && dest_idx == 16 && result == 2'd1) begin
                result = 2'd1;
            end else begin
                result = 2'd0;
            end
            return result;
        end
    endfunction

    // Check if fossil can reach target
    reg [7:0] can_reach_target;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            path1_len <= 4'd0;
            path2_len <= 4'd0;
            status <= 2'd0;
            cycle_count <= 10'd0;
            for (i = 0; i < 8; i = i + 1) begin
                path1_idx[i] <= 4'd0;
                path2_idx[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    status <= 2'd0;
                    if (start) begin
                        next_state <= COMPUTE_ADJ;
                        cycle_count <= 10'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_ADJ: begin
                    status <= 2'd2;
                    // Compute adjacency matrix
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i != j && can_insert(fossils[i], fossils[j]) == 2'd1) begin
                                adj[i][j] <= 1'b1;
                            end else begin
                                adj[i][j] <= 1'b0;
                            end
                        end
                    end
                    next_state <= CHECK_TARGET;
                end

                CHECK_TARGET: begin
                    // Check which fossils can reach target
                    for (i = 0; i < 8; i = i + 1) begin
                        if (can_insert(fossils[i], target) == 2'd1) begin
                            can_reach_target[i] <= 1'b1;
                        end else begin
                            can_reach_target[i] <= 1'b0;
                        end
                    end
                    next_state <= PARTITION_SEARCH;
                end

                PARTITION_SEARCH: begin
                    // Try all possible partitions
                    if (partition_idx < 8'd256) begin
                        partition_mask <= partition_idx;
                        partition_idx <= partition_idx + 8'd1;
                        next_state <= PATH_VALIDATION;
                    end else begin
                        next_state <= IMPOSSIBLE;
                    end
                end

                PATH_VALIDATION: begin
                    // Validate current partition
                    reg [3:0] path1_valid;
                    reg [3:0] path2_valid;
                    reg [3:0] path1_count;
                    reg [3:0] path2_count;
                    reg [3:0] path1_indices [0:7];
                    reg [3:0] path2_indices [0:7];

                    // Check path1 (fossils in partition_mask)
                    path1_valid = 4'd0;
                    path1_count = 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (partition_mask[i] && can_reach_target[i]) begin
                            path1_indices[path1_count] = i;
                            path1_count = path1_count + 4'd1;
                        end
                    end

                    // Check path2 (fossils not in partition_mask)
                    path2_valid = 4'd0;
                    path2_count = 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!partition_mask[i] && can_reach_target[i]) begin
                            path2_indices[path2_count] = i;
                            path2_count = path2_count + 4'd1;
                        end
                    end

                    // Check if both paths are valid
                    if (path1_count > 0 && path2_count > 0 && (path1_count + path2_count) == num_fossils) begin
                        // Found valid partition
                        current_path1_len <= path1_count;
                        current_path2_len <= path2_count;
                        for (i = 0; i < 8; i = i + 1) begin
                            current_path1[i] <= path1_indices[i];
                            current_path2[i] <= path2_indices[i];
                        end
                        next_state <= OUTPUT_RESULT;
                    end else begin
                        next_state <= PARTITION_SEARCH;
                    end
                end

                OUTPUT_RESULT: begin
                    result_valid <= 1'b1;
                    status <= 2'd0;
                    path1_len <= current_path1_len;
                    path2_len <= current_path2_len;
                    for (i = 0; i < 8; i = i + 1) begin
                        path1_idx[i] <= current_path1[i];
                        path2_idx[i] <= current_path2[i];
                    end
                    next_state <= IDLE;
                end

                IMPOSSIBLE: begin
                    status <= 2'd1;
                    result_valid <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    status <= 2'd0;
                end
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IMPOSSIBLE;
                status <= 2'd1;
            end
        end
    end

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 8; i = i + 1) begin
                can_reach_target[i] <= 1'b0;
            end
            partition_mask <= 8'd0;
            partition_idx <= 8'd0;
            current_path1_len <= 4'd0;
            current_path2_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                current_path1[i] <= 4'd0;
                current_path2[i] <= 4'd0;
            end
        end
    end

endmodule