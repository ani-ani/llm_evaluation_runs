module WetClimbingPeg(
    input clk,
    input rst_n,
    input start,
    input graph_valid,
    input [15:0] graph_row,
    input [3:0] graph_node,
    input dry_plan_valid,
    input [5:0] dry_step,
    output reg [5:0] wet_step,
    output reg wet_valid,
    output reg wet_done,
    output reg [4:0] pegs_needed
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_GRAPH = 3'd1;
    localparam [2:0] LOAD_DRY   = 3'd2;
    localparam [2:0] PROCESS    = 3'd3;
    localparam [2:0] OUTPUT_WET = 3'd4;
    localparam [2:0] DONE       = 3'd5;
    localparam [2:0] ERROR      = 3'd6;
    
    // Graph RAM: 16x16 bits (16 rows, 16 cols)
    reg [15:0] graph_ram [0:15];
    
    // Dry plan FIFO: 1024x6 bits (simplified as RAM with pointers)
    reg [5:0] dry_ram [0:1023];
    reg [9:0] dry_head;
    reg [9:0] dry_tail;
    
    // Wet plan output buffer: 1024x6 bits
    reg [5:0] wet_ram [0:1023];
    reg [9:0] wet_wr_ptr;
    reg [9:0] wet_rd_ptr;
    
    // State machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [3:0] graph_idx;
    reg [15:0] current_pegs;
    reg [15:0] original_pegs;
    reg [9:0] dry_idx;
    reg [9:0] wet_idx;
    reg [4:0] peg_count;
    reg [4:0] max_peg_count;
    reg [4:0] original_max_peg_count;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // For processing wet plan
    reg processing_phase;
    reg [5:0] current_dry_step;
    reg [15:0] deps_missing;
    reg [3:0] dep_idx;
    reg dep_check_done;
    
    // Error flag
    reg error_flag;
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            wet_done <= 1'b0;
            wet_valid <= 1'b0;
            pegs_needed <= 5'd0;
            cycle_count <= 10'd0;
            error_flag <= 1'b0;
            
            // Initialize all registers
            graph_idx <= 4'd0;
            current_pegs <= 16'd0;
            original_pegs <= 16'd0;
            dry_idx <= 10'd0;
            wet_idx <= 10'd0;
            peg_count <= 5'd0;
            max_peg_count <= 5'd0;
            original_max_peg_count <= 5'd0;
            dry_head <= 10'd0;
            dry_tail <= 10'd0;
            wet_wr_ptr <= 10'd0;
            wet_rd_ptr <= 10'd0;
            processing_phase <= 1'b0;
            current_dry_step <= 6'd0;
            deps_missing <= 16'd0;
            dep_idx <= 4'd0;
            dep_check_done <= 1'b0;
            
            // Initialize RAMs
            for (i = 0; i < 16; i = i + 1) begin
                graph_ram[i] <= 16'd0;
            end
            for (i = 0; i < 1024; i = i + 1) begin
                dry_ram[i] <= 6'd0;
                wet_ram[i] <= 6'd0;
            end
        end else begin
            cycle_count <= cycle_count + 10'd1;
            
            case (state)
                IDLE: begin
                    wet_done <= 1'b0;
                    wet_valid <= 1'b0;
                    error_flag <= 1'b0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        state <= LOAD_GRAPH;
                        graph_idx <= 4'd0;
                    end
                end
                
                LOAD_GRAPH: begin
                    if (graph_valid) begin
                        graph_ram[graph_node] <= graph_row;
                        graph_idx <= graph_idx + 4'd1;
                        if (graph_idx == 4'd15) begin
                            state <= LOAD_DRY;
                        end
                    end
                end
                
                LOAD_DRY: begin
                    if (dry_plan_valid) begin
                        dry_ram[dry_tail] <= dry_step;
                        dry_tail <= dry_tail + 10'd1;
                        if (dry_step[0] == 1'b1) begin
                            // ADD operation - count as original peg
                            original_pegs <= original_pegs | (16'd1 << dry_step[5:1]);
                        end
                    end
                    if (!dry_plan_valid && start) begin
                        // Start processing when loading done
                        state <= PROCESS;
                        dry_idx <= 10'd0;
                        peg_count <= 5'd0;
                        max_peg_count <= 5'd0;
                        original_max_peg_count <= 5'd0;
                        current_pegs <= 16'd0;
                        wet_wr_ptr <= 10'd0;
                        processing_phase <= 1'b1;
                        dep_check_done <= 1'b0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= 10'd0;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= ERROR;
                    end else if (dry_idx < dry_tail) begin
                        // Start processing a dry step
                        if (!processing_phase) begin
                            current_dry_step <= dry_ram[dry_idx];
                            processing_phase <= 1'b1;
                            dep_check_done <= 1'b0;
                            dep_idx <= 4'd0;
                            deps_missing <= 16'd0;
                        end
                        
                        // Check dependencies if REMOVE operation
                        if (current_dry_step[0] == 1'b0 && !dep_check_done) begin
                            // REMOVE - check if safe
                            if (dep_idx < 4'd16) begin
                                // Check each dependency
                                if (graph_ram[current_dry_step[5:1]][dep_idx] == 1'b1) begin
                                    // This node depends on dep_idx
                                    if (current_pegs[dep_idx] == 1'b0) begin
                                        deps_missing[dep_idx] <= 1'b1;
                                    end
                                end
                                dep_idx <= dep_idx + 4'd1;
                            end else begin
                                dep_check_done <= 1'b1;
                            end
                        end
                        
                        // Generate wet plan steps
                        if (dep_check_done || current_dry_step[0] == 1'b1) begin
                            if (current_dry_step[0] == 1'b0 && (|deps_missing)) begin
                                // Remove is unsafe - output extra ADDs first
                                if (dep_idx < 4'd16) begin
                                    // Find next missing dependency
                                    if (deps_missing[dep_idx]) begin
                                        // Output ADD for this dependency
                                        wet_ram[wet_wr_ptr] <= {dep_idx, 1'b1};
                                        wet_wr_ptr <= wet_wr_ptr + 10'd1;
                                        current_pegs[current_pegs] <= 1'b1;
                                        peg_count <= peg_count + 5'd1;
                                        if (peg_count + 5'd1 > max_peg_count) begin
                                            max_peg_count <= peg_count + 5'd1;
                                        end
                                        deps_missing[dep_idx] <= 1'b0;
                                        dep_idx <= dep_idx + 4'd1;
                                    end else begin
                                        dep_idx <= dep_idx + 4'd1;
                                    end
                                end else begin
                                    // All missing dependencies added, now output original REMOVE
                                    wet_ram[wet_wr_ptr] <= current_dry_step;
                                    wet_wr_ptr <= wet_wr_ptr + 10'd1;
                                    current_pegs[current_dry_step[5:1]] <= 1'b0;
                                    peg_count <= peg_count - 5'd1;
                                    dry_idx <= dry_idx + 10'd1;
                                    processing_phase <= 1'b0;
                                end
                            end else begin
                                // Safe operation - output as is
                                wet_ram[wet_wr_ptr] <= current_dry_step;
                                wet_wr_ptr <= wet_wr_ptr + 10'd1;
                                if (current_dry_step[0] == 1'b1) begin
                                    // ADD
                                    current_pegs[current_dry_step[5:1]] <= 1'b1;
                                    peg_count <= peg_count + 5'd1;
                                    if (peg_count + 5'd1 > max_peg_count) begin
                                        max_peg_count <= peg_count + 5'd1;
                                    end
                                end else begin
                                    // REMOVE
                                    current_pegs[current_dry_step[5:1]] <= 1'b0;
                                    peg_count <= peg_count - 5'd1;
                                end
                                dry_idx <= dry_idx + 10'd1;
                                processing_phase <= 1'b0;
                            end
                        end
                    end else begin
                        // Processing complete
                        if (max_peg_count > 10 * original_max_peg_count) begin
                            state <= ERROR;
                        end else begin
                            state <= OUTPUT_WET;
                            wet_rd_ptr <= 10'd0;
                            pegs_needed <= max_peg_count;
                        end
                    end
                end
                
                OUTPUT_WET: begin
                    if (wet_rd_ptr < wet_wr_ptr) begin
                        wet_step <= wet_ram[wet_rd_ptr];
                        wet_valid <= 1'b1;
                        wet_rd_ptr <= wet_rd_ptr + 10'd1;
                    end else begin
                        wet_valid <= 1'b0;
                        wet_done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Stay in done state
                end
                
                ERROR: begin
                    error_flag <= 1'b1;
                    wet_done <= 1'b1;
                    // Output special error value
                    wet_step <= 6'b111111;
                    wet_valid <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule