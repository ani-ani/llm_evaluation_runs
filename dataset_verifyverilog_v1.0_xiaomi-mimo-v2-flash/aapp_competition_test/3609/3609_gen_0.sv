module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire edge_valid,
    output reg [7:0] result_string [0:29],
    output reg valid,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] READ_EDGES  = 3'd1;
    localparam [2:0] SOLVE_CHECK = 3'd2;
    localparam [2:0] VALID_OUTPUT= 3'd3;
    localparam [2:0] IMPOSSIBLE  = 3'd4;

    // Constants
    localparam [3:0] MAX_N = 4'd16;
    localparam [7:0] MAX_EDGES = 8'd30;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] edge_count;
    reg [7:0] cycle_count;
    reg [3:0] edges_u [0:29];
    reg [3:0] edges_v [0:29];
    reg [3:0] n;
    
    // Degree and assignment tracking
    reg [3:0] deg [0:15];
    reg [3:0] deg_L [0:15];
    reg [3:0] deg_R [0:15];
    
    // Solver iteration variables
    reg [3:0] i;
    reg [3:0] j;
    reg [4:0] edge_idx;
    
    // Temporary calculation variables
    reg [7:0] temp_result;
    reg [7:0] char_idx;
    reg [7:0] digits;
    reg [7:0] temp_val;
    
    // Output buffer helpers
    reg [3:0] out_node;
    reg [3:0] out_deg;
    reg [7:0] out_char;

    integer k;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_count <= 8'd0;
            cycle_count <= 8'd0;
            valid <= 1'b0;
            impossible <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            edge_idx <= 5'd0;
            n <= 4'd0;
            // Initialize string buffer
            for (k = 0; k < 30; k = k + 1) begin
                result_string[k] <= 8'd32; // Space
            end
            // Initialize arrays
            for (k = 0; k < 16; k = k + 1) begin
                deg[k] <= 4'd0;
                deg_L[k] <= 4'd0;
                deg_R[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    edge_count <= 8'd0;
                    cycle_count <= 8'd0;
                    n <= 4'd0;
                    if (start) begin
                        state <= READ_EDGES;
                    end
                end

                READ_EDGES: begin
                    if (edge_valid && edge_count < MAX_EDGES) begin
                        edges_u[edge_count] <= edge_u;
                        edges_v[edge_count] <= edge_v;
                        edge_count <= edge_count + 8'd1;
                        // Update max node index
                        if (edge_u > n) n <= edge_u;
                        if (edge_v > n) n <= edge_v;
                        // Update degree
                        if (edge_u < 16) deg[edge_u] <= deg[edge_u] + 4'd1;
                        if (edge_v < 16) deg[edge_v] <= deg[edge_v] + 4'd1;
                    end else if (!edge_valid) begin
                        state <= SOLVE_CHECK;
                        i <= 4'd1; // Start from node 1
                        edge_idx <= 5'd0;
                    end
                end

                SOLVE_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // If edge count > 2*(n-1), impossible immediately
                    if (edge_count > 2 * (n - 1)) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        // Greedy assignment strategy
                        // Iterate through edges to assign L and R
                        if (edge_idx < edge_count) begin
                            // Try assign to L first
                            if (edges_u[edge_idx] < edges_v[edge_idx]) begin
                                // Check if v has L parent already (and not root)
                                if (edges_v[edge_idx] != 4'd1 && deg_L[edges_v[edge_idx]] == 4'd0) begin
                                    deg_L[edges_v[edge_idx]] <= 4'd1;
                                end else begin
                                    // Try assign to R
                                    if (edges_u[edge_idx] != 4'd1 && edges_v[edge_idx] != 4'd1 && 
                                        edges_u[edge_idx] != n && edges_v[edge_idx] != n && 
                                        deg_R[edges_u[edge_idx]] == 4'd0) begin
                                        // Ensure valid R assignment (u < v implies potential parent v for u)
                                        deg_R[edges_u[edge_idx]] <= 4'd1;
                                    end
                                end
                            end
                            edge_idx <= edge_idx + 5'd1;
                        end else begin
                            // Verification phase
                            if (i <= n) begin
                                // Check constraints
                                // Node 1: deg_L(1) must be 0. deg_R(1) must be 0 if 1 is not root of R (but 1 != n)
                                // Actually: L-tree root is 1 (no parent). R-tree root is n (no parent).
                                // L-tree: Every node u > 1 needs deg_L(u) == 1
                                // R-tree: Every node u < n needs deg_R(u) == 1
                                
                                if (i > 4'd1) begin
                                    if (deg_L[i] != 4'd1) begin
                                        state <= IMPOSSIBLE;
                                    end
                                end
                                if (i < n) begin
                                    if (deg_R[i] != 4'd1) begin
                                        state <= IMPOSSIBLE;
                                    end
                                end
                                i <= i + 4'd1;
                            end else begin
                                state <= VALID_OUTPUT;
                                char_idx <= 8'd0;
                                out_node <= 4'd1;
                            end
                        end
                    end
                    
                    // Timeout safety
                    if (cycle_count > MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end
                end

                VALID_OUTPUT: begin
                    // Construct output string format: "N:D "
                    // Iterate nodes 1 to n
                    if (out_node <= n) begin
                        // Calculate degree to print
                        if (out_node == 4'd1) out_deg <= deg_L[out_node] + deg_R[out_node]; // or just deg
                        else if (out_node == n) out_deg <= deg_L[out_node] + deg_R[out_node];
                        else out_deg <= deg_L[out_node] + deg_R[out_node];
                        
                        // Print Node Index
                        if (out_node >= 4'd10) begin
                            result_string[char_idx] <= 8'd49; // '1'
                            result_string[char_idx + 8'd1] <= (out_node - 8'd10) + 8'd48;
                            char_idx <= char_idx + 8'd2;
                        end else begin
                            result_string[char_idx] <= out_node + 8'd48;
                            char_idx <= char_idx + 8'd1;
                        end
                        
                        // Print ':'
                        result_string[char_idx] <= 8'd58;
                        char_idx <= char_idx + 8'd1;
                        
                        // Print Degree
                        if (out_deg >= 8'd10) begin
                             result_string[char_idx] <= 8'd49;
                             result_string[char_idx + 8'd1] <= (out_deg - 8'd10) + 8'd48;
                             char_idx <= char_idx + 8'd2;
                        end else begin
                             result_string[char_idx] <= out_deg + 8'd48;
                             char_idx <= char_idx + 8'd1;
                        end
                        
                        // Print Space
                        result_string[char_idx] <= 8'd32;
                        char_idx <= char_idx + 8'd1;
                        
                        out_node <= out_node + 4'd1;
                    end else begin
                        // Fill rest with spaces
                        if (char_idx < 8'd30) begin
                            result_string[char_idx] <= 8'd32;
                            char_idx <= char_idx + 8'd1;
                        end else begin
                            valid <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end

                IMPOSSIBLE: begin
                    // Write "IMPOSSIBLE"
                    if (char_idx < 8'd10) begin
                        case (char_idx)
                            8'd0: result_string[0] <= 8'd73; // I
                            8'd1: result_string[1] <= 8'd77; // M
                            8'd2: result_string[2] <= 8'd80; // P
                            8'd3: result_string[3] <= 8'd79; // O
                            8'd4: result_string[4] <= 8'd83; // S
                            8'd5: result_string[5] <= 8'd83; // S
                            8'd6: result_string[6] <= 8'd73; // I
                            8'd7: result_string[7] <= 8'd66; // B
                            8'd8: result_string[8] <= 8'd76; // L
                            8'd9: result_string[9] <= 8'd69; // E
                        endcase
                        char_idx <= char_idx + 8'd1;
                    end else if (char_idx < 8'd30) begin
                        result_string[char_idx] <= 8'd32;
                        char_idx <= char_idx + 8'd1;
                    end else begin
                        impossible <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule