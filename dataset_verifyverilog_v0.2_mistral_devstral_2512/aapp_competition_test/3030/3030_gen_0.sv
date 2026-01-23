module heap_subset (
    input clk,
    input rst_n,
    input start,
    // Parent array (8 nodes)
    input [2:0] parent_0, parent_1, parent_2, parent_3,
    input [2:0] parent_4, parent_5, parent_6, parent_7,
    // Value array (Q8.8 format)
    input [15:0] value_0, value_1, value_2, value_3,
    input [15:0] value_4, value_5, value_6, value_7,
    output reg [3:0] result,  // Max subset size (0-8)
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        BUILD,
        DONE
    } state_t;

    state_t state;
    reg [7:0] cycle_count;
    reg [2:0] current_node;
    reg [2:0] current_threshold;
    reg [3:0] max_size;
    reg [3:0] current_size;
    reg [15:0] values [0:7];
    reg [2:0] parents [0:7];
    reg [2:0] path [0:3];
    reg [3:0] path_len;
    reg valid;

    // Initialize arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            current_node <= 0;
            current_threshold <= 0;
            max_size <= 0;
            current_size <= 0;
            done <= 0;
            result <= 0;
            path_len <= 0;
            valid <= 0;
        end else begin
            // Update arrays on reset or start
            if (rst_n && start) begin
                values[0] <= value_0;
                values[1] <= value_1;
                values[2] <= value_2;
                values[3] <= value_3;
                values[4] <= value_4;
                values[5] <= value_5;
                values[6] <= value_6;
                values[7] <= value_7;
                
                parents[0] <= parent_0;
                parents[1] <= parent_1;
                parents[2] <= parent_2;
                parents[3] <= parent_3;
                parents[4] <= parent_4;
                parents[5] <= parent_5;
                parents[6] <= parent_6;
                parents[7] <= parent_7;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= BUILD;
                        cycle_count <= 0;
                        current_node <= 0;
                        current_threshold <= 0;
                        max_size <= 0;
                        done <= 0;
                    end
                end
                
                BUILD: begin
                    if (cycle_count == 254) begin
                        state <= DONE;
                        result <= max_size;
                        done <= 1;
                    end else begin
                        cycle_count <= cycle_count + 1;
                        
                        // Process each node and threshold
                        if (cycle_count[7:3] == 0) begin
                            current_node <= cycle_count[2:0];
                            current_threshold <= 0;
                        end else begin
                            current_threshold <= current_threshold + 1;
                        end
                        
                        // Compute path for current node
                        path_len = 0;
                        path[0] = current_node;
                        reg [2:0] temp = parents[current_node];
                        if (temp != 3'b000) begin
                            path[1] = temp;
                            path_len = 1;
                            temp = parents[temp];
                            if (temp != 3'b000) begin
                                path[2] = temp;
                                path_len = 2;
                                temp = parents[temp];
                                if (temp != 3'b000) begin
                                    path[3] = temp;
                                    path_len = 3;
                                end
                            end
                        end
                        
                        // Check if current node can be included with current threshold
                        valid = 1;
                        current_size = 0;
                        
                        // Check all nodes in path
                        for (int i = 0; i <= path_len; i++) begin
                            if (values[path[i]] <= values[current_threshold]) begin
                                valid = 0;
                            end
                        end
                        
                        // If valid, count how many nodes satisfy the condition
                        if (valid) begin
                            current_size = 0;
                            for (int i = 0; i < 8; i++) begin
                                reg [2:0] temp_path [0:3];
                                reg [3:0] temp_len = 0;
                                reg temp_valid = 1;
                                
                                // Build path for node i
                                temp_path[0] = i;
                                reg [2:0] temp_parent = parents[i];
                                if (temp_parent != 3'b000) begin
                                    temp_path[1] = temp_parent;
                                    temp_len = 1;
                                    temp_parent = parents[temp_parent];
                                    if (temp_parent != 3'b000) begin
                                        temp_path[2] = temp_parent;
                                        temp_len = 2;
                                        temp_parent = parents[temp_parent];
                                        if (temp_parent != 3'b000) begin
                                            temp_path[3] = temp_parent;
                                            temp_len = 3;
                                        end
                                    end
                                end
                                
                                // Check path
                                for (int j = 0; j <= temp_len; j++) begin
                                    if (values[temp_path[j]] <= values[current_threshold]) begin
                                        temp_valid = 0;
                                    end
                                end
                                
                                if (temp_valid) begin
                                    current_size = current_size + 1;
                                end
                            end
                            
                            // Update max_size
                            if (current_size > max_size) begin
                                max_size = current_size;
                            end
                        end
                    end
                end
                
                DONE: begin
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule