module PartyUnification(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] party,
    input wire [0:63][7:0] edge_data,
    input wire [5:0] num_edges,
    output reg [3:0] result,
    output reg done
);

    // FSM States
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] STEP    = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Frontier Buffer (Circular Buffer)
    reg [15:0] frontier [0:255];
    reg [7:0] frontier_head;
    reg [7:0] frontier_tail;
    reg [7:0] frontier_size;
    reg [15:0] current_state;

    // Visited Lookup Table (256 entries)
    reg [4:0] visited [0:255];
    reg [7:0] visited_count;

    // Adjacency Matrix (16x16)
    reg [15:0] adj_matrix [0:15];

    // Propagation Logic
    reg [15:0] mask;
    reg [3:0] i_reg, j_reg, k_reg;
    reg [15:0] new_state;
    reg [15:0] temp_mask;
    reg [3:0] node;
    reg [3:0] neighbor;
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [3:0] temp_node;
    reg [3:0] temp_neighbor;
    reg [3:0] temp_current_node;
    reg [3:0] temp_next_node;
    reg [3:0] temp_temp_node;
    reg [3:0] temp_temp_neighbor;
    reg [3:0] temp_temp_current_node;
    reg [3:0] temp_temp_next_node;
    reg [3:0] temp_temp_temp_node;
    reg [3:0] temp_temp_temp_neighbor;
    reg [3:0] temp_temp_temp_current_node;
    reg [3:0] temp_temp_temp_next_node;
    reg [3:0] temp_temp_temp_temp_node;
    reg [3:0] temp_temp_temp_temp_neighbor;
    reg [3:0] temp_temp_temp_temp_current_node;
    reg [3:0] temp_temp_temp_temp_next_node;

    // Initialize Adjacency Matrix
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                adj_matrix[idx] <= 16'd0;
            end
        end else if (start) begin
            for (idx = 0; idx < num_edges; idx = idx + 1) begin
                adj_matrix[edge_data[idx][3:0]] <= adj_matrix[edge_data[idx][3:0]] | (1 << edge_data[idx][7:4]);
                adj_matrix[edge_data[idx][7:4]] <= adj_matrix[edge_data[idx][7:4]] | (1 << edge_data[idx][3:0]);
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            frontier_head <= 8'd0;
            frontier_tail <= 8'd0;
            frontier_size <= 8'd0;
            current_state <= 16'd0;
            visited_count <= 8'd0;
            for (idx = 0; idx < 256; idx = idx + 1) begin
                visited[idx] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize frontier with initial state
                    frontier[frontier_tail] <= party;
                    frontier_tail <= (frontier_tail + 8'd1) % 8'd256;
                    frontier_size <= frontier_size + 8'd1;
                    visited[party[7:0]] <= {1'b1, 4'd0};
                    visited_count <= visited_count + 8'd1;
                    current_state <= party;
                    state <= STEP;
                end

                STEP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (frontier_size > 8'd0) begin
                        // Process current state
                        current_state <= frontier[frontier_head];
                        frontier_head <= (frontier_head + 8'd1) % 8'd256;
                        frontier_size <= frontier_size - 8'd1;

                        // Check if unified
                        if ((current_state == 16'd0) || (current_state == 16'hFFFF)) begin
                            result <= cycle_count[3:0];
                            state <= DONE;
                        end else begin
                            // Generate new states by flipping each node
                            for (node = 0; node < 16; node = node + 1) begin
                                // Initialize mask
                                mask <= 16'd0;
                                mask[node] <= 1'b1;

                                // Propagate to connected nodes of same party
                                temp_mask <= mask;
                                for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                                    if (temp_mask[i_reg]) begin
                                        for (j_reg = 0; j_reg < 16; j_reg = j_reg + 1) begin
                                            if (adj_matrix[i_reg][j_reg] && (current_state[j_reg] == current_state[i_reg]) && !temp_mask[j_reg]) begin
                                                temp_mask[j_reg] <= 1'b1;
                                            end
                                        end
                                    end
                                end
                                mask <= temp_mask;

                                // Apply mask to current state
                                new_state <= current_state ^ mask;

                                // Check if new state is unified
                                if ((new_state == 16'd0) || (new_state == 16'hFFFF)) begin
                                    result <= (cycle_count + 8'd1)[3:0];
                                    state <= DONE;
                                end else begin
                                    // Check if visited
                                    if (!visited[new_state[7:0]][4]) begin
                                        visited[new_state[7:0]] <= {1'b1, cycle_count + 8'd1};
                                        visited_count <= visited_count + 8'd1;
                                        frontier[frontier_tail] <= new_state;
                                        frontier_tail <= (frontier_tail + 8'd1) % 8'd256;
                                        frontier_size <= frontier_size + 8'd1;
                                    end
                                end
                            end
                        end
                    end else if (cycle_count >= MAX_CYCLES) begin
                        result <= 4'd0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule