module optimal_paths_length2 (
    input [15:0] adj_matrix [0:15],
    input [3:0] num_nodes,
    output reg [15:0] result
);

    // Internal wires to store the degree of each node
    wire [3:0] degree [0:15];
    
    // Temporary wires for sum of products
    wire [19:0] sum_temp [0:15]; // 20 bits to prevent overflow (max sum ~16*120=1920)

    integer i, j;

    // Step 1: Compute degree for each node
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            // Default degree to 0 if node index >= num_nodes to handle unused nodes safely
            if (i >= num_nodes) begin
                degree[i] = 4'd0;
            end else begin
                degree[i] = 4'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    if (j < num_nodes && adj_matrix[i][j]) begin
                        degree[i] = degree[i] + 1;
                    end
                end
            end
        end
    end

    // Step 2 & 3: Compute degree * (degree - 1) and accumulate sum
    always @(*) begin
        result = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < num_nodes) begin
                // degree * (degree - 1)
                // degree is max 15, so max product is 15*14 = 210
                result = result + (degree[i] * (degree[i] - 1));
            end
        end
    end

endmodule