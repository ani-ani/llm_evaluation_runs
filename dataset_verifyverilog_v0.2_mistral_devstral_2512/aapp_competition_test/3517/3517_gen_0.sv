module airplane_construction (
    input clk,
    input rst_n,
    input start,
    input [2:0] step_count,
    input [7:0] step_times [0:7],
    input [7:0] dependencies [0:7],
    output reg [15:0] min_time,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        BUILD_GRAPH,
        COMPUTE_ORIGINAL,
        TRY_ELIMINATE,
        COMPUTE_ELIMINATED,
        UPDATE_MIN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] dist [0:7];
    reg [15:0] temp_dist [0:7];
    reg [15:0] current_min;
    reg [2:0] eliminate_step;
    reg [2:0] step_idx;
    reg [2:0] topo_idx;
    reg [7:0] topo_order [0:7];
    reg [7:0] topo_count;
    reg [7:0] visited;
    reg [7:0] in_degree [0:7];
    reg [7:0] queue [0:7];
    reg [2:0] queue_head, queue_tail;
    reg [15:0] cycle_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            min_time <= 0;
            cycle_count <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= BUILD_GRAPH;
                        cycle_count <= 0;
                        done <= 0;
                    end
                end
                
                BUILD_GRAPH: begin
                    // Initialize graph structures
                    for (int i = 0; i < 8; i++) begin
                        in_degree[i] <= 0;
                        dist[i] <= 0;
                        temp_dist[i] <= 0;
                    end
                    
                    // Calculate in-degrees
                    for (int i = 0; i < 8; i++) begin
                        for (int j = 0; j < 8; j++) begin
                            if (dependencies[i][j]) begin
                                in_degree[i] <= in_degree[i] + 1;
                            end
                        end
                    end
                    
                    next_state <= COMPUTE_ORIGINAL;
                end
                
                COMPUTE_ORIGINAL: begin
                    // Topological sort and compute original critical path
                    queue_head <= 0;
                    queue_tail <= 0;
                    visited <= 0;
                    
                    // Find nodes with in_degree 0
                    for (int i = 0; i < 8; i++) begin
                        if (i < step_count && in_degree[i] == 0) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 1;
                        end
                    end
                    
                    topo_count <= 0;
                    step_idx <= 0;
                    
                    // Initialize distances
                    for (int i = 0; i < 8; i++) begin
                        dist[i] <= (i == 0) ? step_times[i] : 0;
                    end
                    
                    next_state <= TRY_ELIMINATE;
                end
                
                TRY_ELIMINATE: begin
                    if (eliminate_step == step_count) begin
                        next_state <= DONE;
                        done <= 1;
                    end else begin
                        // Initialize temp_dist for eliminated case
                        for (int i = 0; i < 8; i++) begin
                            temp_dist[i] <= (i == eliminate_step) ? 0 : dist[i];
                        end
                        
                        // Reset topological processing
                        queue_head <= 0;
                        queue_tail <= 0;
                        visited <= 0;
                        topo_count <= 0;
                        step_idx <= 0;
                        
                        next_state <= COMPUTE_ELIMINATED;
                    end
                end
                
                COMPUTE_ELIMINATED: begin
                    // Process topological order
                    if (queue_head < queue_tail) begin
                        reg [2:0] current_node = queue[queue_head];
                        queue_head <= queue_head + 1;
                        
                        // Update distances for neighbors
                        for (int i = 0; i < 8; i++) begin
                            if (dependencies[i][current_node] && i < step_count) begin
                                in_degree[i] <= in_degree[i] - 1;
                                if (in_degree[i] == 0) begin
                                    queue[queue_tail] <= i;
                                    queue_tail <= queue_tail + 1;
                                end
                                
                                if (temp_dist[i] < temp_dist[current_node] + ((i == eliminate_step) ? 0 : step_times[i])) begin
                                    temp_dist[i] <= temp_dist[current_node] + ((i == eliminate_step) ? 0 : step_times[i]);
                                end
                            end
                        end
                    end else begin
                        // All nodes processed
                        next_state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    // Update minimum time
                    if (current_min > temp_dist[step_count-1]) begin
                        current_min <= temp_dist[step_count-1];
                    end
                    
                    eliminate_step <= eliminate_step + 1;
                    next_state <= TRY_ELIMINATE;
                end
                
                DONE: begin
                    min_time <= current_min;
                    done <= 1;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Cycle counter for latency
            if (current_state != IDLE && current_state != DONE) begin
                cycle_count <= cycle_count + 1;
                if (cycle_count == 200) begin
                    next_state <= DONE;
                end
            end
        end
    end

    // Default state transitions
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
            end
            
            BUILD_GRAPH: next_state = COMPUTE_ORIGINAL;
            
            COMPUTE_ORIGINAL: next_state = TRY_ELIMINATE;
            
            TRY_ELIMINATE: begin
                if (eliminate_step == step_count) next_state = DONE;
                else next_state = COMPUTE_ELIMINATED;
            end
            
            COMPUTE_ELIMINATED: begin
                if (queue_head >= queue_tail) next_state = UPDATE_MIN;
            end
            
            UPDATE_MIN: next_state = TRY_ELIMINATE;
            
            DONE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Initialize registers
    initial begin
        current_state = IDLE;
        next_state = IDLE;
        done = 0;
        min_time = 0;
        eliminate_step = 0;
        current_min = 16'hFFFF;
    end

endmodule