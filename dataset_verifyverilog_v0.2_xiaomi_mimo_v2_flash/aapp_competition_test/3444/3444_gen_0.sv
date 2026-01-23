module skiing_probability (
    input clk,
    input rst_n,
    input start,
    input [3:0] edge_valid,
    input [3:0][3:0] edge_src,
    input [3:0][3:0] edge_dst,
    input [3:0][15:0] edge_prob,
    input [2:0] max_k,
    output reg [15:0] result_p0,
    output reg [15:0] result_p1,
    output reg [15:0] result_p2,
    output reg [15:0] result_p3,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam PROCESS_EDGES = 4'd2;
    localparam UPDATE_DP = 4'd3;
    localparam CHECK_DONE = 4'd4;
    localparam OUTPUT = 4'd5;
    localparam DONE = 4'd6;

    // Constants
    localparam WALKS_MAX = 3'd3;
    localparam CABINS = 3'd4;
    localparam FIXED_ONE = 16'h10000; // 1.0 in Q16.16
    localparam IMPOSSIBLE_MARKER = 16'hFFFF;

    // Registers for state machine
    reg [3:0] state;
    reg [3:0] next_state;

    // DP array: dp[4][4] -> 16 entries of 16 bits
    // Flattened: index = cabin * 4 + walks
    reg [15:0] dp [0:15];
    reg [15:0] next_dp [0:15];

    // Temporary registers for updates
    reg [15:0] temp_dp [0:15];

    // Iteration counters
    reg [2:0] edge_idx; // 0 to 3
    reg [1:0] cabin_idx; // 0 to 3 for initialization
    reg [2:0] walks_idx; // 0 to 3 for initialization and checks
    
    // Intermediate calculation registers
    reg [31:0] mul_temp; // For 16x16 -> 32 multiplication
    reg [15:0] mul_result; // Result after shift
    
    // Flags
    reg changes_found;
    reg any_possible;
    reg [15:0] dp_src;
    reg [15:0] dp_dst;
    reg [15:0] prob_val;
    reg [15:0] new_val;
    reg [15:0] old_val;
    reg [2:0] walks_next;
    
    // Update indexers
    reg [1:0] u_cabin;
    reg [2:0] u_walks;

    // Control signals for block assignments
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Reset dp array
            for (i = 0; i < 16; i = i + 1) begin
                dp[i] <= 16'h0000;
            end
            done <= 1'b0;
            impossible <= 1'b0;
            result_p0 <= 16'h0000;
            result_p1 <= 16'h0000;
            result_p2 <= 16'h0000;
            result_p3 <= 16'h0000;
        end else begin
            state <= next_state;
            
            // DP array update
            for (i = 0; i < 16; i = i + 1) begin
                dp[i] <= next_dp[i];
            end

            // Output logic
            if (state == OUTPUT) begin
                result_p0 <= dp[0*4 + 0] ? dp[0*4 + 0] : IMPOSSIBLE_MARKER;
                result_p1 <= dp[0*4 + 1] ? dp[0*4 + 1] : IMPOSSIBLE_MARKER;
                result_p2 <= dp[0*4 + 2] ? dp[0*4 + 2] : IMPOSSIBLE_MARKER;
                result_p3 <= dp[0*4 + 3] ? dp[0*4 + 3] : IMPOSSIBLE_MARKER;
                // Check if all are impossible
                impossible <= (dp[0*4 + 0] == 0 && dp[0*4 + 1] == 0 && 
                               dp[0*4 + 2] == 0 && dp[0*4 + 3] == 0);
            end
            
            if (state == DONE) done <= 1'b1;
            else if (state == IDLE) done <= 1'b0;
        end
    end

    // Next State Logic & Output Logic (Combinational)
    always @(*) begin
        // Default next_dp to hold current values
        for (i = 0; i < 16; i = i + 1) begin
            next_dp[i] = dp[i];
        end
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Reset dp array: dp[0][0] = 1.0, others 0
                // Note: We use blocking assignment here inside combinational block to update the temp values
                for (i = 0; i < 16; i = i + 1) begin
                    next_dp[i] = 16'h0000;
                end
                next_dp[0] = FIXED_ONE; // cabin 0, walks 0
                next_state = PROCESS_EDGES;
            end

            PROCESS_EDGES: begin
                // We process one edge per cycle. 
                // We need to calculate updates based on CURRENT dp (held in next_dp effectively as passed from previous cycle or init)
                // However, strictly we should process all edges before updating.
                // The prompt implies PROCESS_EDGES iterates, then UPDATE_DP applies.
                // To fit sequential logic, we will iterate through edges, calculating potential updates.
                // Since we can't write to dp array while reading it for multiple edges in parallel easily without separate temp storage,
                // we will process edges one by one and update a 'buffer' dp.
                // BUT, strict dependency says: Process Edges -> Update DP.
                // To avoid Read-After-Write hazards in one cycle, we will calculate logic here.
                // Let's simplify: In PROCESS_EDGES state, we iterate through edges 0-3.
                
                if (edge_idx < 4) begin
                    if (edge_valid[edge_idx]) begin
                        // Skiing: src < dst
                        if (edge_src[edge_idx] < edge_dst[edge_idx]) begin
                            // For all walks w
                            for (walks_idx = 0; walks_idx <= max_k; walks_idx = walks_idx + 1) begin
                                dp_src = dp[edge_src[edge_idx]*4 + walks_idx];
                                if (dp_src != 0) begin
                                    mul_temp = dp_src * edge_prob[edge_idx];
                                    mul_result = mul_temp[31:16]; // Q16.16 mul
                                    old_val = next_dp[edge_dst[edge_idx]*4 + walks_idx];
                                    if (mul_result > old_val) begin
                                        next_dp[edge_dst[edge_idx]*4 + walks_idx] = mul_result;
                                    end
                                end
                            end
                        end
                        
                        // Walking: bidirectional, cost 1 walk
                        // src -> dst
                        for (walks_idx = 0; walks_idx <= max_k; walks_idx = walks_idx + 1) begin
                            dp_src = dp[edge_src[edge_idx]*4 + walks_idx];
                            if (dp_src != 0 && walks_idx < max_k) begin
                                walks_next = walks_idx + 1;
                                new_val = dp_src; // * 1.0
                                old_val = next_dp[edge_dst[edge_idx]*4 + walks_next];
                                if (new_val > old_val) begin
                                    next_dp[edge_dst[edge_idx]*4 + walks_next] = new_val;
                                end
                            end
                        end
                        
                        // dst -> src (if different)
                        if (edge_src[edge_idx] != edge_dst[edge_idx]) begin
                            for (walks_idx = 0; walks_idx <= max_k; walks_idx = walks_idx + 1) begin
                                dp_dst = dp[edge_dst[edge_idx]*4 + walks_idx];
                                if (dp_dst != 0 && walks_idx < max_k) begin
                                    walks_next = walks_idx + 1;
                                    new_val = dp_dst;
                                    old_val = next_dp[edge_src[edge_idx]*4 + walks_next];
                                    if (new_val > old_val) begin
                                        next_dp[edge_src[edge_idx]*4 + walks_next] = new_val;
                                    end
                                end
                            end
                        end
                    end
                    next_state = PROCESS_EDGES;
                end else begin
                    next_state = CHECK_DONE;
                end
            end

            CHECK_DONE: begin
                // Check if any updates occurred or if we reached max iterations
                // Since we updated in PROCESS_EDGES, we can't easily detect changes in this flow without extra flags.
                // Heuristic: Loop a fixed number of times (e.g., N times) or until no changes.
                // With N=4, 4 iterations max is sufficient for longest path.
                // We use a counter 'walks_idx' (reused) to track iterations.
                // Actually, PROCESS_EDGES iterates edges, so we need another loop counter for full passes.
                // Let's use 'cabin_idx' to track full iterations (0 to 3).
                
                if (cabin_idx < CABINS) begin
                    cabin_idx = cabin_idx + 1;
                    next_state = PROCESS_EDGES;
                    edge_idx = 0; // Reset edge index for next pass
                end else begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                next_state = DONE;
            end

            DONE: begin
                if (!start) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
        
        // Reset counters based on state transitions
        if (state == IDLE && start) begin
            edge_idx = 0;
            cabin_idx = 0;
        end
        if (state == PROCESS_EDGES) begin
             // Increment edge counter for the next cycle if we are staying in process edges
             // But wait, PROCESS_EDGES handles one edge per cycle. 
             // We need to manage edge_idx increment logic carefully.
             // In the case block above, we handled logic. We need to increment edge_idx here.
             if (edge_idx < 4) begin
                 // Logic in case block executes based on current edge_idx. 
                 // We need to increment edge_idx AFTER processing current one.
                 // Since this is combinational, we set next_state. 
                 // The increment must happen for the *next* cycle.
                 // So we update edge_idx at the end of this block.
                 // However, we can't easily use 'if' inside always @(*) to set reg values if we want to keep them.
                 // Let's handle increments explicitly.
             end
        end
    end
    
    // Separate logic for counter increments to ensure correct sequential behavior
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_idx <= 0;
        end else begin
            if (state == IDLE && start) begin
                edge_idx <= 0;
                cabin_idx <= 0;
            end else if (state == PROCESS_EDGES) begin
                if (edge_idx < 4) begin
                    edge_idx <= edge_idx + 1;
                end else begin
                    edge_idx <= 0;
                end
            end else if (state == CHECK_DONE) begin
                 // If going back to PROCESS_EDGES, reset edge_idx
                 if (cabin_idx < CABINS) begin
                     edge_idx <= 0;
                 end
            end
        end
    end

endmodule
