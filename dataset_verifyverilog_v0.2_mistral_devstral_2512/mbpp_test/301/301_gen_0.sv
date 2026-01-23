module dict_depth (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] parent_mask,
    input [7:0] parent_map_0,
    input [7:0] parent_map_1,
    input [7:0] parent_map_2,
    input [7:0] parent_map_3,
    input [7:0] parent_map_4,
    input [7:0] parent_map_5,
    input [7:0] parent_map_6,
    input [7:0] parent_map_7,
    output reg [3:0] depth,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        PROCESSING,
        CALCULATING,
        DONE
    } state_t;

    state_t state;
    reg [3:0] current_depth;
    reg [3:0] max_depth;
    reg [2:0] current_node;
    reg [2:0] next_node;
    reg [2:0] node_counter;
    reg [2:0] level_counter;
    reg [7:0] visited;
    reg [7:0] queue;
    reg [2:0] queue_ptr;
    reg [2:0] queue_size;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            depth <= 0;
            done <= 0;
            current_depth <= 0;
            max_depth <= 0;
            current_node <= 0;
            next_node <= 0;
            node_counter <= 0;
            level_counter <= 0;
            visited <= 0;
            queue <= 0;
            queue_ptr <= 0;
            queue_size <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SETUP;
                        done <= 0;
                    end
                end
                SETUP: begin
                    state <= PROCESSING;
                    current_depth <= 1;
                    max_depth <= 1;
                    current_node <= 0;
                    visited <= 0;
                    queue <= 0;
                    queue_ptr <= 0;
                    queue_size <= 1;
                    queue[0] <= 1'b1;
                    visited[0] <= 1'b1;
                end
                PROCESSING: begin
                    if (queue_size > 0) begin
                        // Process current node
                        current_node <= queue_ptr;
                        queue[queue_ptr] <= 0;
                        queue_ptr <= queue_ptr + 1;
                        queue_size <= queue_size - 1;
                        
                        // Check if current node has children
                        if (parent_mask[current_node]) begin
                            // Enqueue children
                            case (current_node)
                                3'd0: queue <= queue | parent_map_0;
                                3'd1: queue <= queue | parent_map_1;
                                3'd2: queue <= queue | parent_map_2;
                                3'd3: queue <= queue | parent_map_3;
                                3'd4: queue <= queue | parent_map_4;
                                3'd5: queue <= queue | parent_map_5;
                                3'd6: queue <= queue | parent_map_6;
                                3'd7: queue <= queue | parent_map_7;
                            endcase
                            
                            // Update queue size
                            queue_size <= queue_size + $countones({parent_map_0, parent_map_1, parent_map_2, parent_map_3, parent_map_4, parent_map_5, parent_map_6, parent_map_7}[current_node]);
                            
                            // Update max depth
                            if (current_depth + 1 > max_depth) begin
                                max_depth <= current_depth + 1;
                            end
                        end
                        
                        // Move to next node
                        if (queue_size == 0) begin
                            state <= CALCULATING;
                        end
                    end else begin
                        state <= CALCULATING;
                    end
                end
                CALCULATING: begin
                    state <= DONE;
                    depth <= max_depth;
                    done <= 1;
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule