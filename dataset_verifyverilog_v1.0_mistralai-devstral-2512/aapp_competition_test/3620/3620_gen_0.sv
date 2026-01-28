module GraphColouringCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] nodes [0:15],
    input wire [1:0] edges [0:47],
    input wire [7:0] k,
    input wire [31:0] P,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_COMPONENTS = 3'd1;
    localparam [2:0] COUNT_COLOURINGS = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Component detection variables
    reg [3:0] current_node;
    reg [3:0] component_id [0:15];
    reg [3:0] component_size [0:15];
    reg [3:0] num_components;
    reg [3:0] visited [0:15];
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;

    // Colouring counting variables
    reg [3:0] current_component;
    reg [31:0] component_result;
    reg [31:0] temp_result;
    reg [3:0] vertex_mask;
    reg [3:0] colour_mask;
    reg [3:0] i, j, m;

    // Adjacency matrix unpacking
    reg [15:0] adj_matrix [0:15];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_node <= 4'd0;
            num_components <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_component <= 4'd0;
            component_result <= 32'd0;
            temp_result <= 32'd0;
            vertex_mask <= 4'd0;
            colour_mask <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            m <= 4'd0;

            // Initialize arrays
            for (integer idx = 0; idx < 16; idx = idx + 1) begin
                component_id[idx] <= 4'd0;
                component_size[idx] <= 4'd0;
                visited[idx] <= 4'd0;
                queue[idx] <= 4'd0;
                adj_matrix[idx] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FIND_COMPONENTS;
                        // Unpack adjacency matrix
                        for (i = 0; i < 16; i = i + 1) begin
                            adj_matrix[i] <= nodes[i];
                        end
                    end
                end

                FIND_COMPONENTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // BFS for component detection
                        if (queue_head == queue_tail) begin
                            // Find next unvisited node
                            current_node <= 4'd0;
                            while (current_node < 16 && visited[current_node]) begin
                                current_node <= current_node + 4'd1;
                            end
                            if (current_node < 16) begin
                                // Start new component
                                num_components <= num_components + 4'd1;
                                component_id[current_node] <= num_components;
                                visited[current_node] <= 4'd1;
                                queue[queue_tail] <= current_node;
                                queue_tail <= queue_tail + 4'd1;
                            end else begin
                                state <= COUNT_COLOURINGS;
                            end
                        end else begin
                            // Process queue
                            current_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                            component_size[num_components] <= component_size[num_components] + 4'd1;

                            // Visit neighbors
                            for (i = 0; i < 16; i = i + 1) begin
                                if (adj_matrix[current_node][i] && !visited[i]) begin
                                    visited[i] <= 4'd1;
                                    component_id[i] <= num_components;
                                    queue[queue_tail] <= i;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                end

                COUNT_COLOURINGS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (current_component < num_components) begin
                            // Count colourings for current component
                            if (component_size[current_component] <= 8) begin
                                // Small component: use bitmask DP
                                temp_result <= 32'd1;
                                for (i = 0; i < component_size[current_component]; i = i + 1) begin
                                    temp_result <= (temp_result * k) % P;
                                end
                                component_result <= temp_result;
                            end else begin
                                // Large component: tree DP approximation
                                // Since edges <= s+2, it's a tree with 2 extra edges
                                // Use recursive formula for trees
                                temp_result <= k;
                                for (i = 1; i < component_size[current_component]; i = i + 1) begin
                                    temp_result <= (temp_result * (k - 1)) % P;
                                end
                                component_result <= temp_result;
                            end
                            result <= (result + component_result) % P;
                            current_component <= current_component + 4'd1;
                        end else begin
                            state <= COMPUTE_RESULT;
                        end
                    end
                end

                COMPUTE_RESULT: begin
                    // Final result is already computed
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule