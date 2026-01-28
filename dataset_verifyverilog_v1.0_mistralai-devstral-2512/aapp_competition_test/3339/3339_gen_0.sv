module EdgeDeletionCounter(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [5:0] edge_count,
    input [3:0] edge_a [0:31],
    input [3:0] edge_b [0:31],
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // Constants
    localparam MOD = 32'd1000000009;
    localparam MAX_NODES = 4'd16;
    localparam MAX_EDGES = 6'd32;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_MATRIX = 3'd1;
    localparam [2:0] GAUSS_ELIM = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Matrix storage (transposed: 32 columns x 16 rows)
    reg [15:0] matrix [0:31];
    reg [5:0] rank;
    reg [5:0] pivot_row [0:15];

    // Precomputed powers of 2 mod MOD
    reg [31:0] pow2 [0:32];

    // Control signals
    reg [5:0] current_edge;
    reg [3:0] current_node;
    reg [5:0] elim_col;
    reg [5:0] elim_row;

    // Initialize pow2 lookup table
    integer i;
    initial begin
        pow2[0] = 1;
        for (i = 1; i < 32; i = i + 1) begin
            pow2[i] = (pow2[i-1] * 2) % MOD;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            rank <= 6'd0;
            current_edge <= 6'd0;
            current_node <= 4'd0;
            elim_col <= 6'd0;
            elim_row <= 6'd0;
            
            // Clear matrix
            for (i = 0; i < 32; i = i + 1) begin
                matrix[i] <= 16'd0;
            end
            
            // Clear pivot tracking
            for (i = 0; i < 16; i = i + 1) begin
                pivot_row[i] <= 6'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= BUILD_MATRIX;
                        current_edge <= 6'd0;
                        current_node <= 4'd0;
                    end
                end

                BUILD_MATRIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build incidence matrix (transposed)
                    if (current_node < node_count) begin
                        // Set bit if edge is incident to current_node
                        if (edge_a[current_edge] == current_node || 
                            edge_b[current_edge] == current_node) begin
                            matrix[current_edge][current_node] <= 1'b1;
                        end else begin
                            matrix[current_edge][current_node] <= 1'b0;
                        end
                        
                        current_node <= current_node + 4'd1;
                    end else begin
                        current_node <= 4'd0;
                        if (current_edge < edge_count - 1) begin
                            current_edge <= current_edge + 6'd1;
                        end else begin
                            state <= GAUSS_ELIM;
                            elim_col <= 6'd0;
                            elim_row <= 6'd0;
                            rank <= 6'd0;
                            
                            // Initialize pivot tracking
                            for (i = 0; i < 16; i = i + 1) begin
                                pivot_row[i] <= 6'd32; // Invalid
                            end
                        end
                    end
                end

                GAUSS_ELIM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find pivot in current column
                    if (pivot_row[elim_col] == 6'd32) begin
                        // Search for first row with 1 in this column
                        for (i = elim_row; i < edge_count; i = i + 1) begin
                            if (matrix[i][elim_col]) begin
                                pivot_row[elim_col] <= i;
                                break;
                            end
                        end
                        
                        // If found, swap to current row
                        if (pivot_row[elim_col] != 6'd32) begin
                            if (pivot_row[elim_col] != elim_row) begin
                                // Swap rows
                                reg [15:0] temp;
                                temp <= matrix[elim_row];
                                matrix[elim_row] <= matrix[pivot_row[elim_col]];
                                matrix[pivot_row[elim_col]] <= temp;
                            end
                            rank <= rank + 6'd1;
                        end
                    end
                    
                    // Eliminate this column in other rows
                    if (pivot_row[elim_col] != 6'd32) begin
                        for (i = 0; i < edge_count; i = i + 1) begin
                            if (i != elim_row && matrix[i][elim_col]) begin
                                matrix[i] <= matrix[i] ^ matrix[elim_row];
                            end
                        end
                    end
                    
                    // Move to next column
                    elim_col <= elim_col + 6'd1;
                    elim_row <= elim_row + 6'd1;
                    
                    // Check completion
                    if (elim_col >= node_count || elim_row >= edge_count) begin
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    // Compute result = 2^(edge_count - rank) mod MOD
                    if (edge_count >= rank) begin
                        result <= pow2[edge_count - rank];
                    end else begin
                        result <= 32'd0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        end
    end

endmodule