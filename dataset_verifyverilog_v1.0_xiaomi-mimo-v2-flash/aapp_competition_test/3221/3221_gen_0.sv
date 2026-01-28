module FindMinEnergyCycle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [4:0] M,
    input wire [4:0] alpha,
    input wire [3:0] edge_u [0:23],
    input wire [3:0] edge_v [0:23],
    input wire [31:0] edge_c [0:23],
    output reg [63:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] LOAD_EDGES  = 4'd1;
    localparam [3:0] CHECK_SUBSET = 4'd2;
    localparam [3:0] CALC_DEGREES = 4'd3;
    localparam [3:0] CHECK_DEG_EVEN = 4'd4;
    localparam [3:0] CHECK_CONNECTED = 4'd5;
    localparam [3:0] FIND_MAX_C   = 4'd6;
    localparam [3:0] CALC_ENERGY  = 4'd7;
    localparam [3:0] UPDATE_MIN   = 4'd8;
    localparam [3:0] NEXT_SUBSET  = 4'd9;
    localparam [3:0] DONE_STATE   = 4'd10;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [23:0] subset_mask;
    reg [23:0] next_subset_mask;
    reg [4:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] subset_size;
    reg [31:0] current_max_c;
    reg [63:0] current_energy;
    reg [63:0] min_energy;
    reg min_valid;
    reg found_valid_subset;
    reg all_even_degrees;
    reg is_connected;
    reg [3:0] degrees [0:15];  // Node degrees
    reg [3:0] visited [0:15];  // DFS visited flags
    reg [3:0] queue [0:15];    // BFS/DFS queue
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [31:0] max_c_temp;
    reg [31:0] temp_val;
    reg [31:0] temp_mult_low;
    reg [63:0] temp_mult_result;
    reg [15:0] max_c_bits;
    reg [63:0] energy_low;
    reg [63:0] energy_high;
    reg [3:0] i;
    reg [4:0] j;
    reg temp_bit;
    reg temp_even;
    reg dfs_done;
    reg [3:0] current_node;
    reg start_bfs_flag;
    reg bfs_complete;
    
    // Edge storage (packed for Icarus compatibility)
    reg [3:0] stored_u [0:23];
    reg [3:0] stored_v [0:23];
    reg [31:0] stored_c [0:23];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            valid <= 1'b0;
            subset_mask <= 24'd0;
            min_energy <= 64'hFFFFFFFFFFFFFFFF;
            min_valid <= 1'b0;
            edge_idx <= 5'd0;
            node_idx <= 4'd0;
            subset_size <= 4'd0;
            current_max_c <= 32'd0;
            current_energy <= 64'd0;
            found_valid_subset <= 1'b0;
            all_even_degrees <= 1'b0;
            is_connected <= 1'b0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            max_c_temp <= 32'd0;
            temp_val <= 32'd0;
            temp_mult_low <= 32'd0;
            temp_mult_result <= 64'd0;
            max_c_bits <= 16'd0;
            energy_low <= 64'd0;
            energy_high <= 64'd0;
            temp_bit <= 1'b0;
            temp_even <= 1'b0;
            dfs_done <= 1'b0;
            current_node <= 4'd0;
            start_bfs_flag <= 1'b0;
            bfs_complete <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                degrees[i] <= 4'd0;
                visited[i] <= 4'd0;
                queue[i] <= 4'd0;
            end
            for (j = 0; j < 24; j = j + 1) begin
                stored_u[j] <= 4'd0;
                stored_v[j] <= 4'd0;
                stored_c[j] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= LOAD_EDGES;
                        edge_idx <= 5'd0;
                        subset_mask <= 24'd0;
                        min_energy <= 64'hFFFFFFFFFFFFFFFF;
                        min_valid <= 1'b0;
                        found_valid_subset <= 1'b0;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_idx < M) begin
                        stored_u[edge_idx[4:0]] <= edge_u[edge_idx[4:0]];
                        stored_v[edge_idx[4:0]] <= edge_v[edge_idx[4:0]];
                        stored_c[edge_idx[4:0]] <= edge_c[edge_idx[4:0]];
                        edge_idx <= edge_idx + 5'd1;
                    end else begin
                        state <= CHECK_SUBSET;
                        edge_idx <= 5'd0;
                        subset_mask <= 24'd0;
                        subset_size <= 4'd0;
                    end
                end

                CHECK_SUBSET: begin
                    if (subset_mask < (24'd1 << M)) begin
                        state <= CALC_DEGREES;
                        edge_idx <= 5'd0;
                        subset_size <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            degrees[i] <= 4'd0;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CALC_DEGREES: begin
                    if (edge_idx < M) begin
                        temp_bit <= subset_mask[edge_idx[4:0]];
                        if (subset_mask[edge_idx[4:0]]) begin
                            // Increment degree for both nodes
                            degrees[stored_u[edge_idx[4:0]]] <= degrees[stored_u[edge_idx[4:0]]] + 4'd1;
                            degrees[stored_v[edge_idx[4:0]]] <= degrees[stored_v[edge_idx[4:0]]] + 4'd1;
                            subset_size <= subset_size + 4'd1;
                        end
                        edge_idx <= edge_idx + 5'd1;
                    end else begin
                        state <= CHECK_DEG_EVEN;
                        node_idx <= 4'd0;
                    end
                end

                CHECK_DEG_EVEN: begin
                    // Check if all degrees are even (Eulerian condition)
                    // Also check if subset is not empty
                    if (subset_size == 4'd0) begin
                        all_even_degrees <= 1'b0;
                        state <= NEXT_SUBSET;
                    end else if (node_idx < N) begin
                        if ((degrees[node_idx] & 4'd1) == 4'd0) begin
                            node_idx <= node_idx + 4'd1;
                        end else begin
                            all_even_degrees <= 1'b0;
                            state <= NEXT_SUBSET;
                        end
                    end else begin
                        all_even_degrees <= 1'b1;
                        state <= CHECK_CONNECTED;
                        start_bfs_flag <= 1'b1;
                    end
                end

                CHECK_CONNECTED: begin
                    if (start_bfs_flag) begin
                        start_bfs_flag <= 1'b0;
                        // Initialize BFS
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 4'd0;
                        end
                        // Find first node with degree > 0
                        current_node <= 4'd0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        bfs_complete <= 1'b0;
                        is_connected <= 1'b0;
                    end else if (!bfs_complete) begin
                        // Find start node
                        if (current_node < N && degrees[current_node] == 4'd0) begin
                            current_node <= current_node + 4'd1;
                        end else if (current_node < N) begin
                            visited[current_node] <= 4'd1;
                            queue[0] <= current_node;
                            queue_tail <= 4'd1;
                            current_node <= 4'd15; // Mark as done
                        end else if (queue_head < queue_tail) begin
                            // Process queue
                            current_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                        end else begin
                            // Check if all nodes with degree > 0 are visited
                            current_node <= 4'd0;
                            bfs_complete <= 1'b1;
                        end
                    end else if (bfs_complete && current_node < N) begin
                        // Check connectivity
                        if ((degrees[current_node] > 4'd0) && (visited[current_node] == 4'd0)) begin
                            is_connected <= 1'b0;
                            state <= NEXT_SUBSET;
                        end else begin
                            current_node <= current_node + 4'd1;
                        end
                    end else if (bfs_complete) begin
                        is_connected <= 1'b1;
                        state <= FIND_MAX_C;
                        edge_idx <= 5'd0;
                        max_c_temp <= 32'd0;
                    end

                    // BFS edge processing (add to queue)
                    if (!bfs_complete && queue_head < queue_tail && current_node != 4'd15) begin
                        for (j = 0; j < M; j = j + 1) begin
                            if (subset_mask[j] && !bfs_complete) begin
                                if (stored_u[j] == current_node && !visited[stored_v[j]]) begin
                                    visited[stored_v[j]] <= 4'd1;
                                    queue[queue_tail] <= stored_v[j];
                                    queue_tail <= queue_tail + 4'd1;
                                end else if (stored_v[j] == current_node && !visited[stored_u[j]]) begin
                                    visited[stored_u[j]] <= 4'd1;
                                    queue[queue_tail] <= stored_u[j];
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                end

                FIND_MAX_C: begin
                    if (edge_idx < M) begin
                        if (subset_mask[edge_idx[4:0]]) begin
                            if (stored_c[edge_idx[4:0]] > max_c_temp) begin
                                max_c_temp <= stored_c[edge_idx[4:0]];
                            end
                        end
                        edge_idx <= edge_idx + 5'd1;
                    end else begin
                        state <= CALC_ENERGY;
                    end
                end

                CALC_ENERGY: begin
                    // Calculate energy = max_c^2 + alpha * K
                    // max_c^2 using shift-add
                    max_c_bits <= max_c_temp[15:0];
                    temp_mult_result <= 64'd0;
                    temp_mult_low <= 32'd0;
                    // Simple multiplication: max_c_temp * max_c_temp
                    temp_mult_result <= max_c_temp * max_c_temp;
                    // alpha * K (alpha is 5-bit, K is subset_size 4-bit)
                    energy_low <= temp_mult_result + ({59'd0, alpha} * {60'd0, subset_size});
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    if (all_even_degrees && is_connected) begin
                        if (energy_low < min_energy) begin
                            min_energy <= energy_low;
                            min_valid <= 1'b1;
                        end
                        found_valid_subset <= 1'b1;
                    end
                    state <= NEXT_SUBSET;
                end

                NEXT_SUBSET: begin
                    subset_mask <= subset_mask + 24'd1;
                    state <= CHECK_SUBSET;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (min_valid && found_valid_subset) begin
                        result <= min_energy;
                        valid <= 1'b1;
                    end else begin
                        result <= 64'd0;
                        valid <= 1'b0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule