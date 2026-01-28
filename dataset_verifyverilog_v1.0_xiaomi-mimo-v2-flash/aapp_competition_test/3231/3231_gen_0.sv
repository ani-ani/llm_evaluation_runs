module group_validator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] adj [0:15],
    input wire [3:0] n,
    input wire [3:0] p,
    input wire [3:0] q,
    output reg valid,
    output reg done,
    output reg [63:0] partition,
    output reg [3:0] group_count,
    output reg [255:0] groups
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_PARTITION = 3'd1;
    localparam [2:0] UPDATE       = 3'd2;
    localparam [2:0] VALIDATE     = 3'd3;
    localparam [2:0] DONE_STATE   = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] candidate_partition;
    reg [15:0] best_partition;
    reg [3:0] best_group_count;
    reg [255:0] best_groups;
    reg candidate_valid;
    reg [15:0] partition_counter;
    reg [3:0] i, j, k;
    reg [3:0] node_group;
    reg [3:0] group_sizes [0:15];
    reg [3:0] edge_count;
    reg [3:0] max_group_id;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            partition <= 64'd0;
            group_count <= 4'd0;
            groups <= 256'd0;
            candidate_partition <= 16'd0;
            best_partition <= 16'd0;
            best_group_count <= 4'd0;
            best_groups <= 256'd0;
            candidate_valid <= 1'b0;
            partition_counter <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            node_group <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                group_sizes[i] <= 4'd0;
            end
            edge_count <= 4'd0;
            max_group_id <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    partition_counter <= 16'd0;
                    best_partition <= 16'd0;
                    best_group_count <= 4'd0;
                    best_groups <= 256'd0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= CHECK_PARTITION;
                    end
                end

                CHECK_PARTITION: begin
                    // Generate candidate partition from binary counter
                    // Each node gets a group ID from 0 to (partition_counter bits)
                    // This is a simplified encoding: use bits as group assignment
                    // For n nodes, we use the first n bits of counter to assign groups
                    // Each bit i corresponds to a group choice
                    // For simplicity, we treat bit i as group ID 0 or 1
                    // Better: use counter to enumerate all partitions
                    // Since 2^n possibilities, we just check each partition
                    // Partition encoding: 16-bit where each 4-bit chunk is group ID
                    // We'll generate partition by incrementing counter and mapping
                    // For each node i (0 to n-1), group = partition_counter[i*4 +: 4]
                    // But this is too many. Instead, treat counter as group index
                    // Each node i gets group = (partition_counter >> (i*1)) & 1
                    // Actually, use each bit to decide binary group
                    // We'll just use binary encoding for simplicity
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            candidate_partition[i*4 +: 4] <= {3'd0, partition_counter[i]};
                        end else begin
                            candidate_partition[i*4 +: 4] <= 4'd0;
                        end
                    end
                    state <= VALIDATE;
                end

                VALIDATE: begin
                    // Reset group sizes and edge count
                    for (k = 0; k < 16; k = k + 1) begin
                        group_sizes[k] <= 4'd0;
                    end
                    edge_count <= 4'd0;
                    max_group_id <= 4'd0;
                    // Compute group sizes and max group ID
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            node_group <= candidate_partition[i*4 +: 4];
                            // Increment group size
                            if (node_group < 16) begin
                                group_sizes[node_group] <= group_sizes[node_group] + 4'd1;
                            end
                            // Track max group ID
                            if (node_group > max_group_id) begin
                                max_group_id <= node_group;
                            end
                        end
                    end
                    // Check group sizes <= p
                    candidate_valid <= 1'b1;
                    for (k = 0; k < 16; k = k + 1) begin
                        if (group_sizes[k] > p && group_sizes[k] != 0) begin
                            candidate_valid <= 1'b0;
                        end
                    end
                    // Check number of groups <= 16 (always true)
                    // Cross edges calculation
                    if (candidate_valid) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                for (j = i + 1; j < 16; j = j + 1) begin
                                    if (j < n) begin
                                        if (adj[i][j]) begin
                                            if (candidate_partition[i*4 +: 4] != candidate_partition[j*4 +: 4]) begin
                                                edge_count <= edge_count + 4'd1;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    // Final check
                    if (candidate_valid && (edge_count <= q)) begin
                        best_partition <= candidate_partition;
                        best_group_count <= max_group_id + 4'd1;
                        // Compute groups mask
                        best_groups <= 256'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                node_group <= candidate_partition[i*4 +: 4];
                                // Set bit i in the group mask
                                best_groups[node_group*16 + i] <= 1'b1;
                            end
                        end
                        valid <= 1'b1;
                    end
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Increment partition counter
                    if (partition_counter < 16'hFFFF) begin
                        partition_counter <= partition_counter + 16'd1;
                        state <= CHECK_PARTITION;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (valid) begin
                        partition <= {48'd0, best_partition};
                        group_count <= best_group_count;
                        groups <= best_groups;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule