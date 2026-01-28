module StickRemoval(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [13:0] x1_0, y1_0, x2_0, y2_0,
    input wire [13:0] x1_1, y1_1, x2_1, y2_1,
    input wire [13:0] x1_2, y1_2, x2_2, y2_2,
    input wire [13:0] x1_3, y1_3, x2_3, y2_3,
    input wire [13:0] x1_4, y1_4, x2_4, y2_4,
    input wire [13:0] x1_5, y1_5, x2_5, y2_5,
    input wire [13:0] x1_6, y1_6, x2_6, y2_6,
    input wire [13:0] x1_7, y1_7, x2_7, y2_7,
    output reg [3:0] data_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_DEPS = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Latch inputs
    reg [13:0] x1_latched [0:7];
    reg [13:0] y1_latched [0:7];
    reg [13:0] x2_latched [0:7];
    reg [13:0] y2_latched [0:7];
    reg [3:0] N_latched;

    // Dependency matrix: deps[i][j] = 1 if j depends on i (i must be removed before j)
    reg [7:0] deps [0:7];
    
    // Indegree count for each node
    reg [3:0] indegree [0:7];

    // Output queue
    reg [3:0] output_queue [0:7];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;

    // Intermediate computation registers
    reg [13:0] x1_i_reg, x2_i_reg, y1_i_reg, y2_i_reg;
    reg [13:0] x1_j_reg, x2_j_reg, y1_j_reg, y2_j_reg;
    reg [13:0] x_start_reg, x_end_reg;
    reg [63:0] y_i_start, y_i_end, y_j_start, y_j_end;
    reg is_below_start, is_below_end;
    reg x_overlap;

    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            data_out <= 4'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            N_latched <= 4'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                x1_latched[i] <= 14'd0;
                y1_latched[i] <= 14'd0;
                x2_latched[i] <= 14'd0;
                y2_latched[i] <= 14'd0;
                deps[i] <= 8'd0;
                indegree[i] <= 4'd0;
                output_queue[i] <= 4'd0;
            end
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            
            x1_i_reg <= 14'd0;
            x2_i_reg <= 14'd0;
            y1_i_reg <= 14'd0;
            y2_i_reg <= 14'd0;
            x1_j_reg <= 14'd0;
            x2_j_reg <= 14'd0;
            y1_j_reg <= 14'd0;
            y2_j_reg <= 14'd0;
            x_start_reg <= 14'd0;
            x_end_reg <= 14'd0;
            y_i_start <= 64'd0;
            y_i_end <= 64'd0;
            y_j_start <= 64'd0;
            y_j_end <= 64'd0;
            is_below_start <= 1'b0;
            is_below_end <= 1'b0;
            x_overlap <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Latch inputs
                        N_latched <= N;
                        for (i = 0; i < 8; i = i + 1) begin
                            case (i)
                                4'd0: begin
                                    x1_latched[i] <= x1_0;
                                    y1_latched[i] <= y1_0;
                                    x2_latched[i] <= x2_0;
                                    y2_latched[i] <= y2_0;
                                end
                                4'd1: begin
                                    x1_latched[i] <= x1_1;
                                    y1_latched[i] <= y1_1;
                                    x2_latched[i] <= x2_1;
                                    y2_latched[i] <= y2_1;
                                end
                                4'd2: begin
                                    x1_latched[i] <= x1_2;
                                    y1_latched[i] <= y1_2;
                                    x2_latched[i] <= x2_2;
                                    y2_latched[i] <= y2_2;
                                end
                                4'd3: begin
                                    x1_latched[i] <= x1_3;
                                    y1_latched[i] <= y1_3;
                                    x2_latched[i] <= x2_3;
                                    y2_latched[i] <= y2_3;
                                end
                                4'd4: begin
                                    x1_latched[i] <= x1_4;
                                    y1_latched[i] <= y1_4;
                                    x2_latched[i] <= x2_4;
                                    y2_latched[i] <= y2_4;
                                end
                                4'd5: begin
                                    x1_latched[i] <= x1_5;
                                    y1_latched[i] <= y1_5;
                                    x2_latched[i] <= x2_5;
                                    y2_latched[i] <= y2_5;
                                end
                                4'd6: begin
                                    x1_latched[i] <= x1_6;
                                    y1_latched[i] <= y1_6;
                                    x2_latched[i] <= x2_6;
                                    y2_latched[i] <= y2_6;
                                end
                                4'd7: begin
                                    x1_latched[i] <= x1_7;
                                    y1_latched[i] <= y1_7;
                                    x2_latched[i] <= x2_7;
                                    y2_latched[i] <= y2_7;
                                end
                            endcase
                        end
                        
                        // Initialize dependency matrix and indegrees
                        for (i = 0; i < 8; i = i + 1) begin
                            deps[i] <= 8'd0;
                            indegree[i] <= 4'd0;
                        end
                        
                        state <= COMPUTE_DEPS;
                    end
                end
                
                COMPUTE_DEPS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute dependencies for all pairs
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N_latched) begin
                            x1_i_reg <= x1_latched[i];
                            y1_i_reg <= y1_latched[i];
                            x2_i_reg <= x2_latched[i];
                            y2_i_reg <= y2_latched[i];
                            
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j < N_latched && i != j) begin
                                    x1_j_reg <= x1_latched[j];
                                    y1_j_reg <= y1_latched[j];
                                    x2_j_reg <= x2_latched[j];
                                    y2_j_reg <= y2_latched[j];
                                    
                                    // Check x-overlap
                                    x_start_reg <= (x1_i_reg > x1_j_reg) ? x1_i_reg : x1_j_reg;
                                    x_end_reg <= (x2_i_reg < x2_j_reg) ? x2_i_reg : x2_j_reg;
                                    x_overlap <= (x_start_reg < x_end_reg);
                                    
                                    if (x_overlap) begin
                                        // Compute y values at x_start and x_end using 64-bit arithmetic
                                        // y = y1 + (y2 - y1) * (x - x1) / (x2 - x1)
                                        // For stick i at x_start
                                        y_i_start <= $signed({32'd0, y1_i_reg}) + 
                                                    ($signed({32'd0, y2_i_reg}) - $signed({32'd0, y1_i_reg})) * 
                                                    ($signed({32'd0, x_start_reg}) - $signed({32'd0, x1_i_reg})) / 
                                                    ($signed({32'd0, x2_i_reg}) - $signed({32'd0, x1_i_reg}));
                                        
                                        // For stick i at x_end
                                        y_i_end <= $signed({32'd0, y1_i_reg}) + 
                                                  ($signed({32'd0, y2_i_reg}) - $signed({32'd0, y1_i_reg})) * 
                                                  ($signed({32'd0, x_end_reg}) - $signed({32'd0, x1_i_reg})) / 
                                                  ($signed({32'd0, x2_i_reg}) - $signed({32'd0, x1_i_reg}));
                                        
                                        // For stick j at x_start
                                        y_j_start <= $signed({32'd0, y1_j_reg}) + 
                                                    ($signed({32'd0, y2_j_reg}) - $signed({32'd0, y1_j_reg})) * 
                                                    ($signed({32'd0, x_start_reg}) - $signed({32'd0, x1_j_reg})) / 
                                                    ($signed({32'd0, x2_j_reg}) - $signed({32'd0, x1_j_reg}));
                                        
                                        // For stick j at x_end
                                        y_j_end <= $signed({32'd0, y1_j_reg}) + 
                                                  ($signed({32'd0, y2_j_reg}) - $signed({32'd0, y1_j_reg})) * 
                                                  ($signed({32'd0, x_end_reg}) - $signed({32'd0, x1_j_reg})) / 
                                                  ($signed({32'd0, x2_j_reg}) - $signed({32'd0, x1_j_reg}));
                                        
                                        // Check if j is below i at both points
                                        is_below_start <= (y_j_start < y_i_start);
                                        is_below_end <= (y_j_end < y_i_end);
                                        
                                        if (is_below_start && is_below_end) begin
                                            // j is below i, so i must be removed before j
                                            deps[i][j] <= 1'b1;
                                            indegree[j] <= indegree[j] + 4'd1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    // Transition to OUTPUT state
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    valid_out <= 1'b0;
                    
                    // Find nodes with indegree 0
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N_latched && indegree[i] == 4'd0) begin
                            // Add to output queue
                            output_queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 4'd1;
                            
                            // Decrement indegrees of successors
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j < N_latched && deps[i][j]) begin
                                    indegree[j] <= indegree[j] - 4'd1;
                                end
                            end
                            
                            // Mark this node as processed
                            indegree[i] <= 4'd16; // Use invalid value to mark as processed
                        end
                    end
                    
                    // Output from queue
                    if (queue_head < queue_tail) begin
                        data_out <= output_queue[queue_head];
                        valid_out <= 1'b1;
                        queue_head <= queue_head + 4'd1;
                    end else if (queue_head == queue_tail && queue_head > 4'd0) begin
                        // All outputs done
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule