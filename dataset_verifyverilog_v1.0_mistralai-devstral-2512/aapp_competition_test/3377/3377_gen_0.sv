module wet_climbing_peg(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire graph_valid,
    input wire [15:0] graph_row,
    input wire [3:0] graph_node,
    input wire dry_plan_valid,
    input wire [5:0] dry_step,
    output reg [5:0] wet_step,
    output reg wet_valid,
    output reg wet_done,
    output reg [4:0] pegs_needed
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRAPH = 3'd1;
    localparam [2:0] LOAD_DRY = 3'd2;
    localparam [2:0] PROCESS = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Graph storage (16x16 bits)
    reg [15:0] graph [0:15];
    reg [3:0] graph_idx;
    
    // Dry plan FIFO (1024x6 bits)
    reg [5:0] dry_fifo [0:1023];
    reg [9:0] dry_wr_ptr, dry_rd_ptr;
    reg [9:0] dry_count;
    
    // Wet plan buffer (1024x6 bits)
    reg [5:0] wet_buffer [0:1023];
    reg [9:0] wet_wr_ptr, wet_rd_ptr;
    reg [9:0] wet_count;
    
    // Current state
    reg [15:0] current_pegs;
    reg [15:0] original_pegs;
    reg [4:0] max_pegs;
    reg [4:0] original_max;
    
    // Processing state
    reg [5:0] current_dry_step;
    reg [15:0] missing_deps;
    reg [3:0] insert_idx;
    reg insert_mode;
    
    // Error flag
    reg error_flag;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Initialize graph
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                graph[i] <= 16'd0;
            end
            graph_idx <= 4'd0;
            
            // Initialize FIFOs
            dry_wr_ptr <= 10'd0;
            dry_rd_ptr <= 10'd0;
            dry_count <= 10'd0;
            
            wet_wr_ptr <= 10'd0;
            wet_rd_ptr <= 10'd0;
            wet_count <= 10'd0;
            
            // Initialize state
            current_pegs <= 16'd0;
            original_pegs <= 16'd0;
            max_pegs <= 5'd0;
            original_max <= 5'd0;
            
            // Processing state
            current_dry_step <= 6'd0;
            missing_deps <= 16'd0;
            insert_idx <= 4'd0;
            insert_mode <= 1'b0;
            
            // Outputs
            wet_step <= 6'd0;
            wet_valid <= 1'b0;
            wet_done <= 1'b0;
            pegs_needed <= 5'd0;
            
            error_flag <= 1'b0;
        end else begin
            state <= next_state;
            
            // Load graph state
            if (state == LOAD_GRAPH && graph_valid) begin
                graph[graph_node] <= graph_row;
                if (graph_node == 4'd15) begin
                    next_state <= LOAD_DRY;
                end
            end
            
            // Load dry plan state
            if (state == LOAD_DRY && dry_plan_valid) begin
                dry_fifo[dry_wr_ptr] <= dry_step;
                dry_wr_ptr <= dry_wr_ptr + 10'd1;
                dry_count <= dry_count + 10'd1;
                
                if (dry_plan_valid && dry_wr_ptr == dry_count) begin
                    next_state <= PROCESS;
                end
            end
            
            // Process state
            if (state == PROCESS) begin
                // Check if we need to insert extra pegs
                if (insert_mode) begin
                    // Insert missing dependencies
                    if (insert_idx < 16) begin
                        if (missing_deps[insert_idx]) begin
                            // Add this peg
                            wet_buffer[wet_wr_ptr] <= {5'd0, insert_idx, 1'b1};
                            wet_wr_ptr <= wet_wr_ptr + 10'd1;
                            wet_count <= wet_count + 10'd1;
                            
                            // Update pegs
                            current_pegs[insert_idx] <= 1'b1;
                            
                            // Update max pegs
                            reg [4:0] current_count;
                            integer j;
                            current_count = 5'd0;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (current_pegs[j]) begin
                                    current_count = current_count + 5'd1;
                                end
                            end
                            
                            if (current_count > max_pegs) begin
                                max_pegs <= current_count;
                                if (current_count > 5'd32) begin  // 10 * 3.2 (max original)
                                    error_flag <= 1'b1;
                                end
                            end
                        end
                        insert_idx <= insert_idx + 4'd1;
                    end else begin
                        insert_mode <= 1'b0;
                        insert_idx <= 4'd0;
                    end
                end else begin
                    // Process next dry step
                    if (dry_rd_ptr < dry_count) begin
                        current_dry_step <= dry_fifo[dry_rd_ptr];
                        
                        reg [4:0] node;
                        reg add_op;
                        node = current_dry_step[4:0];
                        add_op = current_dry_step[5];
                        
                        if (add_op) begin
                            // Add operation - check dependencies
                            reg [15:0] deps;
                            deps = graph[node];
                            
                            reg [15:0] missing;
                            integer k;
                            missing = 16'd0;
                            for (k = 0; k < 16; k = k + 1) begin
                                if (deps[k] && !current_pegs[k]) begin
                                    missing[k] = 1'b1;
                                end
                            end
                            
                            if (missing == 16'd0) begin
                                // Safe to add
                                current_pegs[node] <= 1'b1;
                                original_pegs[node] <= 1'b1;
                                
                                // Update max pegs
                                reg [4:0] current_count;
                                integer m;
                                current_count = 5'd0;
                                for (m = 0; m < 16; m = m + 1) begin
                                    if (current_pegs[m]) begin
                                        current_count = current_count + 5'd1;
                                    end
                                end
                                
                                if (current_count > max_pegs) begin
                                    max_pegs <= current_count;
                                end
                                if (current_count > original_max) begin
                                    original_max <= current_count;
                                end
                                
                                // Output step
                                wet_buffer[wet_wr_ptr] <= current_dry_step;
                                wet_wr_ptr <= wet_wr_ptr + 10'd1;
                                wet_count <= wet_count + 10'd1;
                                
                                dry_rd_ptr <= dry_rd_ptr + 10'd1;
                            end else begin
                                // Need to insert dependencies
                                missing_deps <= missing;
                                insert_mode <= 1'b1;
                                insert_idx <= 4'd0;
                            end
                        end else begin
                            // Remove operation - check if safe
                            reg [15:0] deps;
                            deps = graph[node];
                            
                            reg safe;
                            integer n;
                            safe = 1'b1;
                            for (n = 0; n < 16; n = n + 1) begin
                                if (deps[n] && !current_pegs[n]) begin
                                    safe = 1'b0;
                                end
                            end
                            
                            if (safe) begin
                                // Safe to remove
                                current_pegs[node] <= 1'b0;
                                
                                // Output step
                                wet_buffer[wet_wr_ptr] <= current_dry_step;
                                wet_wr_ptr <= wet_wr_ptr + 10'd1;
                                wet_count <= wet_count + 10'd1;
                                
                                dry_rd_ptr <= dry_rd_ptr + 10'd1;
                            end else begin
                                // Need to insert dependencies
                                reg [15:0] missing;
                                integer p;
                                missing = 16'd0;
                                for (p = 0; p < 16; p = p + 1) begin
                                    if (deps[p] && !current_pegs[p]) begin
                                        missing[p] = 1'b1;
                                    end
                                end
                                
                                missing_deps <= missing;
                                insert_mode <= 1'b1;
                                insert_idx <= 4'd0;
                            end
                        end
                    end else begin
                        next_state <= DONE;
                    end
                end
            end
            
            // Done state
            if (state == DONE) begin
                wet_done <= 1'b1;
                pegs_needed <= max_pegs;
                if (error_flag) begin
                    pegs_needed <= 5'd31;  // Error indicator
                end
            end
        end
    end
    
    // Output wet steps
    always @(posedge clk) begin
        if (state == PROCESS || state == DONE) begin
            if (wet_rd_ptr < wet_wr_ptr) begin
                wet_step <= wet_buffer[wet_rd_ptr];
                wet_valid <= 1'b1;
                wet_rd_ptr <= wet_rd_ptr + 10'd1;
            end else begin
                wet_valid <= 1'b0;
            end
        end else begin
            wet_valid <= 1'b0;
        end
    end
    
    // State transitions
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_GRAPH;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD_GRAPH: begin
                if (graph_node == 4'd15 && graph_valid) begin
                    next_state = LOAD_DRY;
                end else begin
                    next_state = LOAD_GRAPH;
                end
            end
            
            LOAD_DRY: begin
                if (dry_plan_valid && dry_wr_ptr == dry_count) begin
                    next_state = PROCESS;
                end else begin
                    next_state = LOAD_DRY;
                end
            end
            
            PROCESS: begin
                if (dry_rd_ptr >= dry_count && !insert_mode) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Start processing
    always @(posedge clk) begin
        if (state == IDLE && start) begin
            next_state <= LOAD_GRAPH;
        end
    end

endmodule