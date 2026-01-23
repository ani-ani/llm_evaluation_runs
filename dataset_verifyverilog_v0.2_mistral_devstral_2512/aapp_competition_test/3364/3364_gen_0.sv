module dsu_union_find (
    input clk,
    input rst_n,
    input start,
    input [2:0] op_type,
    input [2:0] a,
    input [2:0] b,
    output reg result,
    output reg done,
    output reg [2:0] parent [0:7]
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        FIND_A_ROOT,
        FIND_B_ROOT,
        UNION_OP,
        QUERY_OP,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] root_a, root_b;
    reg [2:0] current_node;
    reg [2:0] temp_parent;
    reg [2:0] stack [0:7];
    reg [2:0] stack_ptr;
    reg [3:0] cycle_count;

    // Initialize parent array on reset
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                parent[i] <= i;
            end
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            root_a <= 0;
            root_b <= 0;
            current_node <= 0;
            temp_parent <= 0;
            stack_ptr <= 0;
            cycle_count <= 0;
        end else begin
            current_state <= next_state;
            
            // State machine actions
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= FIND_A_ROOT;
                        cycle_count <= 0;
                        current_node <= a;
                        stack_ptr <= 0;
                    end
                end
                
                FIND_A_ROOT: begin
                    if (cycle_count < 20) begin
                        // Find root of a with path compression
                        if (parent[current_node] == current_node) begin
                            root_a <= current_node;
                            next_state <= FIND_B_ROOT;
                            current_node <= b;
                            stack_ptr <= 0;
                        end else begin
                            stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1;
                            current_node <= parent[current_node];
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                FIND_B_ROOT: begin
                    if (cycle_count < 20) begin
                        // Find root of b with path compression
                        if (parent[current_node] == current_node) begin
                            root_b <= current_node;
                            // Path compression
                            for (i = 0; i < stack_ptr; i = i + 1) begin
                                parent[stack[i]] <= root_b;
                            end
                            
                            if (op_type == 0) begin
                                next_state <= UNION_OP;
                            end else begin
                                next_state <= QUERY_OP;
                            end
                            stack_ptr <= 0;
                        end else begin
                            stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1;
                            current_node <= parent[current_node];
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                UNION_OP: begin
                    if (cycle_count < 20) begin
                        // Perform union operation
                        parent[root_a] <= root_b;
                        next_state <= DONE;
                        cycle_count <= cycle_count + 1;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                QUERY_OP: begin
                    if (cycle_count < 20) begin
                        // Compare roots
                        result <= (root_a == root_b);
                        next_state <= DONE;
                        cycle_count <= cycle_count + 1;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        done <= 0;
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Default state transitions
    always @(*) begin
        next_state = current_state;
    end

endmodule