module minPath(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_data,
    input wire [3:0] k,
    input wire grid_size,
    output reg [7:0] result,
    output reg [3:0] step,
    output reg valid,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_GRID = 4'd1;
    localparam [3:0] STEP_LOOP_INIT = 4'd2;
    localparam [3:0] STEP_LOOP_CALC = 4'd3;
    localparam [3:0] FIND_GLOBAL_MIN = 4'd4;
    localparam [3:0] OUTPUT_SEQ = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] current_step;
    reg [3:0] current_node;
    reg [3:0] prev_node;
    reg [3:0] best_node;
    reg [3:0] num_nodes;
    reg [3:0] cycle_count;
    reg [3:0] output_index;

    // Grid memory (16x8-bit)
    reg [7:0] grid_mem [0:15];

    // Path storage: paths[step][node] = sequence of values
    reg [7:0] path_storage [0:15][0:15];

    // Neighbor lookup table
    reg [3:0] neighbors [0:15];
    reg [3:0] neighbor_count [0:15];

    // Temporary registers for comparisons
    reg [7:0] temp_path1 [0:15];
    reg [7:0] temp_path2 [0:15];
    reg [3:0] compare_result;

    // Initialize neighbor table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            current_step <= 4'd0;
            current_node <= 4'd0;
            prev_node <= 4'd0;
            best_node <= 4'd0;
            num_nodes <= 4'd0;
            cycle_count <= 4'd0;
            output_index <= 4'd0;
            result <= 8'd0;
            step <= 4'd0;
            valid <= 1'b0;
            busy <= 1'b0;

            // Initialize grid memory
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                grid_mem[i] <= 8'd0;
            end

            // Initialize path storage
            for (i = 0; i < 16; i = i + 1) begin
                integer j;
                for (j = 0; j < 16; j = j + 1) begin
                    path_storage[i][j] <= 8'd0;
                end
            end

            // Initialize neighbor table
            for (i = 0; i < 16; i = i + 1) begin
                neighbors[i] <= 4'd0;
                neighbor_count[i] <= 4'd0;
            end
        end else begin
            // Update neighbor table based on grid_size
            if (grid_size) begin // 4x4 grid
                // 4x4 grid neighbor initialization
                neighbors[0] <= 4'd1; // right
                neighbor_count[0] <= 4'd1;
                neighbors[1] <= 4'd0; // left
                neighbor_count[1] <= 4'd1;
                neighbors[2] <= 4'd3; // right
                neighbor_count[2] <= 4'd1;
                neighbors[3] <= 4'd2; // left
                neighbor_count[3] <= 4'd1;
                neighbors[4] <= 4'd5; // right
                neighbor_count[4] <= 4'd1;
                neighbors[5] <= 4'd4; // left
                neighbor_count[5] <= 4'd1;
                neighbors[6] <= 4'd7; // right
                neighbor_count[6] <= 4'd1;
                neighbors[7] <= 4'd6; // left
                neighbor_count[7] <= 4'd1;
                neighbors[8] <= 4'd9; // right
                neighbor_count[8] <= 4'd1;
                neighbors[9] <= 4'd8; // left
                neighbor_count[9] <= 4'd1;
                neighbors[10] <= 4'd11; // right
                neighbor_count[10] <= 4'd1;
                neighbors[11] <= 4'd10; // left
                neighbor_count[11] <= 4'd1;
                neighbors[12] <= 4'd13; // right
                neighbor_count[12] <= 4'd1;
                neighbors[13] <= 4'd12; // left
                neighbor_count[13] <= 4'd1;
                neighbors[14] <= 4'd15; // right
                neighbor_count[14] <= 4'd1;
                neighbors[15] <= 4'd14; // left
                neighbor_count[15] <= 4'd1;
            end else begin // 2x2 grid
                // 2x2 grid neighbor initialization
                neighbors[0] <= 4'd1; // right
                neighbor_count[0] <= 4'd1;
                neighbors[1] <= 4'd0; // left
                neighbor_count[1] <= 4'd1;
                neighbors[2] <= 4'd3; // right
                neighbor_count[2] <= 4'd1;
                neighbors[3] <= 4'd2; // left
                neighbor_count[3] <= 4'd1;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= LOAD_GRID;
                        busy <= 1'b1;
                    end
                end

                LOAD_GRID: begin
                    // Load grid_data into grid_mem
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        grid_mem[i] <= grid_data[i*4 +: 4]; // Extract 4-bit values
                    end
                    num_nodes <= grid_size ? 4'd16 : 4'd4;
                    state <= STEP_LOOP_INIT;
                end

                STEP_LOOP_INIT: begin
                    // Initialize step 0 paths
                    integer i;
                    for (i = 0; i < num_nodes; i = i + 1) begin
                        path_storage[0][i] <= grid_mem[i];
                    end
                    current_step <= 4'd0;
                    state <= STEP_LOOP_CALC;
                end

                STEP_LOOP_CALC: begin
                    if (current_step < k - 1) begin
                        // Process current step
                        if (current_node < num_nodes) begin
                            // Find best path to current_node
                            integer i;
                            for (i = 0; i < num_nodes; i = i + 1) begin
                                temp_path1[i] <= path_storage[current_step][i];
                            end

                            // Compare paths from neighbors
                            integer j;
                            for (j = 0; j < neighbor_count[current_node]; j = j + 1) begin
                                prev_node <= neighbors[current_node];
                                // Compare temp_path1 and path_storage[current_step][prev_node]
                                // This is a simplified comparison - in real implementation, you'd need a proper lex compare
                                if (path_storage[current_step][prev_node] < temp_path1[current_node]) begin
                                    temp_path1[current_node] <= path_storage[current_step][prev_node];
                                end
                            end

                            // Store best path
                            path_storage[current_step + 1][current_node] <= temp_path1[current_node];
                            current_node <= current_node + 1;
                        end else begin
                            current_node <= 4'd0;
                            current_step <= current_step + 1;
                        end
                    end else begin
                        state <= FIND_GLOBAL_MIN;
                    end
                end

                FIND_GLOBAL_MIN: begin
                    // Find best path among all nodes at step k-1
                    integer i;
                    for (i = 0; i < num_nodes; i = i + 1) begin
                        if (i == 0) begin
                            best_node <= i;
                        end else begin
                            if (path_storage[k-1][i] < path_storage[k-1][best_node]) begin
                                best_node <= i;
                            end
                        end
                    end
                    state <= OUTPUT_SEQ;
                    output_index <= 4'd0;
                end

                OUTPUT_SEQ: begin
                    if (output_index < k) begin
                        result <= path_storage[output_index][best_node];
                        step <= output_index;
                        valid <= 1'b1;
                        output_index <= output_index + 1;
                    end else begin
                        valid <= 1'b0;
                        busy <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule