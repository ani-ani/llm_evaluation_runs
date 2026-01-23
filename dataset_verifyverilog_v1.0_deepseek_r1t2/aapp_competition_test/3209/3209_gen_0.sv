module TrainPathPlanner (
    input clk,
    input rst_n,
    input start,
    input [5:0] origin,
    input [5:0] destination,
    input [3:0] num_edges,
    input [5:0] edge_from [0:15],
    input [5:0] edge_to [0:15],
    input [7:0] edge_dep [0:15],
    input [15:0] edge_time [0:15],
    input [15:0] edge_p [0:15],
    input [15:0] edge_d [0:15],
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

// Parameters
localparam MAX_NODES = 8;
localparam MAX_EDGES = 16;
localparam ITERATIONS = 3'd8;

// State declarations
localparam [3:0] IDLE           = 4'd0;
localparam [3:0] INIT           = 4'd1;
localparam [3:0] SELECT_NODE    = 4'd2;
localparam [3:0] PROCESS_EDGES  = 4'd3;
localparam [3:0] UPDATE_NODE    = 4'd4;
localparam [3:0] CHECK_DONE     = 4'd5;
localparam [3:0] FINISHED       = 4'd6;
localparam [3:0] IMPOSSIBLE_STATE = 4'd7;

reg [3:0] state;

// Registers
reg [2:0] iteration_counter;
reg [5:0] current_node;
reg [3:0] edge_counter;
integer i; // For loop variable

// Node arrays
reg [2:0] node_state [0:MAX_NODES-1];
reg [15:0] expected_time [0:MAX_NODES-1];

// Internal temps
reg [15:0] new_time;
reg [15:0] wait_time;
reg [15:0] base_time;
reg [15:0] delay_expected;
reg [15:0] no_delay_prob;
reg [15:0] delay_prob;
reg [15:0] sum_delay;
reg [4:0] delay_iter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all registers
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 16'd0;
        current_node <= 6'd0;
        edge_counter <= 4'd0;
        iteration_counter <= 3'd0;
        
        // Initialize arrays (all elements)
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            node_state[i] <= 3'd0;
            expected_time[i] <= 16'h7FFF;
        end
    
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                if (start) state <= INIT;
            end
            
            INIT: begin
                // Reset only origin node
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    node_state[i] <= 3'd0; // Unvisited
                    expected_time[i] <= 16'h7FFF; // Max
                end
                expected_time[origin] <= 16'd0;
                iteration_counter <= 3'd0;
                state <= SELECT_NODE;
            end
            
            SELECT_NODE: begin
                current_node <= 6'd63; // Invalid node ID
                
                // Find minimum node
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    if ((node_state[i] == 3'd0) && 
                        (current_node == 6'd63 || expected_time[i] < expected_time[current_node]))
                        current_node <= i;
                end
                
                if (current_node == 6'd63) begin
                    if (expected_time[destination] < 16'h7FFF) state <= FINISHED;
                    else state <= IMPOSSIBLE_STATE;
                end else begin
                    edge_counter <= 4'd0;
                    state <= PROCESS_EDGES;
                end
            end
            
            PROCESS_EDGES: begin
                if (edge_counter >= num_edges) begin
                    node_state[current_node] <= 3'd2; // Mark done
                    state <= SELECT_NODE;
                end else if (edge_from[edge_counter] == current_node) begin
                    // Simplified calculations
                    wait_time <= 8'd0;
                    base_time <= edge_time[edge_counter];
                    
                    // Fixed-point multiplication (Q8.8)
                    delay_expected <= (edge_p[edge_counter] * edge_d[edge_counter]) >> 9;
                    
                    // Probability components
                    no_delay_prob <= 16'h0100 - edge_p[edge_counter];
                    delay_prob <= edge_p[edge_counter];
                    
                    state <= UPDATE_NODE;
                end else begin
                    edge_counter <= edge_counter + 4'd1;
                end
            end
            
            UPDATE_NODE: begin
                new_time <= expected_time[current_node] + base_time + delay_expected;
                
                if (edge_to[edge_counter] < MAX_NODES && 
                    new_time < expected_time[edge_to[edge_counter]]) begin
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