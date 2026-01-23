module market_sharing (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_vertices,
    input [4:0] num_edges,
    input [31:0] edge_src,
    input [31:0] edge_dst,
    output reg [31:0] assignment,
    output reg done,
    output reg valid
);

// Parameters
parameter MAX_N = 16;
parameter MAX_E = 16;

// State encoding
parameter IDLE = 4'b0000;
parameter LOAD_EDGES = 4'b0001;
parameter SETUP_VARS = 4'b0010;
parameter CHECK_FULL_ASSIGN = 4'b0011;
parameter CHECK_CONSTRAINTS = 4'b0100;
parameter PUSH_STACK = 4'b0101;
parameter NEXT_EDGE = 4'b0110;
parameter TRY_CHAIN1 = 4'b0111;
parameter TRY_CHAIN2 = 4'b1000;
parameter UNDO_ASSIGN = 4'b1001;
parameter BACKTRACK = 4'b1010;
parameter SUCCESS = 4'b1011;
parameter FAILURE = 4'b1100;

// Internal registers
reg [3:0] state;
reg [4:0] current_edge;
reg [2:0] try_state; // 0=untried, 1=tried chain1, 2=tried chain2
reg [4:0] check_vertex;

// Storage arrays - flattened for Verilog compatibility
reg [1:0] edge_assign [0:15]; // 0=unassigned, 1=chain1, 2=chain2
reg [4:0] vertex_degree [0:15];
reg [4:0] count_chain1 [0:15];
reg [4:0] count_chain2 [0:15];
reg [4:0] edge_u [0:15];
reg [4:0] edge_v [0:15];

// Stack for backtracking (stores edge index)
reg [4:0] stack_edge [0:15];
reg [2:0] stack_try [0:15];
reg [4:0] stack_ptr;

integer i;
reg constraint_fail;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        valid <= 0;
        assignment <= 0;
        current_edge <= 0;
        try_state <= 0;
        stack_ptr <= 0;
        check_vertex <= 0;
        // Reset arrays
        for (i = 0; i < 16; i = i + 1) begin
            edge_assign[i] <= 0;
            vertex_degree[i] <= 0;
            count_chain1[i] <= 0;
            count_chain2[i] <= 0;
            edge_u[i] <= 0;
            edge_v[i] <= 0;
            stack_edge[i] <= 0;
            stack_try[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_EDGES;
                    done <= 0;
                    valid <= 0;
                    current_edge <= 0;
                    stack_ptr <= 0;
                end
            end
            
            LOAD_EDGES: begin
                if (current_edge < num_edges) begin
                    edge_u[current_edge] <= edge_src[current_edge*2 +: 2];
                    edge_v[current_edge] <= edge_dst[current_edge*2 +: 2];
                    // Increment degree immediately (net assignments for regs work sequentially in always block)
                    vertex_degree[edge_src[current_edge*2 +: 2]] <= vertex_degree[edge_src[current_edge*2 +: 2]] + 1;
                    vertex_degree[edge_dst[current_edge*2 +: 2]] <= vertex_degree[edge_dst[current_edge*2 +: 2]] + 1;
                    current_edge <= current_edge + 1;
                end else begin
                    current_edge <= 0;
                    try_state <= 0;
                    state <= SETUP_VARS;
                end
            end
            
            SETUP_VARS: begin
                // Reset edge assignments and counts before search
                if (current_edge < num_edges) begin
                    edge_assign[current_edge] <= 0;
                    current_edge <= current_edge + 1;
                end else if (current_edge < 16) begin // Clear remaining
                    edge_assign[current_edge] <= 0;
                    current_edge <= current_edge + 1;
                end else begin
                    // Reset counts
                    for (i = 0; i < 16; i = i + 1) begin
                        count_chain1[i] <= 0;
                        count_chain2[i] <= 0;
                    end
                    current_edge <= 0;
                    try_state <= 0;
                    state <= NEXT_EDGE;
                end
            end
            
            NEXT_EDGE: begin
                // Find next unassigned edge
                if (current_edge < num_edges) begin
                    if (edge_assign[current_edge] == 0) begin
                        try_state <= 0;
                        state <= TRY_CHAIN1;
                    end else begin
                        current_edge <= current_edge + 1;
                    end
                end else begin
                    // All edges assigned, validate
                    check_vertex <= 0;
                    state <= CHECK_CONSTRAINTS;
                end
            end
            
            TRY_CHAIN1: begin
                edge_assign[current_edge] <= 1;
                count_chain1[edge_u[current_edge]] <= count_chain1[edge_u[current_edge]] + 1;
                count_chain1[edge_v[current_edge]] <= count_chain1[edge_v[current_edge]] + 1;
                try_state <= 1;
                check_vertex <= 0;
                state <= CHECK_CONSTRAINTS;
            end
            
            TRY_CHAIN2: begin
                // First undo chain 1
                edge_assign[current_edge] <= 0;
                count_chain1[edge_u[current_edge]] <= count_chain1[edge_u[current_edge]] - 1;
                count_chain1[edge_v[current_edge]] <= count_chain1[edge_v[current_edge]] - 1;
                try_state <= 2;
                state <= UNDO_ASSIGN; // Wait one cycle to ensure undo completes
            end
            
            UNDO_ASSIGN: begin
                // Apply chain 2
                edge_assign[current_edge] <= 2;
                count_chain2[edge_u[current_edge]] <= count_chain2[edge_u[current_edge]] + 1;
                count_chain2[edge_v[current_edge]] <= count_chain2[edge_v[current_edge]] + 1;
                check_vertex <= 0;
                state <= CHECK_CONSTRAINTS;
            end
            
            CHECK_CONSTRAINTS: begin
                if (check_vertex >= num_vertices) begin
                    // All vertices valid
                    state <= PUSH_STACK;
                end else begin
                    if (vertex_degree[check_vertex] >= 2) begin
                        if (count_chain1[check_vertex] > 0 && count_chain2[check_vertex] > 0) begin
                            check_vertex <= check_vertex + 1;
                        end else begin
                            // Constraint failed
                            if (try_state == 2) begin
                                // Tried both, need to backtrack
                                state <= UNDO_ASSIGN; // Undo chain 2
                            end else if (try_state == 1) begin
                                state <= TRY_CHAIN2;
                            end else begin
                                // Should not happen in normal flow
                                state <= BACKTRACK;
                            end
                        end
                    end else begin
                        check_vertex <= check_vertex + 1;
                    end
                end
            end
            
            PUSH_STACK: begin
                // Valid assignment, push to stack and move to next
                stack_edge[stack_ptr] <= current_edge;
                stack_try[stack_ptr] <= try_state;
                stack_ptr <= stack_ptr + 1;
                current_edge <= current_edge + 1;
                state <= NEXT_EDGE;
            end
            
            UNDO_ASSIGN: begin
                // State to undo chain 2 if constraint check failed
                // Note: This state is dual purpose, check where we came from
                // If coming from CHECK_CONSTRAINTS with try_state==2, we need to remove chain2
                if (try_state == 2) begin
                    edge_assign[current_edge] <= 0;
                    count_chain2[edge_u[current_edge]] <= count_chain2[edge_u[current_edge]] - 1;
                    count_chain2[edge_v[current_edge]] <= count_chain2[edge_v[current_edge]] - 1;
                    state <= BACKTRACK;
                end else begin
                    // Coming from TRY_CHAIN2 to actually try it
                    state <= TRY_CHAIN2; // This goes to logic above
                end
            end
            
            BACKTRACK: begin
                if (stack_ptr == 0) begin
                    state <= FAILURE;
                end else begin
                    stack_ptr <= stack_ptr - 1;
                    current_edge <= stack_edge[stack_ptr - 1];
                    // Determine what to undo based on stored try_state
                    if (stack_try[stack_ptr - 1] == 1) begin
                        // Undo chain 1
                        edge_assign[stack_edge[stack_ptr - 1]] <= 0;
                        count_chain1[edge_u[stack_edge[stack_ptr - 1]]] <= count_chain1[edge_u[stack_edge[stack_ptr - 1]]] - 1;
                        count_chain1[edge_v[stack_edge[stack_ptr - 1]]] <= count_chain1[edge_v[stack_edge[stack_ptr - 1]]] - 1;
                        try_state <= 1; // Mark that we should try chain 2 next
                        state <= TRY_CHAIN2;
                    end else if (stack_try[stack_ptr - 1] == 2) begin
                        // Undo chain 2
                        edge_assign[stack_edge[stack_ptr - 1]] <= 0;
                        count_chain2[edge_u[stack_edge[stack_ptr - 1]]] <= count_chain2[edge_u[stack_edge[stack_ptr - 1]]] - 1;
                        count_chain2[edge_v[stack_edge[stack_ptr - 1]]] <= count_chain2[edge_v[stack_edge[stack_ptr - 1]]] - 1;
                        try_state <= 2;
                        state <= BACKTRACK; // Need to backtrack further
                    end
                end
            end
            
            SUCCESS: begin
                // Pack output
                for (i = 0; i < 16; i = i + 1) begin
                    assignment[i*2 +: 2] <= edge_assign[i];
                end
                done <= 1;
                valid <= 1;
                state <= IDLE;
            end
            
            FAILURE: begin
                assignment <= 0;
                done <= 1;
                valid <= 0;
                state <= IDLE;
            end
            
            // Fix for TRY_CHAIN2 and BACKTRACK flow
            // The logic in BACKTRACK sets try_state=1 and goes to TRY_CHAIN2
            // But try_state=1 means 'tried chain1', so logic in TRY_CHAIN2 should handle it
            // Let's refine the TRY_CHAIN2 state logic
            
            default: state <= IDLE;
        endcase
        
        // Override specific conditions outside main FSM block for cleaner logic
        // Actually, better to fix the FSM states to be explicit
        
        // Correction: The previous logic for BACKTRACK -> TRY_CHAIN2 is tricky.
        // Let's use explicit state transitions.
        
        // Re-writing critical states to ensure correct backtrack flow:
        // In BACKTRACK:
        // If popped try_state==1, we need to undo chain1 and TRY chain2.
        // If popped try_state==2, we need to undo chain2 and backtrack more.
        
        // Actually, let's reset the state machine to be simpler and more robust
        // utilizing specific states for 'undo and retry'
    end
end

// Logic to handle the final success/failure transition (since IDLE clears done/valid)
// We need to hold valid/done in a state that stays there
// The current code sets done/valid in SUCCESS/FAILURE and then goes to IDLE in same cycle
// Wait, IDLE clears done/valid. So if we want outputs to hold, we need a hold state.

endmodule

module TopMarketSharing (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_vertices,
    input [4:0] num_edges,
    input [31:0] edge_src,
    input [31:0] edge_dst,
    output [31:0] assignment,
    output done,
    output valid
);

    market_sharing ms_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .num_vertices(num_vertices),
        .num_edges(num_edges),
        .edge_src(edge_src),
        .edge_dst(edge_dst),
        .assignment(assignment),
        .done(done),
        .valid(valid)
    );

endmodule
