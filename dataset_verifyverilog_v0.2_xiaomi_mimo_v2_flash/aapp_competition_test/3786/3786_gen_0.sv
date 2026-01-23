module apple_collector(
    input clk,
    input rst_n,
    input start,
    input [3:0] p_addr,
    input [3:0] p_data,
    input p_write,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam WR_PARAM = 4'd1;
    localparam CALC_DEPTH_START = 4'd2;
    localparam CALC_DEPTH_WAIT = 4'd3;
    localparam CALC_DEPTH_STORE = 4'd4;
    localparam CALC_DEPTH_NEXT = 4'd5;
    localparam COUNT_LAYER_START = 4'd6;
    localparam COUNT_LAYER_WAIT = 4'd7;
    localparam COUNT_LAYER_UPDATE = 4'd8;
    localparam COUNT_LAYER_NEXT = 4'd9;
    localparam SUM_PARITY = 4'd10;
    localparam DONE_STATE = 4'd11;
    
    reg [3:0] state;
    
    // Memory for parent relationships (nodes 2..16)
    // Address 0 corresponds to node 2, address 14 to node 16
    reg [3:0] parent_mem [14:0];
    
    // Memory for depths of nodes 1..16
    // We will map node index i (1-16) to depth_mem[i-1]
    reg [3:0] depth_mem [15:0];
    
    // Memory for node counts per depth (levels 0..7)
    reg [3:0] count_mem [7:0];
    
    // Temporary variables for traversal
    reg [3:0] current_node;      // Node currently being processed (1..16)
    reg [3:0] walk_node;         // Node for walking up the tree
    reg [3:0] current_depth;     // Accumulated depth during traversal
    reg [3:0] current_layer;     // Current depth level for counting
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            // Initialize memories (optional but good practice)
            for (i = 0; i < 15; i = i + 1) parent_mem[i] <= 4'd0;
            for (i = 0; i < 16; i = i + 1) depth_mem[i] <= 4'd0;
            for (i = 0; i < 8; i = i + 1) count_mem[i] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= WR_PARAM;
                        current_node <= 4'd2; // Start writing parents for node 2
                    end
                end
                
                // Write pre-configured parents (Simulation/Initialization helper)
                // This state handles writing the parent array if needed by the testbench.
                // Since inputs are external, we rely on the external drive.
                // However, to strictly follow the instructions of 'performing calculations',
                // we assume the parent_mem is valid (either externally driven or previously written).
                // If p_write is an input, we should ideally process it continuously or latch it.
                // Here we handle the start-up sequence.
                WR_PARAM: begin
                    // We proceed to calculation immediately as p_write is handled continuously or assumed valid.
                    // If strictly sequential: 
                    // if (current_node <= 16) ...
                    // Let's just jump to calculation to keep it standard.
                    state <= CALC_DEPTH_START;
                    current_node <= 4'd2; // Node 2 is the first with a parent
                end
                
                // --- Depth Calculation ---
                CALC_DEPTH_START: begin
                    // Node 1 (index 0) has depth 0
                    depth_mem[0] <= 4'd0;
                    
                    if (current_node > 4'd16) begin
                        state <= COUNT_LAYER_START;
                    end else begin
                        // Start walking up for current_node
                        walk_node <= current_node;
                        current_depth <= 4'd0;
                        state <= CALC_DEPTH_WAIT;
                    end
                end
                
                CALC_DEPTH_WAIT: begin
                    // We are at walk_node. Is it the root (1)?
                    if (walk_node == 4'd1) begin
                        // Finished walking. Store depth.
                        // current_node is the node we started with.
                        // depth_mem index is current_node - 1
                        depth_mem[current_node - 1] <= current_depth;
                        state <= CALC_DEPTH_STORE;
                    end else begin
                        // It's not root. Go to parent.
                        // walk_node is 2..16, parent_mem index is walk_node - 2
                        walk_node <= parent_mem[walk_node - 2];
                        current_depth <= current_depth + 1;
                        state <= CALC_DEPTH_WAIT;
                    end
                end
                
                CALC_DEPTH_STORE: begin
                    // Move to next node
                    current_node <= current_node + 1;
                    state <= CALC_DEPTH_START;
                end
                
                // --- Layer Counting ---
                COUNT_LAYER_START: begin
                    // Reset count memory
                    for (i = 0; i < 8; i = i + 1) count_mem[i] <= 4'd0;
                    current_node <= 4'd1; // Start from node 1
                    state <= COUNT_LAYER_NEXT;
                end
                
                COUNT_LAYER_NEXT: begin
                    if (current_node > 4'd16) begin
                        state <= SUM_PARITY;
                    end else begin
                        // Get depth of current_node
                        // Index: current_node - 1
                        // Check if depth < 8 (constraint)
                        if (depth_mem[current_node - 1] < 8) begin
                            current_layer <= depth_mem[current_node - 1];
                            state <= COUNT_LAYER_UPDATE;
                        end else begin
                            // Should not happen based on constraints
                            current_node <= current_node + 1;
                            state <= COUNT_LAYER_NEXT;
                        end
                    end
                end
                
                COUNT_LAYER_UPDATE: begin
                    // Increment count for this depth
                    count_mem[current_layer] <= count_mem[current_layer] + 1;
                    current_node <= current_node + 1;
                    state <= COUNT_LAYER_NEXT;
                end
                
                // --- Sum Parity ---
                SUM_PARITY: begin
                    // Sum odd counts
                    result <= 4'd0;
                    current_layer <= 4'd0; // Use as index 0..7
                    state <= DONE_STATE; // We will sum in next cycle or combinational
                    // Let's do sequential summation for clarity and correctness
                    // (Actually, combinational is faster, but sequential fits the SM better)
                    // Let's iterate through layers 0 to 7 in a loop-like state or unroll.
                    // Unrolling is hard in state machine without many states.
                    // Let's use a helper state if needed, or just do it in one go if resources allow.
                    // Since we are in a state, we can calculate result immediately.
                    result <= count_mem[0][0] + count_mem[1][0] + count_mem[2][0] + count_mem[3][0] + 
                              count_mem[4][0] + count_mem[5][0] + count_mem[6][0] + count_mem[7][0];
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Continuous logic for parent memory write
    // This allows the parent memory to be written anytime, not just during state machine execution
    always @(posedge clk) begin
        if (p_write) begin
            // p_addr 0..14 maps to nodes 2..16
            if (p_addr < 15) begin
                parent_mem[p_addr] <= p_data;
            end
        end
    end

endmodule
