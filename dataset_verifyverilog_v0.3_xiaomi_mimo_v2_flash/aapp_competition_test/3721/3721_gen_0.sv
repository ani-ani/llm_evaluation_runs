module chemical_table (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [63:0] grid,
    output reg [7:0] answer,
    output reg done
);

    // Parameters
    localparam [3:0] N = 4'd8;
    localparam [3:0] M = 4'd8;
    localparam [7:0] NM = 8'd64;  // N*M
    localparam [3:0] NODES = 4'd16; // N+M

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] INIT_DSU       = 4'd1;
    localparam [3:0] PROCESS_CELLS  = 4'd2;
    localparam [3:0] FIND_ROW       = 4'd3;
    localparam [3:0] FIND_COL       = 4'd4;
    localparam [3:0] MERGE          = 4'd5;
    localparam [3:0] COUNT_COMPONENTS = 4'd6;
    localparam [3:0] DONE           = 4'd7;

    // Internal state registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] current_cell;
    reg [3:0] current_node;
    reg [3:0] count;
    
    // DSU arrays (16 elements, 4-bit parent, 2-bit rank)
    reg [3:0] parent [0:15];
    reg [1:0] rank   [0:15];
    
    // Temporary storage for union/find
    reg [3:0] row_root;
    reg [3:0] col_root;
    reg [3:0] temp_node;
    reg [3:0] find_node;
    reg [3:0] root_a;
    reg [3:0] root_b;
    
    // Iteration counter for find operations
    reg [3:0] find_iter;
    
    // Flags
    reg processing_cell;
    reg found_root;

    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_DSU;
                else
                    next_state = IDLE;
            end
            
            INIT_DSU: begin
                next_state = PROCESS_CELLS;
            end
            
            PROCESS_CELLS: begin
                if (current_cell >= NM) begin
                    next_state = COUNT_COMPONENTS;
                end else if (processing_cell) begin
                    next_state = FIND_ROW;
                end else begin
                    next_state = PROCESS_CELLS;
                end
            end
            
            FIND_ROW: begin
                if (found_root)
                    next_state = FIND_COL;
                else
                    next_state = FIND_ROW;
            end
            
            FIND_COL: begin
                if (found_root)
                    next_state = MERGE;
                else
                    next_state = FIND_COL;
            end
            
            MERGE: begin
                next_state = PROCESS_CELLS;
            end
            
            COUNT_COMPONENTS: begin
                if (current_node >= NODES)
                    next_state = DONE;
                else
                    next_state = COUNT_COMPONENTS;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            answer <= 8'd0;
            done <= 1'b0;
            current_cell <= 8'd0;
            current_node <= 4'd0;
            count <= 4'd0;
            row_root <= 4'd0;
            col_root <= 4'd0;
            temp_node <= 4'd0;
            find_node <= 4'd0;
            root_a <= 4'd0;
            root_b <= 4'd0;
            find_iter <= 4'd0;
            processing_cell <= 1'b0;
            found_root <= 1'b0;
            
            // Initialize DSU arrays
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
                rank[i] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_cell <= 8'd0;
                        current_node <= 4'd0;
                        count <= 4'd0;
                        processing_cell <= 1'b0;
                    end
                end
                
                INIT_DSU: begin
                    // Initialize parent to self and rank to 0
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= i[3:0];
                        rank[i] <= 2'd0;
                    end
                end
                
                PROCESS_CELLS: begin
                    if (current_cell < NM) begin
                        // Extract i and j
                        // i = current_cell / M, j = current_cell % M
                        // For M=8, divide by 8 is shift right 3
                        // For M=8, mod 8 is lower 3 bits
                        // Since M=8 is constant, we can use shifts
                        // But for generic: i = current_cell >> 3, j = current_cell[2:0]
                        
                        // Check bounds and grid bit
                        // Use temporary variables for calculation
                        reg [3:0] i_calc;
                        reg [2:0] j_calc;
                        i_calc = current_cell[7:3]; // Divide by 8
                        j_calc = current_cell[2:0]; // Mod 8
                        
                        // Check if valid cell and grid bit is set
                        if ((i_calc < n) && (j_calc < m) && (grid[current_cell])) begin
                            processing_cell <= 1'b1;
                            find_node <= i_calc; // Row node
                        end else begin
                            processing_cell <= 1'b0;
                            current_cell <= current_cell + 8'd1;
                        end
                    end
                end
                
                FIND_ROW: begin
                    if (parent[find_node] == find_node) begin
                        row_root <= find_node;
                        found_root <= 1'b1;
                    end else begin
                        found_root <= 1'b0;
                        find_node <= parent[find_node];
                    end
                end
                
                FIND_COL: begin
                    // Extract j from current_cell
                    reg [2:0] j_calc;
                    j_calc = current_cell[2:0];
                    // Column node is N + j
                    if (state == FIND_COL && !found_root) begin
                        if (parent[find_node] == find_node) begin
                            col_root <= find_node;
                            found_root <= 1'b1;
                        end else begin
                            found_root <= 1'b0;
                            find_node <= parent[find_node];
                        end
                    end else if (state == MERGE && current_state_is_find_col) begin
                        // Start find for column
                        find_node <= N + {1'b0, j_calc};
                        found_root <= 1'b0;
                    end
                end
                
                MERGE: begin
                    if (row_root != col_root) begin
                        // Merge by rank
                        if (rank[row_root] < rank[col_root]) begin
                            parent[row_root] <= col_root;
                        end else if (rank[row_root] > rank[col_root]) begin
                            parent[col_root] <= row_root;
                        end else begin
                            // Equal rank, attach col to row and increment row's rank
                            parent[col_root] <= row_root;
                            rank[row_root] <= rank[row_root] + 2'd1;
                        end
                    end
                    current_cell <= current_cell + 8'd1;
                end
                
                COUNT_COMPONENTS: begin
                    // Skip rows >= n and columns >= N+m
                    // Node 0..15, columns are 8..15
                    if (current_node < n) begin
                        // Row node
                        if (parent[current_node] == current_node)
                            count <= count + 4'd1;
                        current_node <= current_node + 4'd1;
                    end else if (current_node < (N + m)) begin
                        // Column node
                        if (parent[current_node] == current_node)
                            count <= count + 4'd1;
                        current_node <= current_node + 4'd1;
                    end else begin
                        // Skip this node
                        current_node <= current_node + 4'd1;
                    end
                    
                    // Calculate answer (max(0, components - 1))
                    // Done when current_node >= NODES
                    if (current_node >= NODES - 4'd1) begin
                        // Final answer calculation
                        if (count > 4'd0)
                            answer <= {4'd0, count} - 8'd1;
                        else
                            answer <= 8'd0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    count <= 4'd0; // Reset for next operation
                end
            endcase
            
            // Update state
            state <= next_state;
        end
    end

    // Helper signals for FIND_COL state
    reg current_state_is_find_col;
    always @(posedge clk) begin
        current_state_is_find_col <= (next_state == FIND_COL) && (state != FIND_COL);
    end

endmodule