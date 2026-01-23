module market_sharing (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_vertices,
    input [4:0] num_edges,
    input [15:0] edge_src,
    input [15:0] edge_dst,
    output reg [31:0] assignment,
    output reg done,
    output reg valid
);

// Parameters
parameter MAX_N = 16;
parameter MAX_E = 16;
parameter MAX_DEG = 16;

// State encoding
parameter IDLE = 3'b000;
parameter INITIALIZE = 3'b001;
parameter ASSIGN_EDGE = 3'b010;
parameter VALIDATE = 3'b011;
parameter BACKTRACK = 3'b100;
parameter DONE = 3'b101;
parameter NO_SOLUTION = 3'b110;

// Internal registers
reg [2:0] state;
reg [4:0] current_edge;
reg [2:0] try_count; // 0=none, 1=try chain1, 2=try chain2, 3=both tried
reg [4:0] vertex;
reg [4:0] check_vertex;

// Storage arrays - flattened for Verilog compatibility
reg [1:0] edge_assign [0:15]; // 0=unassigned, 1=chain1, 2=chain2
reg [4:0] vertex_degree [0:15];
reg [4:0] count_chain1 [0:15];
reg [4:0] count_chain2 [0:15];
reg [15:0] edge_u [0:15]; // stored vertices
reg [15:0] edge_v [0:15];

// Stack for backtracking (stores edge index and assignment tried)
reg [4:0] stack_edge [0:15];
reg [1:0] stack_assign [0:15];
reg [4:0] stack_ptr;

integer i;
reg constraint_valid;
reg [4:0] temp_deg;
reg [4:0] temp_c1;
reg [4:0] temp_c2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        valid <= 0;
        current_edge <= 0;
        try_count <= 0;
        stack_ptr <= 0;
        for (i = 0; i < 16; i = i + 1) begin
            edge_assign[i] <= 0;
            vertex_degree[i] <= 0;
            count_chain1[i] <= 0;
            count_chain2[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INITIALIZE;
                    done <= 0;
                    valid <= 0;
                    current_edge <= 0;
                    try_count <= 0;
                    stack_ptr <= 0;
                end
            end
            
            INITIALIZE: begin
                // Load edges and compute degrees
                if (current_edge < num_edges) begin
                    edge_u[current_edge] <= edge_src[current_edge*2 +: 2]; // Extract vertex indices
                    edge_v[current_edge] <= edge_dst[current_edge*2 +: 2];
                    // Update degrees
                    vertex_degree[edge_src[current_edge*2 +: 2]] <= vertex_degree[edge_src[current_edge*2 +: 2]] + 1;
                    vertex_degree[edge_dst[current_edge*2 +: 2]] <= vertex_degree[edge_dst[current_edge*2 +: 2]] + 1;
                    current_edge <= current_edge + 1;
                end else begin
                    current_edge <= 0;
                    state <= ASSIGN_EDGE;
                end
            end
            
            ASSIGN_EDGE: begin
                if (current_edge >= num_edges) begin
                    // All edges assigned, check final validity
                    state <= VALIDATE;
                    check_vertex <= 0;
                end else if (edge_assign[current_edge] == 0) begin
                    // Not assigned yet
                    if (try_count == 0) begin
                        // Try chain 1 first
                        edge_assign[current_edge] <= 1;
                        // Update counts
                        count_chain1[edge_u[current_edge]] <= count_chain1[edge_u[current_edge]] + 1;
                        count_chain1[edge_v[current_edge]] <= count_chain1[edge_v[current_edge]] + 1;
                        try_count <= 1;
                        state <= VALIDATE;
                        check_vertex <= 0;
                    end else if (try_count == 1) begin
                        // Chain 1 failed, try chain 2
                        edge_assign[current_edge] <= 0; // Undo chain 1
                        count_chain1[edge_u[current_edge]] <= count_chain1[edge_u[current_edge]] - 1;
                        count_chain1[edge_v[current_edge]] <= count_chain1[edge_v[current_edge]] - 1;
                        #1; // Small delay for combinational update
                        edge_assign[current_edge] <= 2;
                        count_chain2[edge_u[current_edge]] <= count_chain2[edge_u[current_edge]] + 1;
                        count_chain2[edge_v[current_edge]] <= count_chain2[edge_v[current_edge]] + 1;
                        try_count <= 2;
                        state <= VALIDATE;
                        check_vertex <= 0;
                    end else begin
                        // Both tried and failed, backtrack
                        edge_assign[current_edge] <= 0;
                        state <= BACKTRACK;
                    end
                end else begin
                    // Already assigned, move to next
                    current_edge <= current_edge + 1;
                    try_count <= 0;
                end
            end
            
            VALIDATE: begin
                // Check constraints for vertices
                if (check_vertex >= num_vertices) begin
                    // All vertices checked and valid
                    if (current_edge >= num_edges) begin
                        state <= DONE;
                        valid <= 1;
                        done <= 1;
                    end else begin
                        // Push to stack and move to next edge
                        stack_edge[stack_ptr] <= current_edge;
                        stack_assign[stack_ptr] <= edge_assign[current_edge];
                        stack_ptr <= stack_ptr + 1;
                        current_edge <= current_edge + 1;
                        try_count <= 0;
                        state <= ASSIGN_EDGE;
                    end
                end else begin
                    // Check this vertex
                    if (vertex_degree[check_vertex] >= 2) begin
                        // Must have both chains
                        if (count_chain1[check_vertex] > 0 && count_chain2[check_vertex] > 0) begin
                            check_vertex <= check_vertex + 1;
                            state <= VALIDATE;
                        end else begin
                            // Constraint violated, backtrack or retry
                            edge_assign[current_edge] <= 0;
                            // Undo counts
                            if (try_count == 1) begin
                                count_chain1[edge_u[current_edge]] <= count_chain1[edge_u[current_edge]] - 1;
                                count_chain1[edge_v[current_edge]] <= count_chain1[edge_v[current_edge]] - 1;
                            end else if (try_count == 2) begin
                                count_chain2[edge_u[current_edge]] <= count_chain2[edge_u[current_edge]] - 1;
                                count_chain2[edge_v[current_edge]] <= count_chain2[edge_v[current_edge]] - 1;
                            end
                            state <= BACKTRACK;
                        end
                    end else begin
                        // No constraint for deg <= 1
                        check_vertex <= check_vertex + 1;
                        state <= VALIDATE;
                    end
                end
            end
            
            BACKTRACK: begin
                if (stack_ptr == 0) begin
                    // Cannot backtrack further, no solution
                    state <= NO_SOLUTION;
                end else begin
                    // Pop stack
                    stack_ptr <= stack_ptr - 1;
                    current_edge <= stack_edge[stack_ptr - 1];
                    try_count <= 2; // Already tried 1, so next will be 2 or done
                    // Undo previous assignment
                    edge_assign[stack_edge[stack_ptr - 1]] <= 0;
                    count_chain1[edge_u[stack_edge[stack_ptr - 1]]] <= count_chain1[edge_u[stack_edge[stack_ptr - 1]]] - 1;
                    count_chain1[edge_v[stack_edge[stack_ptr - 1]]] <= count_chain1[edge_v[stack_edge[stack_ptr - 1]]] - 1;
                    state <= ASSIGN_EDGE;
                end
            end
            
            DONE: begin
                // Output assignments packed into 32-bit register
                for (i = 0; i < 16; i = i + 1) begin
                    assignment[i*2 +: 2] <= edge_assign[i];
                end
                done <= 1;
                valid <= 1;
            end
            
            NO_SOLUTION: begin
                assignment <= 0;
                done <= 1;
                valid <= 0;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule