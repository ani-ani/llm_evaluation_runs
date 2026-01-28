module GameSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] option_count_in,
    input wire [15:0] option_string_in,
    input wire [3:0] target_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_OPTIONS = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] current_node;
    reg [3:0] current_option;
    reg [3:0] current_target;
    reg [3:0] current_start;
    reg [7:0] iteration_count;
    reg [7:0] dist [0:15];
    reg [15:0] options [0:15][0:15];
    reg [3:0] n;
    reg update_occurred;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 4'd0;
            current_option <= 4'd0;
            current_target <= 4'd0;
            current_start <= 4'd0;
            iteration_count <= 8'd0;
            update_occurred <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
            
            // Initialize distances
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd255;
            end
            
            // Initialize options
            integer j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    options[i][j] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_OPTIONS;
                    n = n_in;
                    current_node = 4'd0;
                    current_option = 4'd0;
                end
            end
            
            LOAD_OPTIONS: begin
                if (current_option < option_count_in) begin
                    options[current_node][current_option] = option_string_in;
                    current_option = current_option + 4'd1;
                end else begin
                    current_option = 4'd0;
                    if (current_node < n - 4'd1) begin
                        current_node = current_node + 4'd1;
                    end else begin
                        next_state = COMPUTE;
                        current_target = 4'd0;
                        current_start = 4'd0;
                        iteration_count = 8'd0;
                        update_occurred = 1'b1;
                    end
                end
            end
            
            COMPUTE: begin
                if (update_occurred && iteration_count < 8'd255) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (current_start < n - 4'd1) begin
                    current_start = current_start + 4'd1;
                    next_state = COMPUTE;
                    iteration_count = 8'd0;
                    update_occurred = 1'b1;
                end else if (current_target < n - 4'd1) begin
                    current_target = current_target + 4'd1;
                    current_start = 4'd0;
                    next_state = COMPUTE;
                    iteration_count = 8'd0;
                    update_occurred = 1'b1;
                end else begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Distance computation
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            update_occurred = 1'b0;
            
            // Initialize target distance
            if (iteration_count == 8'd0) begin
                dist[current_target] = 8'd0;
            end
            
            // Compute new distances
            integer i, j;
            reg [7:0] min_dist;
            reg [7:0] worst_case;
            
            for (i = 0; i < n; i = i + 1) begin
                if (i == current_target) begin
                    // Target node, distance is 0
                    continue;
                end
                
                min_dist = 8'd255;
                
                // Check all options for this node
                for (j = 0; j < 16; j = j + 1) begin
                    if (options[i][j] != 16'd0) begin
                        worst_case = 8'd0;
                        
                        // Check all nodes in the option set
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (options[i][j][k]) begin
                                if (dist[k] > worst_case) begin
                                    worst_case = dist[k];
                                end
                            end
                        end
                        
                        // If all nodes in set have finite distance
                        if (worst_case < 8'd255) begin
                            if (worst_case + 8'd1 < min_dist) begin
                                min_dist = worst_case + 8'd1;
                            end
                        end
                    end
                end
                
                // Update distance if better
                if (min_dist < dist[i]) begin
                    dist[i] = min_dist;
                    update_occurred = 1'b1;
                end
            end
            
            iteration_count = iteration_count + 8'd1;
        end
    end
    
    // Output result
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            result = {8'd0, dist[current_start]};
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule