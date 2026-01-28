module ski_probability (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Configuration
    input wire [3:0] node_count, // 0-16
    input wire [4:0] edge_count, // 0-32
    
    // Input edges (16 slots, packed: [31:24]Src, [23:16]Dest, [15:0]Weight(Q16.16))
    input wire [31:0] edge_data_i,
    input wire [4:0] edge_idx_i, // 0-31
    input wire edge_wr_en,
    
    // Output (K=0..15)
    output reg out_valid,
    output reg signed [31:0] prob_k, // Q16.16
    output reg [3:0] k_idx // Current k being output
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_EDGE = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Edge storage (32 entries)
    reg [31:0] edges [0:31];
    reg [4:0] edge_wr_ptr;
    
    // DP state
    reg signed [31:0] prob [0:15]; // Q16.16 probabilities
    reg [3:0] k; // Current iteration
    reg [3:0] node_count_reg, node_count_next;
    reg [4:0] edge_count_reg, edge_count_next;
    
    // Internal signals
    reg [3:0] src, dest;
    reg signed [31:0] weight, new_prob;
    reg [4:0] edge_idx;
    reg [3:0] max_node;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            out_valid <= 1'b0;
            prob_k <= 32'd0;
            k_idx <= 4'd0;
            
            // Initialize edge storage
            edge_wr_ptr <= 5'd0;
            for (integer i = 0; i < 32; i = i + 1) begin
                edges[i] <= 32'd0;
            end
            
            // Initialize DP state
            k <= 4'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                prob[i] <= 32'd0;
            end
            prob[0] <= 32'd32768; // 1.0 in Q16.16
            
            node_count_reg <= 4'd0;
            node_count_next <= 4'd0;
            edge_count_reg <= 5'd0;
            edge_count_next <= 5'd0;
        end else begin
            state <= next_state;
            
            // Update configuration registers
            node_count_reg <= node_count_next;
            edge_count_reg <= edge_count_next;
            
            // Edge write logic
            if (edge_wr_en && edge_idx_i < 5'd32) begin
                edges[edge_idx_i] <= edge_data_i;
            end
            
            // DP computation
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE;
                        node_count_next <= node_count;
                        edge_count_next <= edge_count;
                        k <= 4'd0;
                        
                        // Initialize probabilities
                        for (integer i = 0; i < 16; i = i + 1) begin
                            prob[i] <= 32'd0;
                        end
                        prob[0] <= 32'd32768; // 1.0 in Q16.16
                        
                        max_node <= node_count - 4'd1;
                    end
                end
                
                COMPUTE: begin
                    out_valid <= 1'b0;
                    
                    // Perform one relaxation step
                    for (edge_idx = 0; edge_idx < edge_count_reg; edge_idx = edge_idx + 1) begin
                        src = edges[edge_idx][31:28];
                        dest = edges[edge_idx][27:24];
                        weight = edges[edge_idx][15:0];
                        
                        // Calculate new probability
                        if (prob[src] > 32'd0) begin
                            // new_prob = prob[src] * (1 - weight/65536) = prob[src] * (65536 - weight) >> 16
                            new_prob = (prob[src] * (32'd65536 - weight)) >> 16;
                            
                            // Update if better probability
                            if (new_prob > prob[dest]) begin
                                prob[dest] <= new_prob;
                            end
                        end
                    end
                    
                    // Move to output state after this iteration
                    next_state <= OUTPUT;
                end
                
                OUTPUT: begin
                    out_valid <= 1'b1;
                    prob_k <= prob[max_node];
                    k_idx <= k;
                    
                    // Check if we need more iterations
                    if (k == 4'd15) begin
                        next_state <= IDLE;
                    end else begin
                        k <= k + 4'd1;
                        next_state <= COMPUTE;
                    end
                end
                
                default: begin
                    next_state <= IDLE;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end
    
    // Handle unreachable case (prob = 0)
    always @(*) begin
        if (prob[max_node] == 32'd0) begin
            prob_k = 32'sd-1; // -1 for unreachable
        end
    end

endmodule