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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] INIT_DP = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers for edges storage (32 edges max, 32 bits each)
    reg [31:0] edges [0:31];
    reg [4:0] stored_edge_count;
    
    // DP arrays (16 nodes)
    reg signed [31:0] prob [0:15];
    reg signed [31:0] next_prob [0:15];
    
    // Control registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] k; // Iteration counter 0-15
    reg [4:0] edge_iter; // Edge iterator 0-31
    reg [3:0] node_iter; // Node iterator for copy
    reg [4:0] cycle_count; // Safety counter
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // Edge parsing
    wire [7:0] src = edge_data_i[31:24];
    wire [7:0] dest = edge_data_i[23:16];
    wire [15:0] weight = edge_data_i[15:0]; // Q16.16
    wire signed [31:0] fall_prob = {16'h0000, weight}; // Extend to 32 bits
    wire signed [31:0] survive_prob = 32'h00010000 - fall_prob; // 1.0 - weight
    
    // Computation signals
    reg signed [63:0] mult_temp;
    reg signed [31:0] new_prob_val;
    reg signed [31:0] current_src_prob;
    reg [3:0] current_src;
    reg [3:0] current_dest;
    
    // Integer for loops
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            out_valid <= 1'b0;
            prob_k <= 32'd0;
            k_idx <= 4'd0;
            stored_edge_count <= 5'd0;
            cycle_count <= 5'd0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                prob[i] <= 32'd0;
                next_prob[i] <= 32'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                edges[i] <= 32'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= LOAD_EDGES;
                    end
                end
                
                LOAD_EDGES: begin
                    // Store edges as they come in
                    if (edge_wr_en) begin
                        edges[edge_idx_i] <= edge_data_i;
                        // Track max edges stored (ensure we don't exceed)
                        if (edge_idx_i < 5'd32) begin
                            stored_edge_count <= edge_idx_i + 5'd1;
                        end
                    end
                    // Move to init when edge_count matches or start is done
                    // For this module, we wait for edge_wr_en to go low and trigger
                    // For simplicity, assume loading happens before compute starts
                    // We'll transition manually by checking if we have enough edges
                    // Since we don't have a "loading done" signal, we rely on the
                    // testbench to set start only after loading.
                    // We'll add a small delay or check edge_wr_en.
                    if (!edge_wr_en && edge_count > 0) begin
                        // Wait one cycle to ensure load is complete
                        cycle_count <= cycle_count + 5'd1;
                        if (cycle_count > 5'd2) begin
                            state <= INIT_DP;
                        end
                    end
                end
                
                INIT_DP: begin
                    // Initialize DP for k=0
                    for (i = 0; i < 16; i = i + 1) begin
                        prob[i] <= 32'd0;
                    end
                    // Node 0 (start) has probability 1.0
                    if (node_count > 0) begin
                        prob[0] <= 32'h00010000; // 1.0 in Q16.16
                    end
                    k <= 4'd0;
                    state <= OUTPUT_RESULT;
                    cycle_count <= 5'd0;
                end
                
                COMPUTE: begin
                    // Bellman-Ford style relaxation
                    // For each edge (src->dest), if src is reachable, update dest
                    
                    // Load current edge data
                    if (edge_iter < 5'd32 && edge_iter < edge_count) begin
                        current_src <= edges[edge_iter][31:24];
                        current_dest <= edges[edge_iter][23:16];
                        current_src_prob <= prob[edges[edge_iter][31:24]];
                        
                        // Check if src is valid and reachable
                        if (edges[edge_iter][31:24] < node_count && 
                            edges[edge_iter][23:16] < node_count &&
                            prob[edges[edge_iter][31:24]] > 32'sd0) begin
                            
                            // Calculate new_prob = prob[src] * (1.0 - weight)
                            // Q16.16 multiply: (32b * 32b) -> 64b, take middle 32 bits
                            mult_temp = $signed(prob[edges[edge_iter][31:24]]) * 
                                       $signed(32'h00010000 - {16'h0000, edges[edge_iter][15:0]});
                            new_prob_val = mult_temp[47:16]; // Q32.32 -> Q16.16
                            
                            // Update next_prob if new value is greater
                            if (new_prob_val > next_prob[edges[edge_iter][23:16]]) begin
                                next_prob[edges[edge_iter][23:16]] <= new_prob_val;
                            end
                        end
                        
                        edge_iter <= edge_iter + 5'd1;
                    end else begin
                        // Finished edges for this k
                        // Copy next_prob back to prob for next iteration
                        if (node_iter < node_count) begin
                            prob[node_iter] <= next_prob[node_iter];
                            // Reset next_prob for next iteration
                            next_prob[node_iter] <= 32'sd0;
                            node_iter <= node_iter + 4'd1;
                        end else begin
                            // Done with this iteration
                            k <= k + 4'd1;
                            edge_iter <= 5'd0;
                            node_iter <= 4'd0;
                            
                            if (k >= 4'd15 || k >= node_count - 1) begin
                                state <= OUTPUT_RESULT;
                            end else begin
                                state <= OUTPUT_RESULT;
                            end
                        end
                    end
                    
                    // Safety timeout
                    cycle_count <= cycle_count + 5'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end
                
                OUTPUT_RESULT: begin
                    // Output probability of reaching node_count-1
                    out_valid <= 1'b1;
                    k_idx <= k;
                    
                    if (node_count > 0 && (node_count - 1) < 16) begin
                        prob_k <= prob[node_count - 1];
                    end else begin
                        prob_k <= 32'sd0;
                    end
                    
                    // If unreachable (0), output -1
                    if (prob_k == 32'sd0 && node_count > 0) begin
                        prob_k <= 32'hFFFFFFFF;
                    end
                    
                    // Prepare for next iteration or finish
                    if (k >= 4'd15 || k >= node_count - 1) begin
                        state <= DONE;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                DONE: begin
                    out_valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule