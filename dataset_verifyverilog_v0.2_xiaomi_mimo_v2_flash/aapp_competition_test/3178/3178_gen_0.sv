module graph_decoration_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] node_count,
    input wire [3:0] edge_count,
    input wire [2:0] edge_u [0:15],
    input wire [2:0] edge_v [0:15],
    output reg [15:0] min_cost,
    output reg valid,
    output reg error
);

    // Edge costs: 0, 1, or 2 (encoded as 2-bit values: 00=0, 01=1, 10=2)
    reg [1:0] current_costs [0:15];
    reg [4:0] best_cost;
    reg [4:0] current_cost_sum;
    reg [15:0] candidates_tried;
    reg [15:0] active_edges_mask;
    
    // State machine states
    localparam IDLE = 3'b000;
    localparam NEXT_CONFIG = 3'b001;
    localparam CHECK_VALIDITY = 3'b010;
    localparam UPDATE_BEST = 3'b011;
    localparam DONE = 3'b100;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] config_idx;
    reg [4:0] max_config;
    
    // Constraint checking
    reg [2:0] check_node;
    reg [3:0] edge_i;
    reg [3:0] edge_j;
    reg constraint_ok;
    reg [1:0] sum_ab;
    
    // Cycle detection variables
    reg [7:0] visited;
    reg [7:0] in_stack;
    reg [2:0] current_node;
    reg [3:0] cycle_edge_idx;
    reg cycle_found;
    reg odd_cycle_found;
    reg [3:0] dfs_edge_idx;
    reg [2:0] dfs_parent;
    reg [2:0] start_node;
    
    // Temporary variables for modulo calculation
    reg [1:0] temp_sum;
    reg [4:0] temp_calc_sum;
    reg [3:0] temp_idx;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            error <= 0;
            min_cost <= 16'hFFFF;
            best_cost <= 5'h1F;
            config_idx <= 0;
            max_config <= 0;
            candidates_tried <= 0;
            active_edges_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize
                        best_cost <= 5'h1F;
                        config_idx <= 0;
                        candidates_tried <= 0;
                        valid <= 0;
                        error <= 0;
                        
                        // Create active edges mask based on edge_count
                        active_edges_mask <= (edge_count == 0) ? 16'h0000 : 
                                           (edge_count >= 16) ? 16'hFFFF :
                                           ((1 << edge_count) - 1);
                        
                        // Calculate max configurations: 3^edge_count
                        if (edge_count == 0) begin
                            max_config <= 1;
                        end else if (edge_count == 1) begin
                            max_config <= 3;
                        end else if (edge_count == 2) begin
                            max_config <= 9;
                        end else if (edge_count == 3) begin
                            max_config <= 27;
                        end else if (edge_count == 4) begin
                            max_config <= 81;
                        end else if (edge_count == 5) begin
                            max_config <= 243;
                        end else if (edge_count == 6) begin
                            max_config <= 729;
                        end else if (edge_count == 7) begin
                            max_config <= 2187;
                        end else if (edge_count == 8) begin
                            max_config <= 6561;
                        end else begin
                            max_config <= 16'd10000; // Will handle differently
                        end
                        
                        state <= (edge_count == 0) ? DONE : NEXT_CONFIG;
                    end
                end
                
                NEXT_CONFIG: begin
                    if (config_idx >= max_config) begin
                        // All configurations tried
                        if (best_cost == 5'h1F) begin
                            error <= 1;
                        end else begin
                            min_cost <= best_cost;
                            valid <= 1;
                        end
                        state <= DONE;
                    end else begin
                        // Decode configuration and check if tried
                        decode_config(config_idx, current_costs, edge_count);
                        
                        // Move to validity check
                        state <= CHECK_VALIDITY;
                        check_node <= 0;
                        constraint_ok <= 1;
                        edge_i <= 0;
                        edge_j <= 1;
                    end
                end
                
                CHECK_VALIDITY: begin
                    // Check mod-3 constraints for all nodes
                    if (check_node < node_count && constraint_ok) begin
                        // Check pairs of edges incident to this node
                        if (edge_i < edge_count && edge_j < edge_count) begin
                            // Check if both edges are incident to check_node
                            if ((edge_u[edge_i] == check_node || edge_v[edge_i] == check_node) &&
                                (edge_u[edge_j] == check_node || edge_v[edge_j] == check_node) &&
                                (edge_i != edge_j)) begin
                                // Calculate sum
                                temp_sum = current_costs[edge_i] + current_costs[edge_j];
                                if (temp_sum >= 3) temp_sum = temp_sum - 3;
                                if (temp_sum == 1) constraint_ok <= 0;
                            end
                            
                            // Increment edge indices
                            if (edge_j < edge_count - 1) begin
                                edge_j <= edge_j + 1;
                            end else begin
                                edge_j <= edge_i + 2;
                                edge_i <= edge_i + 1;
                                if (edge_i >= edge_count - 2) begin
                                    // Done with this node
                                    check_node <= check_node + 1;
                                    edge_i <= 0;
                                    edge_j <= 1;
                                end
                            end
                        end else begin
                            // Done with this node
                            check_node <= check_node + 1;
                            edge_i <= 0;
                            edge_j <= 1;
                        end
                    end else if (constraint_ok) begin
                        // All nodes checked, now check for odd cycles
                        if (edge_count < 3) begin
                            // No odd cycles possible with less than 3 edges
                            state <= UPDATE_BEST;
                        end else begin
                            // Check for odd cycles
                            odd_cycle_found <= 0;
                            visited <= 0;
                            in_stack <= 0;
                            start_node <= 0;
                            current_node <= 0;
                            cycle_edge_idx <= 0;
                            state <= UPDATE_BEST; // Simplified: skip cycle check for now
                        end
                    end else begin
                        // Constraint violated, skip to next config
                        config_idx <= config_idx + 1;
                        state <= NEXT_CONFIG;
                    end
                end
                
                UPDATE_BEST: begin
                    // Calculate total cost sum
                    temp_calc_sum = 0;
                    for (temp_idx = 0; temp_idx < 16; temp_idx = temp_idx + 1) begin
                        if (temp_idx < edge_count) begin
                            case (current_costs[temp_idx])
                                2'b00: temp_calc_sum = temp_calc_sum + 0;
                                2'b01: temp_calc_sum = temp_calc_sum + 1;
                                2'b10: temp_calc_sum = temp_calc_sum + 2;
                                default: temp_calc_sum = temp_calc_sum + 0;
                            endcase
                        end
                    end
                    current_cost_sum <= temp_calc_sum;
                    
                    // Check if valid and odd sum
                    if (constraint_ok && !odd_cycle_found && temp_calc_sum[0]) begin
                        if (temp_calc_sum < best_cost) begin
                            best_cost <= temp_calc_sum;
                        end
                    end
                    
                    config_idx <= config_idx + 1;
                    state <= NEXT_CONFIG;
                end
                
                DONE: begin
                    // Stay in done state
                end
            endcase
        end
    end
    
    // Task to decode configuration (ternary)
    task automatic decode_config(
        input [4:0] idx,
        output reg [1:0] costs [0:15],
        input [3:0] count
    );
        integer k;
        reg [4:0] temp;
        begin
            temp = idx;
            for (k = 0; k < 16; k = k + 1) begin
                if (k < count) begin
                    costs[k] = temp % 3;
                    temp = temp / 3;
                end else begin
                    costs[k] = 0;
                end
            end
        end
    endtask

endmodule

module graph_decoration_optimizer_wrapper (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [3:0] edge_count,
    input [2:0] edge_u_0, input [2:0] edge_v_0,
    input [2:0] edge_u_1, input [2:0] edge_v_1,
    input [2:0] edge_u_2, input [2:0] edge_v_2,
    input [2:0] edge_u_3, input [2:0] edge_v_3,
    input [2:0] edge_u_4, input [2:0] edge_v_4,
    input [2:0] edge_u_5, input [2:0] edge_v_5,
    input [2:0] edge_u_6, input [2:0] edge_v_6,
    input [2:0] edge_u_7, input [2:0] edge_v_7,
    input [2:0] edge_u_8, input [2:0] edge_v_8,
    input [2:0] edge_u_9, input [2:0] edge_v_9,
    input [2:0] edge_u_10, input [2:0] edge_v_10,
    input [2:0] edge_u_11, input [2:0] edge_v_11,
    input [2:0] edge_u_12, input [2:0] edge_v_12,
    input [2:0] edge_u_13, input [2:0] edge_v_13,
    input [2:0] edge_u_14, input [2:0] edge_v_14,
    input [2:0] edge_u_15, input [2:0] edge_v_15,
    output [15:0] min_cost,
    output valid,
    output error
);
    // Wrapper for edge arrays
    wire [2:0] edge_u [0:15];
    wire [2:0] edge_v [0:15];
    
    assign edge_u[0] = edge_u_0;
    assign edge_u[1] = edge_u_1;
    assign edge_u[2] = edge_u_2;
    assign edge_u[3] = edge_u_3;
    assign edge_u[4] = edge_u_4;
    assign edge_u[5] = edge_u_5;
    assign edge_u[6] = edge_u_6;
    assign edge_u[7] = edge_u_7;
    assign edge_u[8] = edge_u_8;
    assign edge_u[9] = edge_u_9;
    assign edge_u[10] = edge_u_10;
    assign edge_u[11] = edge_u_11;
    assign edge_u[12] = edge_u_12;
    assign edge_u[13] = edge_u_13;
    assign edge_u[14] = edge_u_14;
    assign edge_u[15] = edge_u_15;
    
    assign edge_v[0] = edge_v_0;
    assign edge_v[1] = edge_v_1;
    assign edge_v[2] = edge_v_2;
    assign edge_v[3] = edge_v_3;
    assign edge_v[4] = edge_v_4;
    assign edge_v[5] = edge_v_5;
    assign edge_v[6] = edge_v_6;
    assign edge_v[7] = edge_v_7;
    assign edge_v[8] = edge_v_8;
    assign edge_v[9] = edge_v_9;
    assign edge_v[10] = edge_v_10;
    assign edge_v[11] = edge_v_11;
    assign edge_v[12] = edge_v_12;
    assign edge_v[13] = edge_v_13;
    assign edge_v[14] = edge_v_14;
    assign edge_v[15] = edge_v_15;
    
    graph_decoration_optimizer u0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .node_count(node_count),
        .edge_count(edge_count),
        .edge_u(edge_u),
        .edge_v(edge_v),
        .min_cost(min_cost),
        .valid(valid),
        .error(error)
    );
endmodule