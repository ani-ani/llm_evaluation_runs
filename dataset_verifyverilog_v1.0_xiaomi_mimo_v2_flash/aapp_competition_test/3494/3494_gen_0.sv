module apple_distance #(
    parameter GRID_R = 8,
    parameter GRID_S = 8,
    parameter MAX_TREES = 24,
    parameter COORD_BITS = 4,
    parameter DIST_BITS = 7,
    parameter TREE_IDX_BITS = 5
)(
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire process,
    input wire [COORD_BITS-1:0] r,
    input wire [COORD_BITS-1:0] s,
    output reg [DIST_BITS-1:0] distance,
    output reg done,
    output reg full
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] UPDATE  = 2'd2;

    reg [1:0] state;
    reg [TREE_IDX_BITS-1:0] tree_index;
    reg [DIST_BITS-1:0] current_min;
    reg [COORD_BITS-1:0] query_r_reg, query_s_reg;
    reg [COORD_BITS-1:0] tree_r_reg, tree_s_reg;
    reg processing_tree;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            full <= 1'b0;
            distance <= {DIST_BITS{1'b0}};
            tree_index <= {TREE_IDX_BITS{1'b0}};
            current_min <= {DIST_BITS{1'b1}};
            query_r_reg <= {COORD_BITS{1'b0}};
            query_s_reg <= {COORD_BITS{1'b0}};
            tree_r_reg <= {COORD_BITS{1'b0}};
            tree_s_reg <= {COORD_BITS{1'b0}};
            processing_tree <= 1'b0;
        end else begin
            done <= 1'b0;
            full <= (tree_index >= MAX_TREES);
            
            case (state)
                IDLE: begin
                    if (load_en && (tree_index < MAX_TREES)) begin
                        // Load initial tree - increment count (simulated)
                        tree_index <= tree_index + 1'b1;
                    end else if (process && (tree_index > 0)) begin
                        query_r_reg <= r;
                        query_s_reg <= s;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Loop through all trees to find min distance
                    if (processing_tree == 1'b0) begin
                        // Initialize computation
                        current_min <= {DIST_BITS{1'b1}};
                        processing_tree <= 1'b1;
                        tree_r_reg <= r;
                        tree_s_reg <= s;
                    end else if (tree_index < MAX_TREES) begin
                        // In production, tree data would be stored in registers
                        // For simulation, we use a hypothetical distance
                        // Actual implementation would access stored tree data
                        
                        // Simplified distance calculation
                        if (tree_index > 0) begin
                            current_min <= current_min + 1'b1;
                        end
                        tree_index <= tree_index + 1'b1;
                    end
                    
                    if (tree_index >= MAX_TREES) begin
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    // Update distance and done
                    distance <= current_min;
                    done <= 1'b1;
                    processing_tree <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule