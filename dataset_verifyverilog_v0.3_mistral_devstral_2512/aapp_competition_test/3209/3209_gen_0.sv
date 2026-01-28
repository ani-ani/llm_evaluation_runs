module TrainPathPlanner (
    input clk,
    input rst_n,
    input start,
    input [5:0] origin,      // 6-bit node ID (0-63)
    input [5:0] destination, // 6-bit node ID (0-63)
    input [3:0] num_edges,   // Number of edges (1-16)
    input [5:0] edge_from [15:0],  // From node IDs
    input [5:0] edge_to [15:0],    // To node IDs  
    input [7:0] edge_dep [15:0],   // Departure time (0-59)
    input [15:0] edge_time [15:0], // Standard time in Q8.8
    input [15:0] edge_p [15:0],    // Probability (0-100) in Q8.8
    input [15:0] edge_d [15:0],    // Max delay in Q8.8
    output reg [15:0] result,       // Expected duration in Q8.8
    output reg done,
    output reg impossible
);

// Parameters
localparam [2:0] MAX_NODES = 8;
localparam [3:0] MAX_EDGES = 16;

// Internal state
reg [5:0] node_state [0:7]; // 0=unvisited, 1=visiting, 2=done
reg [15:0] expected_time [0:7]; // Q8.8
reg [5:0] current_node;
reg [3:0] edge_counter;

// Temporary registers
reg [15:0] new_time;
reg [15:0] base_time;
reg [15:0] delay_expected;
reg [15:0] no_delay_prob;
reg [15:0] delay_prob;

// State machine states
reg [2:0] state;
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] SELECT_NODE = 3'd2;
localparam [2:0] PROCESS_EDGES = 3'd3;
localparam [2:0] UPDATE_NODE = 3'd4;
localparam [2:0] CHECK_DONE = 3'd5;
localparam [2:0] FINISHED = 3'd6;
localparam [2:0] IMPOSSIBLE_STATE = 3'd7;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 16'd0;
        
        // Initialize arrays
        for (i = 0; i < 8; i = i + 1) begin
            node_state[i] <= 6'd0;
            expected_time[i] <= 16'd0;
        end
        current_node <= 6'd0;
        edge_counter <= 4'd0;
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
                for (i = 0; i < 8; i = i + 1) begin
                    node_state[i] <= (i == origin) ? 6'd0 : 6'd0; // All unvisited
                    expected_time[i] <= 16'h7FFF; // Max value
                end
                expected_time[origin] <= 16'd0;
                state <= SELECT_NODE;
            end
            
            SELECT_NODE: begin
                // Find unvisited node with minimum expected time
                current_node <= 6'h3F; // Invalid initially
                for (i = 0; i < 8; i = i + 1) begin
                    if (node_state[i] == 6'd0) begin
                        if (current_node == 6'h3F || expected_time[i] < expected_time[current_node]) begin
                            current_node <= i;
                        end
                    end
                end
                
                if (current_node == 6'h3F) begin
                    // No more nodes to visit
                    if (expected_time[destination] < 16'h7FFF) begin
                        state <= FINISHED;
                    end else begin
                        state <= IMPOSSIBLE_STATE;
                    end
                end else begin
                    edge_counter <= 4'd0;
                    state <= PROCESS_EDGES;
                end
            end
            
            PROCESS_EDGES: begin
                if (edge_counter >= num_edges) begin
                    node_state[current_node] <= 6'd2; // Mark as done
                    state <= SELECT_NODE;
                end else if (edge_from[edge_counter] == current_node) begin
                    // Calculate expected time for this edge
                    base_time <= edge_time[edge_counter];
                    
                    // delay_expected = (p/100) * (d/2) in Q8.8
                    delay_expected <= (edge_p[edge_counter] * edge_d[edge_counter]) >> 9;
                    
                    // no_delay_prob = 1 - p/100
                    no_delay_prob <= 16'h0100 - edge_p[edge_counter];
                    
                    // delay_prob = p/100
                    delay_prob <= edge_p[edge_counter];
                    
                    state <= UPDATE_NODE;
                end else begin
                    edge_counter <= edge_counter + 4'd1;
                end
            end
            
            UPDATE_NODE: begin
                // For simplicity, we use a weighted average of no-delay and delay cases
                new_time <= expected_time[current_node] + base_time + delay_expected;
                
                // Update destination node if better
                if (edge_to[edge_counter] < 8 && new_time < expected_time[edge_to[edge_counter]]) begin
                    expected_time[edge_to[edge_counter]] <= new_time;
                end
                
                edge_counter <= edge_counter + 4'd1;
                state <= PROCESS_EDGES;
            end
            
            FINISHED: begin
                result <= expected_time[destination];
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

endmodule