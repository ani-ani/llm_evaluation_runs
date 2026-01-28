module MinPurchases(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] q,
    input wire [15:0] row_col_packed,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // DSU parameters
    localparam [7:0] MAX_NODES = 8'd200;
    reg [7:0] parent [0:199];
    reg [7:0] rank [0:199];
    reg [7:0] merges;
    
    // Input processing
    reg [7:0] current_q;
    reg [7:0] row_index;
    reg [7:0] col_index;
    reg [7:0] node_count;
    
    // Initialize DSU
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_q <= 8'd0;
            merges <= 8'd0;
            
            // Initialize DSU arrays
            for (i = 0; i < 200; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    current_q <= 8'd0;
                    merges <= 8'd0;
                    
                    // Initialize DSU arrays
                    for (i = 0; i < 200; i = i + 1) begin
                        parent[i] <= i;
                        rank[i] <= 8'd0;
                    end
                    
                    if (start) begin
                        state <= READ;
                        current_q <= q;
                        node_count <= 8'd0;
                    end
                end
                
                READ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_q > 8'd0) begin
                        // Extract row and column from packed input
                        row_index <= row_col_packed[15:8];
                        col_index <= row_col_packed[7:0];
                        
                        // Calculate node indices
                        // Rows: 0 to n-1, Columns: m to m+c-1
                        // For simplicity, assume n and m are known or derived
                        // Here we use row_index and col_index directly as node indices
                        
                        // Union the row and column nodes
                        if (row_index < MAX_NODES && col_index < MAX_NODES) begin
                            if (dsu_find(row_index) != dsu_find(col_index)) begin
                                dsu_union(row_index, col_index);
                                merges <= merges + 8'd1;
                            end
                        end
                        
                        current_q <= current_q - 8'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Simplified component calculation
                    result <= (MAX_NODES - merges) - 1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // DSU functions
    function [7:0] dsu_find;
        input [7:0] x;
        begin
            if (parent[x] != x) begin
                parent[x] = dsu_find(parent[x]);
            end
            dsu_find = parent[x];
        end
    endfunction
    
    function dsu_union;
        input [7:0] x, y;
        reg [7:0] x_root, y_root;
        begin
            x_root = dsu_find(x);
            y_root = dsu_find(y);
            if (x_root != y_root) begin
                if (rank[x_root] > rank[y_root]) begin
                    parent[y_root] = x_root;
                end else begin
                    parent[x_root] = y_root;
                    if (rank[x_root] == rank[y_root]) begin
                        rank[y_root] = rank[y_root] + 1;
                    end
                end
            end
        end
    endfunction
    
endmodule