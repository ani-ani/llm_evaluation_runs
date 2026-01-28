module CycleBreaker #(
    parameter N_MAX = 8,
    parameter M_MAX = 16
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [3:0] src [0:M_MAX-1],
    input [3:0] dst [0:M_MAX-1],
    output reg [4:0] r,
    output reg [3:0] remove_list [0:M_MAX/2-1],
    output reg done
);
    
    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] INIT            = 4'd1;
    localparam [3:0] FIND_MAX        = 4'd2;
    localparam [3:0] APPEND          = 4'd3;
    localparam [3:0] UPDATE          = 4'd4;
    localparam [3:0] CHECK_DONE      = 4'd5;
    localparam [3:0] COMPUTE_REMOVAL = 4'd6;
    localparam [3:0] OUTPUT          = 4'd7;
    localparam [3:0] DONE_STATE      = 4'd8;
    
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Algorithm registers
    reg [0:N_MAX-1] active;
    reg [4:0] outdegree [0:N_MAX-1];
    reg [3:0] ordering [0:N_MAX-1];
    reg [3:0] position [0:N_MAX-1];
    reg [0:N_MAX-1][0:N_MAX-1] adj_matrix;
    
    reg [3:0] pos;
    reg [3:0] curr_vertex;
    reg [3:0] max_vertex;
    reg [4:0] max_degree;
    reg [4:0] edge_idx;
    reg [3:0] i, j;
    reg found;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize ALL registers
            state <= IDLE;
            cycle_count <= 8'd0;
            r <= 5'd0;
            done <= 1'b0;
            
            for (i = 0; i < N_MAX; i = i + 1) begin
                active[i] <= 1'b0;
                outdegree[i] <= 5'd0;
                ordering[i] <= 4'd0;
                position[i] <= 4'd0;
                for (j = 0; j < N_MAX; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end
            
            for (i = 0; i < M_MAX/2; i = i + 1) begin
                remove_list[i] <= 4'd0;
            end
            
            pos <= 4'd0;
            curr_vertex <= 4'd0;
            max_vertex <= 4'd0;
            max_degree <= 5'd0;
            edge_idx <= 5'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Clear adjacency matrix
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        for (j = 0; j < N_MAX; j = j + 1) begin
                            adj_matrix[i][j] <= 1'b0;
                        end
                        outdegree[i] <= 5'd0;
                    end
                    
                    // Build adjacency matrix and outdegrees
                    for (edge_idx = 0; edge_idx < M_MAX; edge_idx = edge_idx + 1) begin
                        if (edge_idx < m) begin
                            adj_matrix[src[edge_idx]][dst[edge_idx]] <= 1'b1;
                            outdegree[src[edge_idx]] <= outdegree[src[edge_idx]] + 5'd1;
                        end
                    end
                    
                    // Initialize active flags
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        active[i] <= (i < n) ? 1'b1 : 1'b0;
                    end
                    
                    pos <= 4'd0;
                    state <= FIND_MAX;
                end
                
                FIND_MAX: begin
                    max_degree <= 5'd0;
                    max_vertex <= 4'd0;
                    found <= 1'b0;
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        if (active[i] && outdegree[i] >= max_degree) begin
                            found <= 1'b1;
                            max_degree <= outdegree[i];
                            max_vertex <= i;
                        end
                    end
                    state <= found ? APPEND : CHECK_DONE;
                end
                
                APPEND: begin
                    ordering[pos] <= max_vertex;
                    position[max_vertex] <= pos;
                    active[max_vertex] <= 1'b0;
                    pos <= pos + 4'd1;
                    curr_vertex <= max_vertex;
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    // For all active vertices with edge to curr_vertex, decrement outdegree
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        if (active[i] && adj_matrix[i][curr_vertex]) begin
                            outdegree[i] <= outdegree[i] - 5'd1;
                        end
                    end
                    state <= CHECK_DONE;
                end
                
                CHECK_DONE: begin
                    if (pos < n) begin
                        state <= FIND_MAX;
                    end else begin
                        state <= COMPUTE_REMOVAL;
                    end
                end
                
                COMPUTE_REMOVAL: begin
                    r <= 5'd0;
                    // Reset remove_list in initialization - no need here
                    for (edge_idx = 0; edge_idx < M_MAX; edge_idx = edge_idx + 1) begin
                        if (edge_idx < m) begin
                            if (position[src[edge_idx]] > position[dst[edge_idx]]) begin
                                if (r < (M_MAX/2)) begin
                                    remove_list[r] <= edge_idx + 4'd1;  // 1-based index
                                end
                                r <= r + 5'd1;
                            end
                        end
                    end
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    if (r > (M_MAX/2)) begin
                        r <= M_MAX/2;
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout prevention
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
                $display("Timeout!");
            end
        end
    end
endmodule