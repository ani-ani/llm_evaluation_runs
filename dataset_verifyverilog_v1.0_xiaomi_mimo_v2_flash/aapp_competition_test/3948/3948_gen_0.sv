module k_multihedgehog_checker(
    input wire [3:0] n,           // Number of nodes (1-16)
    input wire [3:0] k,           // k parameter (1-15)
    input wire [15:0] adj [0:15], // Adjacency matrix: adj[i][j]=1 if edge i-j
    output reg valid              // 1 if valid k-multihedgehog
);

// Function to count set bits
function [3:0] count_bits;
    input [15:0] x;
    integer j;
    begin
        count_bits = 0;
        for (j = 0; j < 16; j = j + 1)
            count_bits = count_bits + x[j];
    end
endfunction

// Internal variables
reg [3:0] deg [0:15];          // Degrees for each node
reg [15:0] visited;             // Visited flags
reg [3:0] layer [0:15];         // BFS layers
reg [3:0] parent [0:15];        // Parent pointers
reg [3:0] queue [0:15];         // BFS queue
reg [3:0] head, tail;           // Queue pointers
reg [3:0] candidate, i, v, u;   // Loop variables
reg all_visited;                // All nodes visited
reg [3:0] max_layer;            // Maximum layer in BFS
reg valid_candidate;            // Valid candidate flag
integer iter;                   // BFS iteration counter

always @(*) begin
    // Initialize outputs
    valid = 1'b0;
    
    // Immediate rejection for k>3
    if (k > 3'd3) begin
        valid = 1'b0;
    end
    else begin
        // Compute degrees
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n)
                deg[i] = count_bits(adj[i]);
            else
                deg[i] = 4'd0;
        end
        
        // Try each candidate center
        for (candidate = 0; candidate < n; candidate = candidate + 1) begin
            if (!valid && deg[candidate] >= 3'd3) begin
                // Initialize BFS
                visited = 16'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    layer[i] = 4'd0;
                    parent[i] = 4'd15;  // Invalid parent (since n <= 16)
                end
                head = 4'd0;
                tail = 4'd0;
                queue[tail] = candidate; tail = tail + 1;
                visited[candidate] = 1'b1;
                layer[candidate] = 4'd0;
                parent[candidate] = 4'd15;
                
                // Bounded BFS (16 iterations max)
                for (iter = 0; iter < 16; iter = iter + 1) begin
                    if (head < tail) begin
                        u = queue[head]; head = head + 1;
                        for (v = 0; v < 16; v = v + 1) begin
                            if (v < n && adj[u][v] && !visited[v]) begin
                                visited[v] = 1'b1;
                                layer[v] = layer[u] + 1;
                                parent[v] = u;
                                queue[tail] = v; tail = tail + 1;
                            end
                        end
                    end
                end
                
                // Check all nodes visited
                all_visited = 1'b1;
                for (i = 0; i < n; i = i + 1)
                    if (!visited[i]) all_visited = 1'b0;
                
                // Find maximum layer
                max_layer = 4'd0;
                for (i = 0; i < n; i = i + 1)
                    if (layer[i] > max_layer) max_layer = layer[i];
                
                // Validate layer conditions
                if (all_visited && max_layer == k) begin
                    valid_candidate = 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        if (layer[i] == 4'd0 && deg[i] < 3'd3) valid_candidate = 1'b0;
                        else if (layer[i] > 4'd0 && layer[i] < k && deg[i] < 4'd4) valid_candidate = 1'b0;
                        else if (layer[i] == k && deg[i] != 4'd1) valid_candidate = 1'b0;
                        else if (layer[i] > k) valid_candidate = 1'b0;
                    end
                    if (valid_candidate) valid = 1'b1;
                end
            end
        end
    end
end
endmodule