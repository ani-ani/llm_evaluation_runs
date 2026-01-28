module max_new_edges (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [7:0] m,
    input [8:0] edges [0:31], // src[3:0], dst[7:4], packed into 9 bits (assuming 4-bit indices)
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE               = 3'd0;
    localparam [2:0] LOAD               = 3'd1;
    localparam [2:0] RESET_MATRIX       = 3'd2;
    localparam [2:0] TRANSITIVE_CLOSURE = 3'd3;
    localparam [2:0] COUNT              = 3'd4;
    localparam [2:0] FINISH             = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Storage
    reg [15:0] adj [0:15];   // 16 rows, 16 columns per row
    reg [15:0] reach [0:15]; // 16 rows, 16 columns per row
    
    // Indices and counters
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [4:0] edge_idx;
    reg [15:0] temp_reach;

    // Helper wires for logic
    wire [3:0] u;
    wire [3:0] v;
    wire edge_valid;
    
    // Extract source/destination from edge input
    // Assuming edges[i] format: {src[3:0], dst[3:0], 1-bit valid or unused}
    // If spec requires 9 bits, I'll use the full width. 
    // Input is 9 bits. Let's assume bits [3:0] are dst, [7:4] are src.
    // If edges are packed into 9 bits, bit 8 might be valid or unused.
    assign u = edges[edge_idx][7:4];
    assign v = edges[edge_idx][3:0];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (edge_idx >= m) next_state = RESET_MATRIX;
            end
            RESET_MATRIX: begin
                if (i >= n) next_state = TRANSITIVE_CLOSURE;
            end
            TRANSITIVE_CLOSURE: begin
                // Total iterations: n*n*n. 
                // We use loops k, i, j. 
                if (k >= n && i >= n && j >= n) next_state = COUNT;
            end
            COUNT: begin
                if (i >= n && j >= n) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            edge_idx <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            // Reset matrices
            for (int r = 0; r < 16; r++) begin
                adj[r] <= 16'd0;
                reach[r] <= 16'd0;
            end
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    edge_idx <= 5'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    result <= 16'd0;
                end

                LOAD: begin
                    // Load edge into adjacency matrix
                    // We must check if edge_idx is within valid range of edges array (0-31)
                    // If m > 32, we might have issues, but spec says max 32 entries.
                    if (edge_idx < 5'd32) begin
                        if (edges[edge_idx][8]) begin // Assuming bit 8 is a valid flag if needed, else just check < m
                            adj[u][v] <= 1'b1;
                        end
                    end
                    edge_idx <= edge_idx + 5'd1;
                end

                RESET_MATRIX: begin
                    // Initialize reach matrix with adj matrix
                    // Also set reach[i][i] = 1 (reflexive reachability)
                    if (i < n) begin
                        reach[i] <= adj[i]; // Copy row
                        // Set diagonal bit (self reachability)
                        // We need to set bit i in row i
                        // reach[i] is 16 bits. reach[i][i] should be 1.
                        // Using bit-wise OR
                        reach[i][i] <= 1'b1;
                        
                        i <= i + 4'd1;
                    end
                end

                TRANSITIVE_CLOSURE: begin
                    // Floyd-Warshall: reach[i][j] = reach[i][j] | (reach[i][k] & reach[k][j])
                    // Loop structure: k (outer), i (mid), j (inner)
                    if (k < n) begin
                        if (i < n) begin
                            if (j < n) begin
                                // If reach[i][k] is 1 and reach[k][j] is 1, set reach[i][j] to 1
                                if (reach[i][k] && reach[k][j]) begin
                                    reach[i][j] <= 1'b1;
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= 4'd0;
                            k <= k + 4'd1;
                        end
                    end else begin
                        // Done
                    end
                end

                COUNT: begin
                    // Count pairs (u, v) where u != v, adj[u][v] == 0, reach[u][v] == 0
                    if (i < n) begin
                        if (j < n) begin
                            if (i != j) begin // u != v
                                if (!adj[i][j] && !reach[i][j]) begin
                                    result <= result + 16'd1;
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule