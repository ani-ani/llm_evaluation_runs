module optimal_team_selector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_valid,
    input wire [3:0] node_id,
    input wire [3:0] parent_id,
    input wire [11:0] salary,
    input wire [11:0] productivity,
    output reg [31:0] max_ratio_q16_16,
    output reg done
);

// Parameters
parameter N = 12; // Max nodes
parameter K = 6;  // Max team size
parameter M = 4;  // Max children per node
parameter ITERATIONS = 16; // Binary search iterations

// State definitions
typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    BINARY_SEARCH,
    DP_COMPUTE,
    DONE
} state_t;

// Tree node structure
typedef struct {
    logic [3:0] parent_id;
    logic [11:0] salary;
    logic [11:0] productivity;
    logic is_root_child;
} node_t;

// DP table structure (node, count)
typedef logic signed [31:0] dp_table_t [N][K+1];

// Module signals
state_t state, next_state;
logic [3:0] node_count;
node_t tree [N];
logic [31:0] low, high, mid;
logic [4:0] iteration;
logic [3:0] current_node;
logic [2:0] current_count;
dp_table_t dp;
logic [31:0] best_ratio;
logic [3:0] children [N][M];
logic [3:0] child_count [N];

// State machine
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        node_count <= 0;
        iteration <= 0;
        current_node <= 0;
        current_count <= 0;
        low <= 0;
        high <= 4095 << 16;
        best_ratio <= 0;
        done <= 0;
        max_ratio_q16_16 <= 0;
        for (int i = 0; i < N; i++) begin
            tree[i].parent_id <= 0;
            tree[i].salary <= 0;
            tree[i].productivity <= 0;
            tree[i].is_root_child <= 0;
            child_count[i] <= 0;
            for (int j = 0; j < M; j++) begin
                children[i][j] <= 0;
            end
        end
    end else begin
        state <= next_state;
        
        if (state == LOAD_DATA && data_valid) begin
            if (node_id > 0 && node_id <= N) begin
                tree[node_id-1].parent_id = parent_id;
                tree[node_id-1].salary = salary;
                tree[node_id-1].productivity = productivity;
                tree[node_id-1].is_root_child = (parent_id == 0);
                node_count <= node_count + 1;
            end
        end
        
        if (state == BINARY_SEARCH) begin
            if (iteration == 0) begin
                low <= 0;
                high <= 4095 << 16;
            end
            mid <= (low + high) >> 1;
        end
        
        if (state == DP_COMPUTE) begin
            // DP computation will be handled in combinational logic
        end
    end
end

// Next state logic
always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = LOAD_DATA;
        end
        LOAD_DATA: begin
            if (node_count == N) next_state = BINARY_SEARCH;
        end
        BINARY_SEARCH: begin
            if (iteration == ITERATIONS) begin
                next_state = DONE;
                done = 1;
                max_ratio_q16_16 = best_ratio;
            end else begin
                next_state = DP_COMPUTE;
            end
        end
        DP_COMPUTE: begin
            next_state = BINARY_SEARCH;
            iteration = iteration + 1;
        end
        DONE: begin
            if (!start) begin
                next_state = IDLE;
                done = 0;
            end
        end
    endcase
end

// Build tree structure (children lists)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < N; i++) begin
            child_count[i] <= 0;
            for (int j = 0; j < M; j++) begin
                children[i][j] <= 0;
            end
        end
    end else if (state == LOAD_DATA && data_valid && node_id > 0 && node_id <= N) begin
        logic [3:0] pid = parent_id;
        if (pid > 0 && pid <= N) begin
            if (child_count[pid-1] < M) begin
                children[pid-1][child_count[pid-1]] <= node_id - 1;
                child_count[pid-1] <= child_count[pid-1] + 1;
            end
        end
    end
end

// DP computation
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j <= K; j++) begin
                dp[i][j] <= -32'h80000000; // Initialize to negative infinity
            end
        end
    end else if (state == DP_COMPUTE) begin
        // Initialize DP table for leaves
        for (int i = 0; i < N; i++) begin
            if (child_count[i] == 0) begin
                // Leaf node
                dp[i][0] <= 0; // Not selecting the node
                dp[i][1] <= ($signed(productivity) << 16) - ($signed(mid) * $signed(salary)) >> 16;
            end
        end
        
        // Process nodes in reverse order (from leaves to root)
        for (int i = N-1; i >= 0; i--) begin
            if (child_count[i] > 0) begin
                // Initialize DP for current node
                dp[i][0] <= 0;
                dp[i][1] <= ($signed(tree[i].productivity) << 16) - ($signed(mid) * $signed(tree[i].salary)) >> 16;
                
                // Merge with children
                for (int c = 0; c < child_count[i]; c++) begin
                    logic [3:0] child = children[i][c];
                    
                    // Temporary storage for merged DP
                    logic signed [31:0] temp_dp [K+1];
                    for (int j = 0; j <= K; j++) begin
                        temp_dp[j] = -32'h80000000;
                    end
                    
                    // Knapsack merge
                    for (int j = 0; j <= K; j++) begin
                        for (int k = 0; k <= j; k++) begin
                            if (dp[i][j-k] != -32'h80000000 && dp[child][k] != -32'h80000000) begin
                                logic signed [31:0] val = dp[i][j-k] + dp[child][k];
                                if (val > temp_dp[j]) begin
                                    temp_dp[j] = val;
                                end
                            end
                        end
                    end
                    
                    // Copy back to dp[i]
                    for (int j = 0; j <= K; j++) begin
                        dp[i][j] = temp_dp[j];
                    end
                end
            end
        end
        
        // Check if we found a valid solution with root constraint
        logic valid_solution = 0;
        for (int j = 1; j <= K; j++) begin
            if (dp[0][j] > 0) begin
                valid_solution = 1;
                break;
            end
        end
        
        // Update binary search bounds
        if (valid_solution) begin
            low <= mid;
            best_ratio <= mid;
        end else begin
            high <= mid;
        end
    end
end

endmodule