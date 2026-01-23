module bfs_validator #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter MAX_CYCLES = 100
)(
    input clk,
    input rst_n,
    input start,
    
    // Adjacency: each input is an 8-bit bitmask of neighbors for that node
    input [DATA_WIDTH-1:0] adj_0,
    input [DATA_WIDTH-1:0] adj_1,
    input [DATA_WIDTH-1:0] adj_2,
    input [DATA_WIDTH-1:0] adj_3,
    input [DATA_WIDTH-1:0] adj_4,
    input [DATA_WIDTH-1:0] adj_5,
    input [DATA_WIDTH-1:0] adj_6,
    input [DATA_WIDTH-1:0] adj_7,
    
    // Sequence: 8 elements, each 8-bit (but only low 3 bits used for node ID)
    input [DATA_WIDTH-1:0] seq_0,
    input [DATA_WIDTH-1:0] seq_1,
    input [DATA_WIDTH-1:0] seq_2,
    input [DATA_WIDTH-1:0] seq_3,
    input [DATA_WIDTH-1:0] seq_4,
    input [DATA_WIDTH-1:0] seq_5,
    input [DATA_WIDTH-1:0] seq_6,
    input [DATA_WIDTH-1:0] seq_7,
    
    output reg valid,
    output reg done
);

// State definitions
localparam [3:0] IDLE           = 4'd0;
localparam [3:0] CHECK_START    = 4'd1;
localparam [3:0] GET_NEIGHBORS  = 4'd2;
localparam [3:0] VERIFY_CHILDREN = 4'd3;
localparam [3:0] UPDATE_QUEUE   = 4'd4;
localparam [3:0] FINISHED       = 4'd5;

reg [3:0] state, next_state;
reg [7:0] queue;           // One-hot encoding for queue
reg [7:0] visited;         // Bitmask of visited nodes
reg [2:0] head_ptr;        // Index in sequence for current node
reg [2:0] child_ptr;       // Index in sequence for children
reg [2:0] current_node;    // Node being processed
reg [7:0] neighbor_mask;   // Unvisited neighbors
reg [2:0] neighbor_count;  // Count of unvisited neighbors
reg [2:0] verify_count;    // How many children verified
reg [7:0] cycle_count;     // Timeout counter

// Helper: Get adjacency for current node
reg [7:0] current_adj;

// Helper: Get sequence element at head position
reg [7:0] head_seq;

// Helper: Get sequence element at child position
reg [7:0] child_seq;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = CHECK_START;
        end
        CHECK_START: begin
            // Check if first element is 1 (0-indexed)
            if (head_seq != 8'd0) begin
                next_state = FINISHED;
            end else begin
                next_state = GET_NEIGHBORS;
            end
        end
        GET_NEIGHBORS: begin
            if (queue == 8'd0) begin
                next_state = FINISHED;
            end else begin
                next_state = VERIFY_CHILDREN;
            end
        end
        VERIFY_CHILDREN: begin
            if (verify_count >= neighbor_count) begin
                next_state = UPDATE_QUEUE;
            end else if (child_ptr >= N || cycle_count >= MAX_CYCLES) begin
                next_state = FINISHED;
            end else begin
                next_state = VERIFY_CHILDREN;
            end
        end
        UPDATE_QUEUE: begin
            if (head_ptr >= N) begin
                next_state = FINISHED;
            end else begin
                next_state = GET_NEIGHBORS;
            end
        end
        FINISHED: next_state = FINISHED;
        default: next_state = IDLE;
    endcase
end

// Datapath logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid <= 1'b0;
        done <= 1'b0;
        queue <= 8'd0;
        visited <= 8'd0;
        head_ptr <= 3'd0;
        child_ptr <= 3'd0;
        current_node <= 3'd0;
        neighbor_mask <= 8'd0;
        neighbor_count <= 3'd0;
        verify_count <= 3'd0;
        cycle_count <= 8'd0;
        current_adj <= 8'd0;
        head_seq <= 8'd0;
        child_seq <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 1'b0;
                done <= 1'b0;
                cycle_count <= 8'd0;
                head_ptr <= 3'd0;
                child_ptr <= 3'd0;
                verify_count <= 3'd0;
                queue <= 8'd0;
                visited <= 8'd0;
            end
            
            CHECK_START: begin
                // Get first sequence element
                case (head_ptr)
                    3'd0: head_seq <= seq_0;
                    3'd1: head_seq <= seq_1;
                    3'd2: head_seq <= seq_2;
                    3'd3: head_seq <= seq_3;
                    3'd4: head_seq <= seq_4;
                    3'd5: head_seq <= seq_5;
                    3'd6: head_seq <= seq_6;
                    3'd7: head_seq <= seq_7;
                    default: head_seq <= seq_0;
                endcase
                
                if (head_seq == 8'd0) begin
                    // Initialize BFS with node 0
                    queue <= 8'b00000001;
                    visited <= 8'b00000001;
                    head_ptr <= 3'd1;
                    current_node <= 3'd0;
                    valid <= 1'b1; // Assume valid until proven otherwise
                    cycle_count <= 8'd0;
                end else begin
                    valid <= 1'b0;
                    done <= 1'b1;
                end
            end
            
            GET_NEIGHBORS: begin
                // Get current node from queue (find lowest set bit)
                if (queue[0]) current_node <= 3'd0;
                else if (queue[1]) current_node <= 3'd1;
                else if (queue[2]) current_node <= 3'd2;
                else if (queue[3]) current_node <= 3'd3;
                else if (queue[4]) current_node <= 3'd4;
                else if (queue[5]) current_node <= 3'd5;
                else if (queue[6]) current_node <= 3'd6;
                else if (queue[7]) current_node <= 3'd7;
                
                // Get adjacency for current node
                case (current_node)
                    3'd0: current_adj <= adj_0;
                    3'd1: current_adj <= adj_1;
                    3'd2: current_adj <= adj_2;
                    3'd3: current_adj <= adj_3;
                    3'd4: current_adj <= adj_4;
                    3'd5: current_adj <= adj_5;
                    3'd6: current_adj <= adj_6;
                    3'd7: current_adj <= adj_7;
                    default: current_adj <= 8'd0;
                endcase
                
                // Get neighbors and remove visited (1 cycle delay)
                neighbor_mask <= current_adj & ~visited;
                
                // Count neighbors (combinational logic)
                neighbor_count <= 0;
                if (current_adj[0] && !visited[0]) neighbor_count <= neighbor_count + 1;
                if (current_adj[1] && !visited[1]) neighbor_count <= neighbor_count + 1;
                if (current_adj[2] && !visited[2]) neighbor_count <= neighbor_count + 1;
                if (current_adj[3] && !visited[3]) neighbor_count <= neighbor_count + 1;
                if (current_adj[4] && !visited[4]) neighbor_count <= neighbor_count + 1;
                if (current_adj[5] && !visited[5]) neighbor_count <= neighbor_count + 1;
                if (current_adj[6] && !visited[6]) neighbor_count <= neighbor_count + 1;
                if (current_adj[7] && !visited[7]) neighbor_count <= neighbor_count + 1;
                
                verify_count <= 0;
                child_ptr <= head_ptr;
                cycle_count <= cycle_count + 1;
            end
            
            VERIFY_CHILDREN: begin
                if (verify_count < neighbor_count && child_ptr < N) begin
                    // Get child sequence element
                    case (child_ptr)
                        3'd0: child_seq <= seq_0;
                        3'd1: child_seq <= seq_1;
                        3'd2: child_seq <= seq_2;
                        3'd3: child_seq <= seq_3;
                        3'd4: child_seq <= seq_4;
                        3'd5: child_seq <= seq_5;
                        3'd6: child_seq <= seq_6;
                        3'd7: child_seq <= seq_7;
                        default: child_seq <= seq_0;
                    endcase
                    
                    // Check if child_seq is in neighbor_mask
                    if (child_seq < 8'd8) begin
                        case (child_seq)
                            3'd0: if (neighbor_mask[0]) verify_count <= verify_count + 1;
                            3'd1: if (neighbor_mask[1]) verify_count <= verify_count + 1;
                            3'd2: if (neighbor_mask[2]) verify_count <= verify_count + 1;
                            3'd3: if (neighbor_mask[3]) verify_count <= verify_count + 1;
                            3'd4: if (neighbor_mask[4]) verify_count <= verify_count + 1;
                            3'd5: if (neighbor_mask[5]) verify_count <= verify_count + 1;
                            3'd6: if (neighbor_mask[6]) verify_count <= verify_count + 1;
                            3'd7: if (neighbor_mask[7]) verify_count <= verify_count + 1;
                            default: valid <= 1'b0;
                        endcase
                    end else begin
                        valid <= 1'b0;
                    end
                    
                    child_ptr <= child_ptr + 1;
                end
                cycle_count <= cycle_count + 1;
            end
            
            UPDATE_QUEUE: begin
                // Enqueue all verified children (neighbors that are in sequence)
                if (child_ptr >= head_ptr && child_ptr < N) begin
                    case (child_ptr)
                        3'd1: begin
                            if (seq_1 < 8'd8 && neighbor_mask[seq_1]) begin
                                queue[seq_1] <= 1'b1;
                                visited[seq_1] <= 1'b1;
                            end
                        end
                        3'd2: begin
                            if (seq_2 < 8'd8 && neighbor_mask[seq_2]) begin
                                queue[seq_2] <= 1'b1;
                                visited[seq_2] <= 1'b1;
                            end
                        end
                        3'd3: begin
                            if (seq_3 < 8'd8 && neighbor_mask[seq_3]) begin
                                queue[seq_3] <= 1'b1;
                                visited[seq_3] <= 1'b1;
                            end
                        end
                        3'd4: begin
                            if (seq_4 < 8'd8 && neighbor_mask[seq_4]) begin
                                queue[seq_4] <= 1'b1;
                                visited[seq_4] <= 1'b1;
                            end
                        end
                        3'd5: begin
                            if (seq_5 < 8'd8 && neighbor_mask[seq_5]) begin
                                queue[seq_5] <= 1'b1;
                                visited[seq_5] <= 1'b1;
                            end
                        end
                        3'd6: begin
                            if (seq_6 < 8'd8 && neighbor_mask[seq_6]) begin
                                queue[seq_6] <= 1'b1;
                                visited[seq_6] <= 1'b1;
                            end
                        end
                        3'd7: begin
                            if (seq_7 < 8'd8 && neighbor_mask[seq_7]) begin
                                queue[seq_7] <= 1'b1;
                                visited[seq_7] <= 1'b1;
                            end
                        end
                    endcase
                end
                
                // Remove current node from queue
                case (current_node)
                    3'd0: queue[0] <= 1'b0;
                    3'd1: queue[1] <= 1'b0;
                    3'd2: queue[2] <= 1'b0;
                    3'd3: queue[3] <= 1'b0;
                    3'd4: queue[4] <= 1'b0;
                    3'd5: queue[5] <= 1'b0;
                    3'd6: queue[6] <= 1'b0;
                    3'd7: queue[7] <= 1'b0;
                endcase
                
                // Update head pointer
                head_ptr <= head_ptr + neighbor_count;
                
                // Check if we're done
                if (head_ptr + neighbor_count >= N) begin
                    done <= 1'b1;
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
                if (!valid) valid <= 1'b0;
            end
            
            default: begin
                valid <= 1'b0;
                done <= 1'b0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule