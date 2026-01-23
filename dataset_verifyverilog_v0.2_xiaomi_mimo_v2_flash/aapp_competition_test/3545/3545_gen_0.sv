module anatoly_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pre_obs [7:0],
    input wire [7:0] in_obs [7:0],
    input wire [7:0] post_obs [7:0],
    input wire [3:0] n,
    output reg valid,
    output reg [1:0] call_config [5:0],
    output reg [7:0] tree_pre [7:0],
    output reg [7:0] tree_in [7:0],
    output reg [7:0] tree_post [7:0],
    output reg done
);
    parameter MAX_N = 8;
    parameter MAX_SLOTS = 6;

    // State definition
    reg [3:0] state;
    localparam IDLE = 0;
    localparam PREPARE_CONFIG = 1;
    localparam CHECK_TREES = 2;
    localparam FOUND_SOLUTION = 3;
    localparam FINISHED = 4;

    // Internal registers
    reg [9:0] perm_idx;
    reg [3:0] root_idx;
    reg [3:0] left_size;
    reg [3:0] current_n;
    
    // Current configuration
    reg [1:0] current_calls [MAX_SLOTS-1:0];
    reg [1:0] next_calls [MAX_SLOTS-1:0];

    // Combinational logic signals
    wire check_match;
    wire [7:0] gen_pre_wire [MAX_N-1:0];
    wire [7:0] gen_in_wire [MAX_N-1:0];
    wire [7:0] gen_post_wire [MAX_N-1:0];

    integer i, j;

    // --- Permutation Generation (Base 3 Decoder) ---
    generate
        for (genvar s = 0; s < 6; s = s + 1) begin : gen_perm
            assign next_calls[s] = (perm_idx / (3 ** s)) % 3;
        end
    endgenerate

    // --- Consistency Check Logic ---
    // Combinational block to verify current configuration
    reg check_match_reg;
    reg [7:0] gen_pre_reg [MAX_N-1:0];
    reg [7:0] gen_in_reg [MAX_N-1:0];
    reg [7:0] gen_post_reg [MAX_N-1:0];

    always @(*) begin
        // Initialize
        check_match_reg = 0;
        for (i = 0; i < MAX_N; i = i + 1) begin
            gen_pre_reg[i] = 0;
            gen_in_reg[i] = 0;
            gen_post_reg[i] = 0;
        end

        // 1. Check basic validity
        if (root_idx >= current_n || left_size != root_idx) begin
            // In this problem, left_size must equal root_idx for valid split in 0..N-1 space
            // and we assume the tree is fully defined by the root split (Right Skewed)
            // If n > 6, we cannot represent it with 6 slots.
            check_match_reg = 0;
        end else if (current_n > MAX_SLOTS) begin
            check_match_reg = 0;
        end else begin
            // 2. Generate True Tree Structure (Right Skewed)
            // We assume the tree is built recursively on the set {0..n-1}
            // Root is at index 'root_idx'.
            // Left subtree contains 0..root_idx-1.
            // Right subtree contains root_idx+1..n-1.
            // We assume Right Skewed structure for subtrees.
            
            // Generate Preorder (True)
            // Root, Left (recursive), Right (recursive)
            // Since we assume Right Skewed: Root, then next largest in range, etc.
            // Wait, for Right Skewed (Root is max of range):
            // Preorder: Root, then (Root-1), ...
            // Inorder: ..., 0, Root.
            // Postorder: ..., 0, Root.
            
            // However, the loop iterates 'left_size'.
            // If 'left_size' is the size, then 'root_idx' is the index.
            // We need to fill gen_pre_reg, gen_in_reg, gen_post_reg.
            
            // Let's generate the values for the tree.
            // We will use a stack to generate the traversals for the specific tree shape.
            // Tree shape: Root 'root_idx'. Left '0..root_idx-1'. Right 'root_idx+1..n-1'.
            // Structure: Right Skewed on left, Right Skewed on right.
            // (i.e., Last element of range is root of that range).
            
            // We need to generate the 3 traversals.
            // We use a stack: (start_val, end_val, state)
            // state 0 = Pre, 1 = In, 2 = Post (for generation)
            // Actually, we need to fill the arrays.
            // 
            // Let's just simulate the traversal to fill gen_*_reg.
            // Stack for generation: (val, type) where type 0=Pre, 1=In, 2=Post.
            // Wait, we need to generate the arrays.
            
            // Since n is small, we can unroll or use a fixed loop.
            // Let's use a stack for True Tree Generation.
            // 
            // We need to simulate: Traverse(0, n-1).
            // Root = root_idx.
            // Traverse(0, root_idx-1).
            // Traverse(root_idx+1, n-1).
            
            // Stack entry: (low, high).
            // We process (low, high) -> Root = high. Left = (low, high-1). Right = empty (for right skewed).
            // Wait, right skewed means Root is High.
            // If we have range [0, root_idx], Root is root_idx. Left is [0, root_idx-1].
            // If we have range [root_idx+1, n-1], Root is n-1. Left is [root_idx+1, n-2].
            // This is not right skewed if we pick Root as high.
            
            // Let's assume the tree structure is fixed as: 
            // Slot 0: Root
            // Slot 1: Left Child
            // Slot 3: LL
            // Slot 4: LR
            // Slot 2: Right Child
            // Slot 5: RL
            // And we assign values from the set {0..n-1} to these slots.
            
            // Generate Preorder (True)
            gen_pre_reg[0] = root_idx;
            for (i = 1; i < current_n; i = i + 1) begin
                if (i <= root_idx) begin
                    gen_pre_reg[i] = root_idx - i + 1;
                end else begin
                    gen_pre_reg[i] = root_idx + i - root_idx;
                end
            end
            
            // Generate Inorder (True)
            // Inorder: Left, Root, Right
            // For Right Skewed: Left, Root, Right
            // Left: 0..root_idx-1 (Right Skewed)
            // Right: root_idx+1..n-1 (Right Skewed)
            // We need to generate the Inorder for the whole tree.
            // Inorder: Left (0..root_idx-1), Root, Right (root_idx+1..n-1)
            // Left: 0, 1, ..., root_idx-1
            // Root: root_idx
            // Right: root_idx+1, root_idx+2, ..., n-1
            // So Inorder: 0, 1, ..., root_idx-1, root_idx, root_idx+1, ..., n-1
            integer in_idx = 0;
            for (i = 0; i < root_idx; i = i + 1) begin
                gen_in_reg[in_idx] = i;
                in_idx = in_idx + 1;
            end
            gen_in_reg[in_idx] = root_idx;
            in_idx = in_idx + 1;
            for (i = root_idx + 1; i < current_n; i = i + 1) begin
                gen_in_reg[in_idx] = i;
                in_idx = in_idx + 1;
            end
            
            // Generate Postorder (True)
            // Postorder: Left, Right, Root
            // For Right Skewed: Left, Right, Root
            // Left: 0..root_idx-1 (Right Skewed)
            // Right: root_idx+1..n-1 (Right Skewed)
            // We need to generate the Postorder for the whole tree.
            // Postorder: Left (0..root_idx-1), Right (root_idx+1..n-1), Root
            // Left: 0, 1, ..., root_idx-1
            // Right: root_idx+1, root_idx+2, ..., n-1
            // Root: root_idx
            // So Postorder: 0, 1, ..., root_idx-1, root_idx+1, ..., n-1, root_idx
            integer post_idx = 0;
            for (i = 0; i < root_idx; i = i + 1) begin
                gen_post_reg[post_idx] = i;
                post_idx = post_idx + 1;
            end
            for (i = root_idx + 1; i < current_n; i = i + 1) begin
                gen_post_reg[post_idx] = i;
                post_idx = post_idx + 1;
            end
            gen_post_reg[post_idx] = root_idx;
            
            // 3. Simulate the execution of the code
            // We need to generate calc_pre, calc_in, calc_post
            // We traverse the slots (0, 1, 2, 3, 4, 5)
            // We check if the output matches obs
            
            // Initialize calc streams
            reg [7:0] calc_pre [MAX_N-1:0];
            reg [7:0] calc_in [MAX_N-1:0];
            reg [7:0] calc_post [MAX_N-1:0];
            for (i = 0; i < MAX_N; i = i + 1) begin
                calc_pre[i] = 0;
                calc_in[i] = 0;
                calc_post[i] = 0;
            end
            
            // Stack for simulation
            reg [2:0] stack_slot [3:0];
            reg [1:0] stack_state [3:0];
            reg [2:0] sp;
            
            // Push initial slot (0, Pre)
            sp = 0;
            stack_slot[sp] = 0;
            stack_state[sp] = 0;
            sp = sp + 1;
            
            // Simulate the traversal
            while (sp > 0) begin
                sp = sp - 1;
                reg [2:0] s = stack_slot[sp];
                reg [1:0] st = stack_state[sp];
                
                if (s >= current_n) continue;
                
                reg [1:0] T = current_calls[s];
                reg [7:0] V;
                
                // Map slot to tree_pre index
                case (s)
                    0: V = gen_pre_reg[0];
                    1: V = gen_pre_reg[1];
                    3: V = gen_pre_reg[2];
                    4: V = gen_pre_reg[3];
                    2: V = gen_pre_reg[4];
                    5: V = gen_pre_reg[5];
                    default: V = 0;
                endcase
                
                // Process based on state
                if (st == 0) begin // Pre-Process
                    if (T == 0) begin
                        calc_pre[i] = V;
                        i = i + 1;
                    end
                    if (s == 0) begin
                        if (1 < current_n) begin
                            stack_slot[sp] = 1;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                        if (2 < current_n) begin
                            stack_slot[sp] = 2;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                    end else if (s == 1) begin
                        if (3 < current_n) begin
                            stack_slot[sp] = 3;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                        if (4 < current_n) begin
                            stack_slot[sp] = 4;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                    end else if (s == 2) begin
                        if (5 < current_n) begin
                            stack_slot[sp] = 5;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                    end
                end else if (st == 1) begin // Mid-Process
                    if (T == 1) begin
                        calc_in[i] = V;
                        i = i + 1;
                    end
                    if (s == 0) begin
                        if (2 < current_n) begin
                            stack_slot[sp] = 2;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                    end else if (s == 1) begin
                        if (4 < current_n) begin
                            stack_slot[sp] = 4;
                            stack_state[sp] = 0;
                            sp = sp + 1;
                        end
                    end
                end else if (st == 2) begin // Post-Process
                    if (T == 2) begin
                        calc_post[i] = V;
                        i = i + 1;
                    end
                end
            end
            
            // 4. Compare calc streams with obs
            reg match = 1;
            for (i = 0; i < current_n; i = i + 1) begin
                if (calc_pre[i] != pre_obs[i] || calc_in[i] != in_obs[i] || calc_post[i] != post_obs[i]) begin
                    match = 0;
                    break;
                end
            end
            
            // Set check_match_reg if match
            check_match_reg = match;
        end
    end
    
    // Assign combinational signals
    assign check_match = check_match_reg;
    assign gen_pre_wire = gen_pre_reg;
    assign gen_in_wire = gen_in_reg;
    assign gen_post_wire = gen_post_reg;

    // --- Finite State Machine ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            perm_idx <= 0;
            root_idx <= 0;
            left_size <= 0;
            current_n <= 0;
            for (i = 0; i < MAX_SLOTS; i = i + 1) begin
                current_calls[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREPARE_CONFIG;
                        current_n <= n;
                    end
                end
                PREPARE_CONFIG: begin
                    current_calls <= next_calls;
                    perm_idx <= perm_idx + 1;
                    if (perm_idx >= 729) begin
                        state <= CHECK_TREES;
                        root_idx <= 0;
                        left_size <= 0;
                    end
                end
                CHECK_TREES: begin
                    if (check_match) begin
                        state <= FOUND_SOLUTION;
                        valid <= 1;
                    end else begin
                        if (left_size < root_idx) begin
                            left_size <= left_size + 1;
                        end else begin
                            left_size <= 0;
                            if (root_idx < current_n - 1) begin
                                root_idx <= root_idx + 1;
                            end else begin
                                state <= PREPARE_CONFIG;
                            end
                        end
                    end
                end
                FOUND_SOLUTION: begin
                    call_config <= current_calls;
                    tree_pre <= gen_pre_reg;
                    tree_in <= gen_in_reg;
                    tree_post <= gen_post_reg;
                    state <= FINISHED;
                    done <= 1;
                end
                FINISHED: begin
                    // Stay in FINISHED state
                end
            endcase
        end
    end
endmodule
