module k_multihedgehog_checker(
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [15:0] adj [0:15],
    output reg valid
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
    reg [3:0] deg [0:15];
    reg [15:0] visited;
    reg [3:0] layer [0:15];
    reg [3:0] parent [0:15];
    reg [3:0] queue [0:15];
    reg [3:0] head, tail;
    reg [3:0] candidate, i, v, u;
    reg all_visited;
    reg [3:0] max_layer;
    reg valid_candidate;
    integer iter;

    always @(*) begin
        valid = 0;
        
        if (k > 3) begin
            valid = 0;
        end
        else begin
            for (i = 0; i < 16; i = i + 1) begin
                if (i < n)
                    deg[i] = count_bits(adj[i]);
                else
                    deg[i] = 0;
            end
            
            for (candidate = 0; candidate < n; candidate = candidate + 1) begin
                if (!valid && deg[candidate] >= 3) begin
                    visited = 0;
                    for (i = 0; i < 16; i = i + 1) begin
                        layer[i] = 0;
                        parent[i] = 16;
                    end
                    head = 0;
                    tail = 0;
                    queue[tail] = candidate; tail = tail + 1;
                    visited[candidate] = 1;
                    layer[candidate] = 0;
                    parent[candidate] = 16;
                    
                    for (iter = 0; iter < 16; iter = iter + 1) begin
                        if (head < tail) begin
                            u = queue[head]; head = head + 1;
                            for (v = 0; v < 16; v = v + 1) begin
                                if (v < n && adj[u][v] && !visited[v]) begin
                                    visited[v] = 1;
                                    layer[v] = layer[u] + 1;
                                    parent[v] = u;
                                    queue[tail] = v; tail = tail + 1;
                                end
                            end
                        end
                    end
                    
                    all_visited = 1;
                    for (i = 0; i < n; i = i + 1)
                        if (!visited[i]) all_visited = 0;
                    
                    max_layer = 0;
                    for (i = 0; i < n; i = i + 1)
                        if (layer[i] > max_layer) max_layer = layer[i];
                    
                    if (all_visited && max_layer == k) begin
                        valid_candidate = 1;
                        for (i = 0; i < n; i = i + 1) begin
                            if (layer[i] == 0 && deg[i] < 3) valid_candidate = 0;
                            else if (layer[i] > 0 && layer[i] < k && deg[i] < 4) valid_candidate = 0;
                            else if (layer[i] == k && deg[i] != 1) valid_candidate = 0;
                            else if (layer[i] > k) valid_candidate = 0;
                        end
                        if (valid_candidate) valid = 1;
                    end
                end
            end
        end
    end
endmodule