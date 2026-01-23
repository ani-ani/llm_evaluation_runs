module TrainPathPlanner (
    input clk,
    input rst_n,
    input start,
    input [5:0] origin,      // 6-bit node ID (0-63)
    input [5:0] destination, // 6-bit node ID (0-63)
    input [3:0] num_edges,   // Number of edges (1-16)
    input [5:0] edge_from_0,
    input [5:0] edge_from_1,
    input [5:0] edge_from_2,
    input [5:0] edge_from_3,
    input [5:0] edge_from_4,
    input [5:0] edge_from_5,
    input [5:0] edge_from_6,
    input [5:0] edge_from_7,
    input [5:0] edge_from_8,
    input [5:0] edge_from_9,
    input [5:0] edge_from_10,
    input [5:0] edge_from_11,
    input [5:0] edge_from_12,
    input [5:0] edge_from_13,
    input [5:0] edge_from_14,
    input [5:0] edge_from_15,
    input [5:0] edge_to_0,
    input [5:0] edge_to_1,
    input [5:0] edge_to_2,
    input [5:0] edge_to_3,
    input [5:0] edge_to_4,
    input [5:0] edge_to_5,
    input [5:0] edge_to_6,
    input [5:0] edge_to_7,
    input [5:0] edge_to_8,
    input [5:0] edge_to_9,
    input [5:0] edge_to_10,
    input [5:0] edge_to_11,
    input [5:0] edge_to_12,
    input [5:0] edge_to_13,
    input [5:0] edge_to_14,
    input [5:0] edge_to_15,
    input [7:0] edge_dep_0,
    input [7:0] edge_dep_1,
    input [7:0] edge_dep_2,
    input [7:0] edge_dep_3,
    input [7:0] edge_dep_4,
    input [7:0] edge_dep_5,
    input [7:0] edge_dep_6,
    input [7:0] edge_dep_7,
    input [7:0] edge_dep_8,
    input [7:0] edge_dep_9,
    input [7:0] edge_dep_10,
    input [7:0] edge_dep_11,
    input [7:0] edge_dep_12,
    input [7:0] edge_dep_13,
    input [7:0] edge_dep_14,
    input [7:0] edge_dep_15,
    input [15:0] edge_time_0,
    input [15:0] edge_time_1,
    input [15:0] edge_time_2,
    input [15:0] edge_time_3,
    input [15:0] edge_time_4,
    input [15:0] edge_time_5,
    input [15:0] edge_time_6,
    input [15:0] edge_time_7,
    input [15:0] edge_time_8,
    input [15:0] edge_time_9,
    input [15:0] edge_time_10,
    input [15:0] edge_time_11,
    input [15:0] edge_time_12,
    input [15:0] edge_time_13,
    input [15:0] edge_time_14,
    input [15:0] edge_time_15,
    input [15:0] edge_p_0,
    input [15:0] edge_p_1,
    input [15:0] edge_p_2,
    input [15:0] edge_p_3,
    input [15:0] edge_p_4,
    input [15:0] edge_p_5,
    input [15:0] edge_p_6,
    input [15:0] edge_p_7,
    input [15:0] edge_p_8,
    input [15:0] edge_p_9,
    input [15:0] edge_p_10,
    input [15:0] edge_p_11,
    input [15:0] edge_p_12,
    input [15:0] edge_p_13,
    input [15:0] edge_p_14,
    input [15:0] edge_p_15,
    input [15:0] edge_d_0,
    input [15:0] edge_d_1,
    input [15:0] edge_d_2,
    input [15:0] edge_d_3,
    input [15:0] edge_d_4,
    input [15:0] edge_d_5,
    input [15:0] edge_d_6,
    input [15:0] edge_d_7,
    input [15:0] edge_d_8,
    input [15:0] edge_d_9,
    input [15:0] edge_d_10,
    input [15:0] edge_d_11,
    input [15:0] edge_d_12,
    input [15:0] edge_d_13,
    input [15:0] edge_d_14,
    input [15:0] edge_d_15,
    output reg [15:0] result,       // Expected duration in Q8.8
    output reg done,
    output reg impossible
);

// Parameters
localparam [3:0] MAX_NODES = 4'd8;
localparam [3:0] MAX_EDGES = 4'd16;

// Internal state
reg [5:0] node_state_0;
reg [5:0] node_state_1;
reg [5:0] node_state_2;
reg [5:0] node_state_3;
reg [5:0] node_state_4;
reg [5:0] node_state_5;
reg [5:0] node_state_6;
reg [5:0] node_state_7; // 0=unvisited, 1=visiting, 2=done
reg [15:0] expected_time_0;
reg [15:0] expected_time_1;
reg [15:0] expected_time_2;
reg [15:0] expected_time_3;
reg [15:0] expected_time_4;
reg [15:0] expected_time_5;
reg [15:0] expected_time_6;
reg [15:0] expected_time_7; // Q8.8
reg [5:0] current_node;
reg [3:0] edge_counter;
reg [3:0] processed_edges;

// Temporary registers
reg [15:0] new_time;
reg [15:0] wait_time;
reg [15:0] base_time;
reg [15:0] delay_expected;
reg [15:0] prob_factor;
reg [15:0] no_delay_prob;
reg [15:0] delay_prob;
reg [15:0] best_time;
reg [3:0] min_idx;
reg [5:0] edge_from_curr;
reg [5:0] edge_to_curr;
reg [15:0] edge_time_curr;
reg [15:0] edge_p_curr;
reg [15:0] edge_d_curr;

// State machine states
reg [3:0] state;
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT = 4'd1;
localparam [3:0] SELECT_NODE = 4'd2;
localparam [3:0] CHECK_NODE = 4'd3;
localparam [3:0] PROCESS_EDGES = 4'd4;
localparam [3:0] PROCESS_EDGE = 4'd5;
localparam [3:0] UPDATE_NODE = 4'd6;
localparam [3:0] FINISHED = 4'd7;
localparam [3:0] IMPOSSIBLE_STATE = 4'd8;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 16'd0;
        node_state_0 <= 6'd0;
        node_state_1 <= 6'd0;
        node_state_2 <= 6'd0;
        node_state_3 <= 6'd0;
        node_state_4 <= 6'd0;
        node_state_5 <= 6'd0;
        node_state_6 <= 6'd0;
        node_state_7 <= 6'd0;
        expected_time_0 <= 16'd0;
        expected_time_1 <= 16'd0;
        expected_time_2 <= 16'd0;
        expected_time_3 <= 16'd0;
        expected_time_4 <= 16'd0;
        expected_time_5 <= 16'd0;
        expected_time_6 <= 16'd0;
        expected_time_7 <= 16'd0;
        current_node <= 6'd0;
        edge_counter <= 4'd0;
        processed_edges <= 4'd0;
        best_time <= 16'd0;
        min_idx <= 4'd0;
        edge_from_curr <= 6'd0;
        edge_to_curr <= 6'd0;
        edge_time_curr <= 16'd0;
        edge_p_curr <= 16'd0;
        edge_d_curr <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                    done <= 1'b0;
                    impossible <= 1'b0;
                end
            end
            
            INIT: begin
                // Initialize node states and expected times
                node_state_0 <= (origin == 6'd0) ? 6'd0 : 6'd0;
                node_state_1 <= (origin == 6'd1) ? 6'd0 : 6'd0;
                node_state_2 <= (origin == 6'd2) ? 6'd0 : 6'd0;
                node_state_3 <= (origin == 6'd3) ? 6'd0 : 6'd0;
                node_state_4 <= (origin == 6'd4) ? 6'd0 : 6'd0;
                node_state_5 <= (origin == 6'd5) ? 6'd0 : 6'd0;
                node_state_6 <= (origin == 6'd6) ? 6'd0 : 6'd0;
                node_state_7 <= (origin == 6'd7) ? 6'd0 : 6'd0;
                expected_time_0 <= (origin == 6'd0) ? 16'd0 : 16'h7FFF;
                expected_time_1 <= (origin == 6'd1) ? 16'd0 : 16'h7FFF;
                expected_time_2 <= (origin == 6'd2) ? 16'd0 : 16'h7FFF;
                expected_time_3 <= (origin == 6'd3) ? 16'd0 : 16'h7FFF;
                expected_time_4 <= (origin == 6'd4) ? 16'd0 : 16'h7FFF;
                expected_time_5 <= (origin == 6'd5) ? 16'd0 : 16'h7FFF;
                expected_time_6 <= (origin == 6'd6) ? 16'd0 : 16'h7FFF;
                expected_time_7 <= (origin == 6'd7) ? 16'd0 : 16'h7FFF;
                current_node <= 6'd0;
                state <= SELECT_NODE;
            end
            
            SELECT_NODE: begin
                // Find unvisited node with minimum expected time
                best_time <= 16'h7FFF;
                min_idx <= 4'd8;
                if (node_state_0 == 6'd0 && expected_time_0 < best_time) begin
                    best_time <= expected_time_0;
                    min_idx <= 4'd0;
                end
                state <= CHECK_NODE;
            end
            
            CHECK_NODE: begin
                // Continue finding minimum
                if (min_idx == 4'd8) begin
                    // Check next node
                    if (node_state_1 == 6'd0 && expected_time_1 < best_time) begin
                        best_time <= expected_time_1;
                        min_idx <= 4'd1;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_2 == 6'd0 && expected_time_2 < best_time) begin
                        best_time <= expected_time_2;
                        min_idx <= 4'd2;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_3 == 6'd0 && expected_time_3 < best_time) begin
                        best_time <= expected_time_3;
                        min_idx <= 4'd3;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_4 == 6'd0 && expected_time_4 < best_time) begin
                        best_time <= expected_time_4;
                        min_idx <= 4'd4;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_5 == 6'd0 && expected_time_5 < best_time) begin
                        best_time <= expected_time_5;
                        min_idx <= 4'd5;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_6 == 6'd0 && expected_time_6 < best_time) begin
                        best_time <= expected_time_6;
                        min_idx <= 4'd6;
                    end
                end
                if (min_idx == 4'd8) begin
                    if (node_state_7 == 6'd0 && expected_time_7 < best_time) begin
                        best_time <= expected_time_7;
                        min_idx <= 4'd7;
                    end
                end
                
                if (min_idx == 4'd8) begin
                    // No more nodes to visit
                    if (destination == 6'd0) begin
                        if (expected_time_0 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd1) begin
                        if (expected_time_1 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd2) begin
                        if (expected_time_2 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd3) begin
                        if (expected_time_3 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd4) begin
                        if (expected_time_4 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd5) begin
                        if (expected_time_5 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else if (destination == 6'd6) begin
                        if (expected_time_6 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else begin
                        if (expected_time_7 < 16'h7FFF) begin
                            state <= FINISHED;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end
                end else begin
                    // Set current node based on min_idx
                    case (min_idx)
                        4'd0: current_node <= 6'd0;
                        4'd1: current_node <= 6'd1;
                        4'd2: current_node <= 6'd2;
                        4'd3: current_node <= 6'd3;
                        4'd4: current_node <= 6'd4;
                        4'd5: current_node <= 6'd5;
                        4'd6: current_node <= 6'd6;
                        4'd7: current_node <= 6'd7;
                        default: current_node <= 6'd0;
                    endcase
                    edge_counter <= 4'd0;
                    state <= PROCESS_EDGES;
                end
            end
            
            PROCESS_EDGES: begin
                if (edge_counter >= num_edges) begin
                    // Mark as done
                    if (current_node == 6'd0) node_state_0 <= 6'd2;
                    else if (current_node == 6'd1) node_state_1 <= 6'd2;
                    else if (current_node == 6'd2) node_state_2 <= 6'd2;
                    else if (current_node == 6'd3) node_state_3 <= 6'd2;
                    else if (current_node == 6'd4) node_state_4 <= 6'd2;
                    else if (current_node == 6'd5) node_state_5 <= 6'd2;
                    else if (current_node == 6'd6) node_state_6 <= 6'd2;
                    else node_state_7 <= 6'd2;
                    state <= SELECT_NODE;
                end else begin
                    // Get current edge data
                    case (edge_counter)
                        4'd0: begin
                            edge_from_curr <= edge_from_0;
                            edge_to_curr <= edge_to_0;
                            edge_time_curr <= edge_time_0;
                            edge_p_curr <= edge_p_0;
                            edge_d_curr <= edge_d_0;
                        end
                        4'd1: begin
                            edge_from_curr <= edge_from_1;
                            edge_to_curr <= edge_to_1;
                            edge_time_curr <= edge_time_1;
                            edge_p_curr <= edge_p_1;
                            edge_d_curr <= edge_d_1;
                        end
                        4'd2: begin
                            edge_from_curr <= edge_from_2;
                            edge_to_curr <= edge_to_2;
                            edge_time_curr <= edge_time_2;
                            edge_p_curr <= edge_p_2;
                            edge_d_curr <= edge_d_2;
                        end
                        4'd3: begin
                            edge_from_curr <= edge_from_3;
                            edge_to_curr <= edge_to_3;
                            edge_time_curr <= edge_time_3;
                            edge_p_curr <= edge_p_3;
                            edge_d_curr <= edge_d_3;
                        end
                        4'd4: begin
                            edge_from_curr <= edge_from_4;
                            edge_to_curr <= edge_to_4;
                            edge_time_curr <= edge_time_4;
                            edge_p_curr <= edge_p_4;
                            edge_d_curr <= edge_d_4;
                        end
                        4'd5: begin
                            edge_from_curr <= edge_from_5;
                            edge_to_curr <= edge_to_5;
                            edge_time_curr <= edge_time_5;
                            edge_p_curr <= edge_p_5;
                            edge_d_curr <= edge_d_5;
                        end
                        4'd6: begin
                            edge_from_curr <= edge_from_6;
                            edge_to_curr <= edge_to_6;
                            edge_time_curr <= edge_time_6;
                            edge_p_curr <= edge_p_6;
                            edge_d_curr <= edge_d_6;
                        end
                        4'd7: begin
                            edge_from_curr <= edge_from_7;
                            edge_to_curr <= edge_to_7;
                            edge_time_curr <= edge_time_7;
                            edge_p_curr <= edge_p_7;
                            edge_d_curr <= edge_d_7;
                        end
                        4'd8: begin
                            edge_from_curr <= edge_from_8;
                            edge_to_curr <= edge_to_8;
                            edge_time_curr <= edge_time_8;
                            edge_p_curr <= edge_p_8;
                            edge_d_curr <= edge_d_8;
                        end
                        4'd9: begin
                            edge_from_curr <= edge_from_9;
                            edge_to_curr <= edge_to_9;
                            edge_time_curr <= edge_time_9;
                            edge_p_curr <= edge_p_9;
                            edge_d_curr <= edge_d_9;
                        end
                        4'd10: begin
                            edge_from_curr <= edge_from_10;
                            edge_to_curr <= edge_to_10;
                            edge_time_curr <= edge_time_10;
                            edge_p_curr <= edge_p_10;
                            edge_d_curr <= edge_d_10;
                        end
                        4'd11: begin
                            edge_from_curr <= edge_from_11;
                            edge_to_curr <= edge_to_11;
                            edge_time_curr <= edge_time_11;
                            edge_p_curr <= edge_p_11;
                            edge_d_curr <= edge_d_11;
                        end
                        4'd12: begin
                            edge_from_curr <= edge_from_12;
                            edge_to_curr <= edge_to_12;
                            edge_time_curr <= edge_time_12;
                            edge_p_curr <= edge_p_12;
                            edge_d_curr <= edge_d_12;
                        end
                        4'd13: begin
                            edge_from_curr <= edge_from_13;
                            edge_to_curr <= edge_to_13;
                            edge_time_curr <= edge_time_13;
                            edge_p_curr <= edge_p_13;
                            edge_d_curr <= edge_d_13;
                        end
                        4'd14: begin
                            edge_from_curr <= edge_from_14;
                            edge_to_curr <= edge_to_14;
                            edge_time_curr <= edge_time_14;
                            edge_p_curr <= edge_p_14;
                            edge_d_curr <= edge_d_14;
                        end
                        4'd15: begin
                            edge_from_curr <= edge_from_15;
                            edge_to_curr <= edge_to_15;
                            edge_time_curr <= edge_time_15;
                            edge_p_curr <= edge_p_15;
                            edge_d_curr <= edge_d_15;
                        end
                        default: begin
                            edge_from_curr <= 6'd0;
                            edge_to_curr <= 6'd0;
                            edge_time_curr <= 16'd0;
                            edge_p_curr <= 16'd0;
                            edge_d_curr <= 16'd0;
                        end
                    endcase
                    state <= PROCESS_EDGE;
                end
            end
            
            PROCESS_EDGE: begin
                if (edge_from_curr == current_node) begin
                    // Calculate expected time for this edge
                    // wait_time = (departure - current_time) mod 60
                    // Assume immediate departure for simplicity
                    wait_time <= 16'd0;
                    
                    // base_time = standard_time
                    base_time <= edge_time_curr;
                    
                    // delay_expected = (p/100) * (d/2) in Q8.8
                    // p in [0,100], d in [1,120] scaled to Q8.8
                    // delay_expected = (p * d / 200) in Q8.8
                    // 200 = 0xC8, dividing by 200 in Q8.8 means multiply by 256/200 = 1.28
                    // Simplification: delay_expected <= (edge_p_curr * edge_d_curr[15:0]) >> 9;
                    delay_expected <= (edge_p_curr * edge_d_curr[15:0]) >> 9;
                    
                    // no_delay_prob = 1 - p/100 = (100 - p) in percent, scaled to Q8.8
                    // 1.0 = 0x0100 (256), 0.01 = 0x0001
                    // no_delay_prob = (100 - p) * 0x0100 / 100 = (100 - p) * 2.56
                    // For simplicity: no_delay_prob = 16'h0100 - edge_p_curr;
                    // Actually, p is already Q8.8, so 100 = 0x6400
                    // 1.0 - p/100 = 0x0100 - (p >> 8)
                    no_delay_prob <= 16'h0100 - (edge_p_curr >> 8);
                    
                    // delay_prob = p/100 = p >> 8
                    delay_prob <= edge_p_curr >> 8;
                    
                    state <= UPDATE_NODE;
                end else begin
                    edge_counter <= edge_counter + 1;
                    state <= PROCESS_EDGES;
                end
            end
            
            UPDATE_NODE: begin
                // Calculate expected time with delays
                // new_time = expected_time[current_node] + base_time + delay_expected
                new_time <= best_time + base_time + delay_expected;
                
                // Update destination node if better
                if (edge_to_curr < MAX_NODES && new_time < get_expected_time(edge_to_curr)) begin
                    set_expected_time(edge_to_curr, new_time);
                end
                
                edge_counter <= edge_counter + 1;
                state <= PROCESS_EDGES;
            end
            
            FINISHED: begin
                // Get result from destination node
                case (destination)
                    6'd0: result <= expected_time_0;
                    6'd1: result <= expected_time_1;
                    6'd2: result <= expected_time_2;
                    6'd3: result <= expected_time_3;
                    6'd4: result <= expected_time_4;
                    6'd5: result <= expected_time_5;
                    6'd6: result <= expected_time_6;
                    6'd7: result <= expected_time_7;
                    default: result <= 16'h7FFF;
                endcase
                done <= 1'b1;
                state <= IDLE;
            end
            
            IMPOSSIBLE_STATE: begin
                impossible <= 1'b1;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Helper functions for expected time access
function [15:0] get_expected_time;
    input [5:0] node;
    begin
        case (node)
            6'd0: get_expected_time = expected_time_0;
            6'd1: get_expected_time = expected_time_1;
            6'd2: get_expected_time = expected_time_2;
            6'd3: get_expected_time = expected_time_3;
            6'd4: get_expected_time = expected_time_4;
            6'd5: get_expected_time = expected_time_5;
            6'd6: get_expected_time = expected_time_6;
            6'd7: get_expected_time = expected_time_7;
            default: get_expected_time = 16'h7FFF;
        endcase
    end
endfunction

task set_expected_time;
    input [5:0] node;
    input [15:0] value;
    begin
        case (node)
            6'd0: expected_time_0 <= value;
            6'd1: expected_time_1 <= value;
            6'd2: expected_time_2 <= value;
            6'd3: expected_time_3 <= value;
            6'd4: expected_time_4 <= value;
            6'd5: expected_time_5 <= value;
            6'd6: expected_time_6 <= value;
            6'd7: expected_time_7 <= value;
            default: ;
        endcase
    end
endtask

endmodule