module railway_network(
    input clk,
    input rst_n,
    input start,
    input valid_input,
    input [3:0] city_idx,
    input [7:0] city_name,
    input [3:0] edge_src,
    input [3:0] edge_dst,
    input [15:0] edge_cost,
    input [1:0] assignment_idx,
    input [3:0] assignment_src,
    input [3:0] assignment_dst,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FLOYD_SETUP = 3'd2;
    localparam [2:0] FLOYD_COMPUTE = 3'd3;
    localparam [2:0] ASSIGN_PROCESS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] city_idx_reg;
    reg [15:0] cost_matrix [0:15][0:15];
    reg [3:0] assignments_src [0:3];
    reg [3:0] assignments_dst [0:3];
    reg [3:0] floyd_i, floyd_j, floyd_k;
    reg [1:0] assign_idx;
    reg [15:0] total_cost;
    reg [3:0] processed_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Temporary registers for Floyd-Warshall
    reg [15:0] temp_cost;
    reg [15:0] new_cost;
    
    // For assignments processing
    reg [3:0] current_src;
    reg [3:0] current_dst;
    reg [15:0] current_path_cost;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 16'd0;
            cycle_count <= 8'd0;
            processed_count <= 4'd0;
            total_cost <= 16'd0;
            floyd_i <= 4'd0;
            floyd_j <= 4'd0;
            floyd_k <= 4'd0;
            assign_idx <= 2'd0;
            current_src <= 4'd0;
            current_dst <= 4'd0;
            current_path_cost <= 16'd0;
            
            // Initialize cost matrix with INF
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    if (i == j)
                        cost_matrix[i][j] <= 16'd0;
                    else
                        cost_matrix[i][j] <= 16'hFFFF; // INF
                end
            end
            
            // Initialize assignments
            for (i = 0; i < 4; i = i + 1) begin
                assignments_src[i] <= 4'd0;
                assignments_dst[i] <= 4'd0;
            end
        end else begin
            // State transition
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    processed_count <= 4'd0;
                    total_cost <= 16'd0;
                    if (start) begin
                        ready <= 1'b0;
                        floyd_i <= 4'd0;
                        floyd_j <= 4'd0;
                        floyd_k <= 4'd0;
                        assign_idx <= 2'd0;
                    end
                end
                
                INIT: begin
                    if (valid_input) begin
                        if (edge_src < 16 && edge_dst < 16) begin
                            // Update edge cost (take minimum for parallel edges)
                            if (edge_cost < cost_matrix[edge_src][edge_dst]) begin
                                cost_matrix[edge_src][edge_dst] <= edge_cost;
                            end
                        end
                        // Load assignment
                        if (assignment_idx < 4) begin
                            assignments_src[assignment_idx] <= assignment_src;
                            assignments_dst[assignment_idx] <= assignment_dst;
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FLOYD_SETUP: begin
                    // Reset Floyd-Warshall iteration
                    floyd_i <= 4'd0;
                    floyd_j <= 4'd0;
                    floyd_k <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FLOYD_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Floyd-Warshall inner computation
                    if (floyd_k < 16 && floyd_i < 16 && floyd_j < 16) begin
                        temp_cost <= cost_matrix[floyd_i][floyd_k] + cost_matrix[floyd_k][floyd_j];
                        
                        if (cost_matrix[floyd_i][floyd_k] != 16'hFFFF && 
                            cost_matrix[floyd_k][floyd_j] != 16'hFFFF) begin
                            new_cost <= cost_matrix[floyd_i][floyd_k] + cost_matrix[floyd_k][floyd_j];
                            
                            if (new_cost < cost_matrix[floyd_i][floyd_j]) begin
                                cost_matrix[floyd_i][floyd_j] <= new_cost;
                            end
                        end
                    end
                    
                    // Increment counters
                    floyd_j <= floyd_j + 4'd1;
                    if (floyd_j == 15) begin
                        floyd_j <= 4'd0;
                        floyd_i <= floyd_i + 4'd1;
                        if (floyd_i == 15) begin
                            floyd_i <= 4'd0;
                            floyd_k <= floyd_k + 4'd1;
                        end
                    end
                end
                
                ASSIGN_PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process each assignment
                    if (processed_count < 4) begin
                        current_src <= assignments_src[processed_count];
                        current_dst <= assignments_dst[processed_count];
                        current_path_cost <= cost_matrix[assignments_src[processed_count]]
                                                [assignments_dst[processed_count]];
                        
                        // Add to total (handle overflow)
                        if (current_path_cost != 16'hFFFF) begin
                            if (total_cost + current_path_cost < total_cost) begin
                                total_cost <= 16'hFFFF; // Overflow protection
                            end else begin
                                total_cost <= total_cost + current_path_cost;
                            end
                        end
                        
                        processed_count <= processed_count + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= (total_cost == 16'hFFFF) ? 16'd0 : total_cost;
                    done <= 1'b1;
                    ready <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                if (cycle_count >= 8'd50)  // Allow time for input loading
                    next_state = FLOYD_SETUP;
                else
                    next_state = INIT;
            end
            
            FLOYD_SETUP: begin
                next_state = FLOYD_COMPUTE;
            end
            
            FLOYD_COMPUTE: begin
                if (floyd_k >= 16)
                    next_state = ASSIGN_PROCESS;
                else
                    next_state = FLOYD_COMPUTE;
            end
            
            ASSIGN_PROCESS: begin
                if (processed_count >= 4)
                    next_state = FINISH;
                else
                    next_state = ASSIGN_PROCESS;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule