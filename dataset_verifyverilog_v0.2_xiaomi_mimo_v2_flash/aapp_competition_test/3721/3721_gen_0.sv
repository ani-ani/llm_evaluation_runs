module chemical_table(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] q,
    input valid_in,
    input [3:0] r,
    input [3:0] c,
    output reg [7:0] result,
    output reg done,
    output reg rden
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam READ_INPUTS = 3'b001;
    localparam PROCESS_INPUTS = 3'b010;
    localparam COUNT_COMPONENTS = 3'b011;
    localparam FINALIZE = 3'b100;
    localparam DSU_FIND_ROOT = 3'b101;
    localparam DSU_UNION = 3'b110;
    localparam DSU_COMPRESS = 3'b111;

    // DSU Registers
    reg [3:0] parent [15:0];
    reg [3:0] rank   [15:0];
    
    // Temporary registers for DSU operations
    reg [3:0] node_u, node_v;
    reg [3:0] root_u, root_v;
    reg [3:0] current_node;
    reg [3:0] find_stack [4:0]; // Stack for path compression (max depth 4 for 16 nodes)
    reg [2:0] stack_ptr;
    reg [3:0] temp_parent;

    // Control Registers
    reg [2:0] state, next_state;
    reg [3:0] q_cnt;           // Counter for processed inputs
    reg [3:0] node_idx;        // Iterator for counting components
    reg [7:0] comp_count;      // Count of connected components
    reg [7:0] final_result;    // Result storage
    reg       done_flag;
    reg       rden_flag;

    // Integer for reset loop
    integer i;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = READ_INPUTS;
                else next_state = IDLE;
            end
            READ_INPUTS: begin
                if (valid_in && q_cnt < q) next_state = PROCESS_INPUTS;
                else if (q_cnt >= q) next_state = COUNT_COMPONENTS;
                else next_state = READ_INPUTS;
            end
            PROCESS_INPUTS: begin
                // Start Find for node_u
                next_state = DSU_FIND_ROOT;
            end
            DSU_FIND_ROOT: begin
                // Check if we found root (parent is self or stack done logic handled in datapath)
                // We use a specific state for traversal to ensure sequential processing
                if (parent[current_node] == current_node) next_state = DSU_UNION; // Found root
                else next_state = DSU_FIND_ROOT; // Continue traversing
            end
            DSU_UNION: begin
                // After Union, go back to reading inputs
                next_state = READ_INPUTS;
            end
            COUNT_COMPONENTS: begin
                // Iterate through all nodes to count roots
                if (node_idx >= (n + m)) next_state = FINALIZE;
                else next_state = DSU_FIND_ROOT; // Find root to check if it's a component
            end
            FINALIZE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Registers
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
                rank[i] <= 4'd0;
            end
            result <= 8'd0;
            done <= 1'b0;
            rden <= 1'b0;
            q_cnt <= 4'd0;
            node_idx <= 4'd0;
            comp_count <= 8'd0;
            stack_ptr <= 3'd0;
            rden_flag <= 1'b0;
            done_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize DSU: Parent[i] = i for all nodes (0 to n+m-1)
                        // We initialize partially in cycle 0, or use a counter. 
                        // For simplicity in hardware, we initialize on start and assume n, m are stable.
                        // Since max nodes is 16, we can unroll or use a small loop state.
                        // Here we initialize strictly necessary range.
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n + m) begin
                                parent[i] <= i[3:0];
                                rank[i] <= 4'd0;
                            end
                        end
                        q_cnt <= 4'd0;
                        node_idx <= 4'd0;
                        comp_count <= 8'd0;
                        done <= 1'b0;
                        rden <= 1'b1; // Signal ready to receive inputs
                    end
                end

                READ_INPUTS: begin
                    rden <= 1'b1; // Keep high during read phase
                    if (valid_in && q_cnt < q) begin
                        // Capture inputs
                        node_u <= r;
                        node_v <= c + n; // Offset column index
                        q_cnt <= q_cnt + 1'b1;
                        rden <= 1'b0; // Pulse low to acknowledge capture (optional flow control)
                    end
                end

                PROCESS_INPUTS: begin
                    // Prepare for Find on node_u
                    current_node <= node_u;
                    stack_ptr <= 3'd0;
                    // Start traversal immediately
                end

                DSU_FIND_ROOT: begin
                    if (parent[current_node] == current_node) begin
                        // Found root of u
                        if (stack_ptr > 0) begin
                            // Path compression: Point all nodes on stack to this root
                            // We handle one link per cycle (sequential compression)
                            stack_ptr <= stack_ptr - 1'b1;
                            parent[find_stack[stack_ptr - 1'b1]] <= current_node;
                            // Stay in this state to finish compression if needed, or proceed if stack empty
                            // Since we decrement stack_ptr, next cycle check condition again. 
                            // If stack_ptr becomes 0, we fall through or need another state to trigger union.
                        end else begin
                            // Compression done (or no stack). Assign root_u
                            root_u <= current_node;
                            // Now need to find root of v. 
                            // Transition logic is tricky here. We use a specific flag or sub-state.
                            // Let's use a helper state 'CHECK_ROOT_V' effectively handled by jumping logic.
                            // However, Verilog case state is linear. 
                            // We will set current_node to node_v to find root of v next.
                            current_node <= node_v;
                            // We need to distinguish finding root of U vs V.
                            // We can reuse this state: if current_node was u, now check v.
                        end
                    end else begin
                        // Traverse
                        if (stack_ptr < 5) begin
                            find_stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1'b1;
                            current_node <= parent[current_node];
                        end
                    end
                    
                    // Logic to switch between U and V finding:
                    // We need a temp register to know if we are finding root for U or V.
                    // Let's refine the logic in a simpler way:
                    // Use 2 Find cycles: one for U, one for V.
                    // We'll use state DSU_FIND_ROOT only for traversal.
                    // To handle the switch, let's add a specific state trigger.
                end
                
                // Correction: The previous DSU_FIND_ROOT block is too complex for a single state machine.
                // Let's break it down with internal flags.
                // To keep it synthesizable and correct:
                // Use a separate flag 'finding_v' to distinguish which node we are resolving.
                // Since we are strictly writing code, let's rewrite the DSU logic more cleanly within the constraints.
            endcase
        end
    end

    // --- REFINED DATAPATH IMPLEMENTATION ---
    // Due to the complexity of nested loops in FSM, we implement a micro-coded style approach
    // or simply add states to handle Find(u), Find(v), Union.
    // Let's re-evaluate the FSM to strictly support standard DSU operations sequentially.
    
    reg finding_v; // Flag to indicate we are currently finding root for V
    reg [3:0] stack_restore_ptr; // To restore stack state for compression pass
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and state
            done <= 1'b0;
            result <= 8'd0;
            rden <= 1'b0;
            state <= IDLE;
            q_cnt <= 4'd0;
            node_idx <= 4'd0;
            finding_v <= 1'b0;
            stack_ptr <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize DSU arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n + m) parent[i] <= i[3:0];
                            else parent[i] <= 4'd0; // Clean unused
                            rank[i] <= 4'd0;
                        end
                        q_cnt <= 4'd0;
                        node_idx <= 4'd0;
                        comp_count <= 8'd0;
                        finding_v <= 1'b0;
                        rden <= 1'b1; // Ready for input
                        state <= READ_INPUTS;
                    end else begin
                        rden <= 1'b0;
                    end
                end

                READ_INPUTS: begin
                    if (valid_in && q_cnt < q) begin
                        node_u <= r;
                        node_v <= c + n;
                        q_cnt <= q_cnt + 1'b1;
                        rden <= 1'b0; // Handshake
                        // Transition to processing immediately next cycle
                        state <= PROCESS_INPUTS;
                    end else if (q_cnt >= q) begin
                        // Done reading, start counting components
                        state <= COUNT_COMPONENTS;
                        rden <= 1'b0;
                        node_idx <= 4'd0;
                    end else begin
                        rden <= 1'b1; // Keep ready
                    end
                end

                PROCESS_INPUTS: begin
                    // Prepare for Find(node_u)
                    current_node <= node_u;
                    stack_ptr <= 3'd0;
                    finding_v <= 1'b0;
                    state <= DSU_FIND_ROOT;
                end

                DSU_FIND_ROOT: begin
                    if (parent[current_node] == current_node) begin
                        // Found root
                        if (stack_ptr > 0) begin
                            // Path compression: Write back
                            // We pop one from stack per cycle to keep logic shallow
                            parent[find_stack[stack_ptr - 1'b1]] <= current_node;
                            stack_ptr <= stack_ptr - 1'b1;
                            // Stay in this state to continue compressing
                        end else begin
                            // Compression finished for this node
                            if (!finding_v) begin
                                // Found root of u
                                root_u <= current_node;
                                // Switch to finding root of v
                                finding_v <= 1'b1;
                                current_node <= node_v;
                                stack_ptr <= 3'd0;
                                // Stay in DSU_FIND_ROOT state (loop back to start of this block)
                                // Explicitly handled by not changing state, but we need to reset logic for V
                                // Since we are inside the case block, the 'else' branch below for V won't be hit next cycle
                                // We need to ensure logic flow handles the 'finding_v' flag correctly.
                                // We will stay in state DSU_FIND_ROOT, and next cycle it will process node_v.
                            end else begin
                                // Found root of v
                                root_v <= current_node;
                                state <= DSU_UNION;
                            end
                        end
                    end else begin
                        // Traverse up
                        if (stack_ptr < 5) begin
                            find_stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1'b1;
                            current_node <= parent[current_node];
                        end
                    end
                end

                DSU_UNION: begin
                    if (root_u != root_v) begin
                        if (rank[root_u] > rank[root_v]) begin
                            parent[root_v] <= root_u;
                        end else if (rank[root_v] > rank[root_u]) begin
                            parent[root_u] <= root_v;
                        end else begin
                            parent[root_v] <= root_u;
                            rank[root_u] <= rank[root_u] + 1'b1;
                        end
                    end
                    // Loop back to READ_INPUTS
                    state <= READ_INPUTS;
                end

                COUNT_COMPONENTS: begin
                    // Iterate through all nodes 0 to (n+m-1)
                    if (node_idx < n + m) begin
                        // Perform Find on node_idx to get canonical root
                        current_node <= node_idx;
                        stack_ptr <= 3'd0;
                        state <= DSU_FIND_ROOT_COUNT;
                        // We use a temporary flag to indicate we are in counting mode
                        // But simple way: jump to a specific counting find state
                    end else begin
                        // Done counting
                        state <= FINALIZE;
                    end
                end

                // Special Find state for Counting (no union, just count root)
                DSU_FIND_ROOT_COUNT: begin
                    if (parent[current_node] == current_node) begin
                        // Root found
                        if (stack_ptr > 0) begin
                            parent[find_stack[stack_ptr - 1'b1]] <= current_node;
                            stack_ptr <= stack_ptr - 1'b1;
                        end else begin
                            // This node is a root (or compressed to one)
                            // Since we iterate node_idx, we check if this node is its own parent after compression
                            // Actually, we are checking current_node == parent[current_node] which implies root.
                            // If it's a root, increment count.
                            comp_count <= comp_count + 1'b1;
                            node_idx <= node_idx + 1'b1;
                            state <= COUNT_COMPONENTS;
                        end
                    end else begin
                        if (stack_ptr < 5) begin
                            find_stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1'b1;
                            current_node <= parent[current_node];
                        end
                    end
                end

                FINALIZE: begin
                    // Result = Components - 1
                    // Note: If no nodes (q=0 and n+m=0, but constraints say n,m >=1), comp_count >= 1.
                    if (comp_count > 0) begin
                        result <= comp_count - 1'b1;
                    end else begin
                        result <= 8'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule