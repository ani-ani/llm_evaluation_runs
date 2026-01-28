module BFS_Shortest_Path (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s,
    input wire [3:0] t,
    input wire [15:0] type_i,
    input wire [15:0] len_i_0, input wire [15:0] len_i_1, input wire [15:0] len_i_2, input wire [15:0] len_i_3,
    input wire [15:0] len_i_4, input wire [15:0] len_i_5, input wire [15:0] len_i_6, input wire [15:0] len_i_7,
    input wire [15:0] len_i_8, input wire [15:0] len_i_9, input wire [15:0] len_i_10, input wire [15:0] len_i_11,
    input wire [15:0] len_i_12, input wire [15:0] len_i_13, input wire [15:0] len_i_14, input wire [15:0] len_i_15,
    input wire [63:0] list_i_0, input wire [63:0] list_i_1, input wire [63:0] list_i_2, input wire [63:0] list_i_3,
    input wire [63:0] list_i_4, input wire [63:0] list_i_5, input wire [63:0] list_i_6, input wire [63:0] list_i_7,
    input wire [63:0] list_i_8, input wire [63:0] list_i_9, input wire [63:0] list_i_10, input wire [63:0] list_i_11,
    input wire [63:0] list_i_12, input wire [63:0] list_i_13, input wire [63:0] list_i_14, input wire [63:0] list_i_15,
    output reg [4:0] result,
    output reg valid,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_QUEUE = 3'd2;
    localparam [2:0] PROCESS_NODE = 3'd3;
    localparam [2:0] EXPAND = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    
    // Internal Registers
    reg [15:0] visited;
    reg [15:0] in_queue;
    reg [4:0] dist [0:15]; // 16 nodes, distance 0-16 (5 bits)
    reg [4:0] queue [0:15]; // FIFO for BFS queue
    reg [3:0] q_head, q_tail, q_size;
    reg [3:0] current_node;
    reg [3:0] processed_count;
    reg [3:0] cycle_counter;
    
    // Temporary registers for processing
    reg [3:0] neighbor_idx;
    reg [3:0] adj_len;
    reg adj_type;
    reg [63:0] adj_list;
    reg [3:0] list_idx;
    reg [3:0] found_neighbor;
    
    // Loop counters
    integer i;

    // FSM Synchronization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 5'd0;
            visited <= 16'd0;
            in_queue <= 16'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            q_size <= 4'd0;
            current_node <= 4'd0;
            processed_count <= 4'd0;
            cycle_counter <= 4'd0;
            neighbor_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 5'd16;
                queue[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_counter <= 4'd0;
                end
                INIT: begin
                    // Reset BFS structures
                    visited <= 16'd0;
                    in_queue <= 16'd0;
                    q_head <= 4'd0;
                    q_tail <= 4'd0;
                    q_size <= 4'd0;
                    processed_count <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        dist[i] <= 5'd16;
                        queue[i] <= 4'd0;
                    end
                    // Enqueue source
                    queue[0] <= s;
                    q_tail <= 4'd1;
                    q_size <= 4'd1;
                    dist[s] <= 5'd0;
                    in_queue[s] <= 1'b1;
                    visited[s] <= 1'b1;
                end
                CHECK_QUEUE: begin
                    cycle_counter <= cycle_counter + 4'd1;
                end
                PROCESS_NODE: begin
                    // Dequeue
                    current_node <= queue[q_head];
                    q_head <= q_head + 4'd1;
                    q_size <= q_size - 4'd1;
                    // Load adjacency info
                    processed_count <= processed_count + 4'd1;
                    case (queue[q_head])
                        4'd0: begin adj_type <= type_i[0]; adj_len <= len_i_0[3:0]; adj_list <= list_i_0; end
                        4'd1: begin adj_type <= type_i[1]; adj_len <= len_i_1[3:0]; adj_list <= list_i_1; end
                        4'd2: begin adj_type <= type_i[2]; adj_len <= len_i_2[3:0]; adj_list <= list_i_2; end
                        4'd3: begin adj_type <= type_i[3]; adj_len <= len_i_3[3:0]; adj_list <= list_i_3; end
                        4'd4: begin adj_type <= type_i[4]; adj_len <= len_i_4[3:0]; adj_list <= list_i_4; end
                        4'd5: begin adj_type <= type_i[5]; adj_len <= len_i_5[3:0]; adj_list <= list_i_5; end
                        4'd6: begin adj_type <= type_i[6]; adj_len <= len_i_6[3:0]; adj_list <= list_i_6; end
                        4'd7: begin adj_type <= type_i[7]; adj_len <= len_i_7[3:0]; adj_list <= list_i_7; end
                        4'd8: begin adj_type <= type_i[8]; adj_len <= len_i_8[3:0]; adj_list <= list_i_8; end
                        4'd9: begin adj_type <= type_i[9]; adj_len <= len_i_9[3:0]; adj_list <= list_i_9; end
                        4'd10: begin adj_type <= type_i[10]; adj_len <= len_i_10[3:0]; adj_list <= list_i_10; end
                        4'd11: begin adj_type <= type_i[11]; adj_len <= len_i_11[3:0]; adj_list <= list_i_11; end
                        4'd12: begin adj_type <= type_i[12]; adj_len <= len_i_12[3:0]; adj_list <= list_i_12; end
                        4'd13: begin adj_type <= type_i[13]; adj_len <= len_i_13[3:0]; adj_list <= list_i_13; end
                        4'd14: begin adj_type <= type_i[14]; adj_len <= len_i_14[3:0]; adj_list <= list_i_14; end
                        4'd15: begin adj_type <= type_i[15]; adj_len <= len_i_15[3:0]; adj_list <= list_i_15; end
                        default: begin adj_type <= 1'b0; adj_len <= 4'd0; adj_list <= 64'd0; end
                    endcase
                    neighbor_idx <= 4'd0;
                    list_idx <= 4'd0;
                end
                EXPAND: begin
                    // Process neighbors
                    // N-type: iterate through list
                    // C-type: iterate 0-15, skip if in list
                    if (adj_type == 1'b0) begin // N-type
                        if (neighbor_idx < adj_len) begin
                            found_neighbor <= adj_list[neighbor_idx*4 +: 4];
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end
                    end else begin // C-type
                        if (neighbor_idx < 4'd16) begin
                            // Check if neighbor_idx is in the exclusion list
                            if (list_idx < adj_len && adj_list[list_idx*4 +: 4] == neighbor_idx) begin
                                list_idx <= list_idx + 4'd1; // Advance list, skip this neighbor
                            end else begin
                                found_neighbor <= neighbor_idx;
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end
                    end
                    // Update distance and queue if valid neighbor found in this cycle
                    // (Logic simplified: we update based on found_neighbor set in previous EXPAND cycle)
                end
                FINISH: begin
                    if (dist[t] < 5'd16) begin
                        result <= dist[t];
                        valid <= 1'b1;
                    end else begin
                        result <= 5'd0;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                end
            endcase
            
            // Post-processing update for EXPAND state (to avoid combinatorial logic)
            if (state == EXPAND) begin
                // Update logic: only if we found a valid neighbor in the previous step
                // Note: This is a simplified update logic. 
                // In real hardware, we might need a delay register or combinational check.
                // Here, we assume 'found_neighbor' holds the valid neighbor from previous cycle.
                // To be safe, we perform updates based on current state checks.
            end
        end
    end

    // Combinational Logic for Next State and Updates
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = CHECK_QUEUE;
            CHECK_QUEUE: begin
                if (cycle_counter >= 8'd200) next_state = FINISH; // Safety timeout
                else if (q_size == 4'd0) next_state = FINISH;
                else next_state = PROCESS_NODE;
            end
            PROCESS_NODE: next_state = EXPAND;
            EXPAND: begin
                // Determine when expansion is done
                if (adj_type == 1'b0) begin
                    if (neighbor_idx >= adj_len) next_state = CHECK_QUEUE;
                    else next_state = EXPAND;
                end else begin
                    if (neighbor_idx >= 4'd16) next_state = CHECK_QUEUE;
                    else next_state = EXPAND;
                end
            end
            FINISH: if (done) next_state = IDLE; else next_state = FINISH; // Wait one cycle for done pulse
            default: next_state = IDLE;
        endcase
    end

    // Neighbor Update Logic (Separated for clarity)
    // This block handles the actual graph updates based on 'found_neighbor'
    // We trigger updates only when 'found_neighbor' is valid and state is EXPAND
    reg update_trigger;
    always @(posedge clk) begin
        if (!rst_n) begin
            update_trigger <= 1'b0;
        end else begin
            update_trigger <= 1'b0;
            if (state == EXPAND) begin
                // Check if current iteration finds a neighbor
                // For N-type: if neighbor_idx < adj_len
                // For C-type: if neighbor_idx < 16 AND not in exclusion list
                if (adj_type == 1'b0) begin
                    if (neighbor_idx < adj_len) update_trigger <= 1'b1;
                end else begin
                    if (neighbor_idx < 4'd16 && !(list_idx < adj_len && adj_list[list_idx*4 +: 4] == neighbor_idx)) begin
                        update_trigger <= 1'b1;
                    end
                end
            end
        end
    end

    // Update logic for distances and queue
    always @(posedge clk) begin
        if (state == EXPAND && update_trigger) begin
            if (!visited[found_neighbor] && !in_queue[found_neighbor]) begin
                dist[found_neighbor] <= dist[current_node] + 5'd1;
                queue[q_tail] <= found_neighbor;
                q_tail <= q_tail + 4'd1;
                q_size <= q_size + 4'd1;
                visited[found_neighbor] <= 1'b1;
                in_queue[found_neighbor] <= 1'b1;
            end
        end
    end

endmodule