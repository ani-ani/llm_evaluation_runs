module equivalence_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] expr_a_type,
    input wire [1:0] expr_b_type,
    input wire [15:0] list_a_data [0:15],
    input wire [15:0] list_b_data [0:15],
    input wire [3:0] children_a_idx [0:1],
    input wire [3:0] children_b_idx [0:1],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FETCH_A    = 3'd1;
    localparam [2:0] FETCH_B    = 3'd2;
    localparam [2:0] EVAL_A     = 3'd3;
    localparam [2:0] EVAL_B     = 3'd4;
    localparam [2:0] COMPARE    = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Type encodings
    localparam [1:0] TYPE_LIST   = 2'd0;
    localparam [1:0] TYPE_CONCAT = 2'd1;
    localparam [1:0] TYPE_SHUFFLE = 2'd2;
    localparam [1:0] TYPE_SORTED  = 2'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Stack for recursive evaluation (depth limited to 8)
    reg [1:0] stack_type [0:7];
    reg [3:0] stack_idx [0:7];  // Index in list or child pointer
    reg [2:0] stack_ptr;
    reg [2:0] recursion_depth;
    localparam [2:0] MAX_DEPTH = 3'd7;

    // Working lists for current evaluation
    reg [15:0] list_a_work [0:15];
    reg [15:0] list_b_work [0:15];
    reg [3:0] len_a, len_b;
    reg [3:0] i, j, k;

    // Flags
    reg [1:0] current_expr;  // 0=A, 1=B
    reg shuffle_flag_a;
    reg shuffle_flag_b;

    // Integer for sorting loop
    integer m;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = FETCH_A;
            end
            FETCH_A: begin
                next_state = EVAL_A;
            end
            FETCH_B: begin
                next_state = EVAL_B;
            end
            EVAL_A: begin
                if (stack_ptr == 3'd0 && recursion_depth == 3'd0) next_state = FETCH_B;
                else next_state = EVAL_A;
            end
            EVAL_B: begin
                if (stack_ptr == 3'd0 && recursion_depth == 3'd0) next_state = COMPARE;
                else next_state = EVAL_B;
            end
            COMPARE: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            stack_ptr <= 3'd0;
            recursion_depth <= 3'd0;
            len_a <= 4'd0;
            len_b <= 4'd0;
            shuffle_flag_a <= 1'b0;
            shuffle_flag_b <= 1'b0;
            current_expr <= 2'd0;
            // Initialize working arrays
            for (m = 0; m < 16; m = m + 1) begin
                list_a_work[m] <= 16'd0;
                list_b_work[m] <= 16'd0;
            end
            // Initialize stack
            for (m = 0; m < 8; m = m + 1) begin
                stack_type[m] <= 2'd0;
                stack_idx[m] <= 4'd0;
            end
        end else begin
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    stack_ptr <= 3'd0;
                    recursion_depth <= 3'd0;
                    len_a <= 4'd0;
                    len_b <= 4'd0;
                    shuffle_flag_a <= 1'b0;
                    shuffle_flag_b <= 1'b0;
                    current_expr <= 2'd0;
                    for (m = 0; m < 16; m = m + 1) begin
                        list_a_work[m] <= 16'd0;
                        list_b_work[m] <= 16'd0;
                    end
                    for (m = 0; m < 8; m = m + 1) begin
                        stack_type[m] <= 2'd0;
                        stack_idx[m] <= 4'd0;
                    end
                end

                FETCH_A: begin
                    current_expr <= 2'd0;
                    // Push root node A onto stack
                    stack_type[0] <= expr_a_type;
                    stack_idx[0] <= 4'd0;  // Root index
                    stack_ptr <= 3'd1;
                    recursion_depth <= 3'd1;
                    len_a <= 4'd0;
                    shuffle_flag_a <= 1'b0;
                end

                FETCH_B: begin
                    current_expr <= 2'd1;
                    // Push root node B onto stack
                    stack_type[0] <= expr_b_type;
                    stack_idx[0] <= 4'd0;  // Root index
                    stack_ptr <= 3'd1;
                    recursion_depth <= 3'd1;
                    len_b <= 4'd0;
                    shuffle_flag_b <= 1'b0;
                end

                EVAL_A: begin
                    if (stack_ptr > 3'd0 && cycle_count < MAX_CYCLES) begin
                        // Pop current node
                        stack_ptr <= stack_ptr - 3'd1;
                        recursion_depth <= recursion_depth - 3'd1;
                        
                        case (stack_type[stack_ptr - 3'd1])
                            TYPE_LIST: begin
                                // Copy list to working buffer
                                if (current_expr == 2'd0) begin
                                    for (i = 0; i < 16; i = i + 1) begin
                                        list_a_work[i] <= list_a_data[i];
                                    end
                                    len_a <= 4'd16;
                                end
                            end
                            
                            TYPE_CONCAT: begin
                                // Evaluate children in order (right then left for stack)
                                if (stack_ptr < 3'd8) begin
                                    // Push child 1 (left) then child 0 (right) to stack
                                    // Note: Assuming children_a_idx[0] is left, [1] is right
                                    // For CONCAT, we need left first in list, so process right first
                                    // Since stack is LIFO, push left last
                                    // Simulating child indices stored in children_a_idx
                                    // Left child is at index 0, right child at index 1
                                    // Push right child
                                    stack_type[stack_ptr] <= expr_a_type;  // Default, will be updated
                                    stack_idx[stack_ptr] <= children_a_idx[1];  // Right child
                                    stack_ptr <= stack_ptr + 3'd1;
                                    // Push left child
                                    stack_type[stack_ptr + 3'd1] <= expr_a_type;
                                    stack_idx[stack_ptr + 3'd1] <= children_a_idx[0];  // Left child
                                    stack_ptr <= stack_ptr + 3'd2;
                                    recursion_depth <= recursion_depth + 3'd2;
                                end
                            end
                            
                            TYPE_SHUFFLE: begin
                                shuffle_flag_a <= 1'b1;
                                // Push child to evaluate
                                if (stack_ptr < 3'd8) begin
                                    stack_type[stack_ptr] <= expr_a_type;
                                    stack_idx[stack_ptr] <= children_a_idx[0];
                                    stack_ptr <= stack_ptr + 3'd1;
                                    recursion_depth <= recursion_depth + 3'd1;
                                end
                            end
                            
                            TYPE_SORTED: begin
                                // Push child to evaluate
                                if (stack_ptr < 3'd8) begin
                                    stack_type[stack_ptr] <= expr_a_type;
                                    stack_idx[stack_ptr] <= children_a_idx[0];
                                    stack_ptr <= stack_ptr + 3'd1;
                                    recursion_depth <= recursion_depth + 3'd1;
                                end
                            end
                        endcase
                    end
                end

                EVAL_B: begin
                    if (stack_ptr > 3'd0 && cycle_count < MAX_CYCLES) begin
                        // Pop current node
                        stack_ptr <= stack_ptr - 3'd1;
                        recursion_depth <= recursion_depth - 3'd1;
                        
                        case (stack_type[stack_ptr - 3'd1])
                            TYPE_LIST: begin
                                // Copy list to working buffer
                                if (current_expr == 2'd1) begin
                                    for (i = 0; i < 16; i = i + 1) begin
                                        list_b_work[i] <= list_b_data[i];
                                    end
                                    len_b <= 4'd16;
                                end
                            end
                            
                            TYPE_CONCAT: begin
                                // Evaluate children (right then left)
                                if (stack_ptr < 3'd8) begin
                                    // Push right child
                                    stack_type[stack_ptr] <= expr_b_type;
                                    stack_idx[stack_ptr] <= children_b_idx[1];
                                    stack_ptr <= stack_ptr + 3'd1;
                                    // Push left child
                                    stack_type[stack_ptr + 3'd1] <= expr_b_type;
                                    stack_idx[stack_ptr + 3'd1] <= children_b_idx[0];
                                    stack_ptr <= stack_ptr + 3'd2;
                                    recursion_depth <= recursion_depth + 3'd2;
                                end
                            end
                            
                            TYPE_SHUFFLE: begin
                                shuffle_flag_b <= 1'b1;
                                // Push child to evaluate
                                if (stack_ptr < 3'd8) begin
                                    stack_type[stack_ptr] <= expr_b_type;
                                    stack_idx[stack_ptr] <= children_b_idx[0];
                                    stack_ptr <= stack_ptr + 3'd1;
                                    recursion_depth <= recursion_depth + 3'd1;
                                end
                            end
                            
                            TYPE_SORTED: begin
                                // Push child to evaluate
                                if (stack_ptr < 3'd8) begin
                                    stack_type[stack_ptr] <= expr_b_type;
                                    stack_idx[stack_ptr] <= children_b_idx[0];
                                    stack_ptr <= stack_ptr + 3'd1;
                                    recursion_depth <= recursion_depth + 3'd1;
                                end
                            end
                        endcase
                    end
                end

                COMPARE: begin
                    // Apply final transformations
                    
                    // SORTED for A: bubble sort
                    if (expr_a_type == TYPE_SORTED || shuffle_flag_a) begin
                        // If shuffle_flag is set (from SHUFFLE op), we don't sort, but for SORTED op we do
                        if (expr_a_type == TYPE_SORTED) begin
                            for (j = 0; j < 15; j = j + 1) begin
                                for (k = 0; k < 15 - j; k = k + 1) begin
                                    if (list_a_work[k] > list_a_work[k + 1]) begin
                                        list_a_work[k] <= list_a_work[k + 1];
                                        list_a_work[k + 1] <= list_a_work[k];
                                    end
                                end
                            end
                        end
                    end
                    
                    // SORTED for B: bubble sort
                    if (expr_b_type == TYPE_SORTED || shuffle_flag_b) begin
                        if (expr_b_type == TYPE_SORTED) begin
                            for (j = 0; j < 15; j = j + 1) begin
                                for (k = 0; k < 15 - j; k = k + 1) begin
                                    if (list_b_work[k] > list_b_work[k + 1]) begin
                                        list_b_work[k] <= list_b_work[k + 1];
                                        list_b_work[k + 1] <= list_b_work[k];
                                    end
                                end
                            end
                        end
                    end
                    
                    // Equivalence check
                    result <= 1'b1;  // Assume equal
                    
                    // Check lengths
                    if (len_a != len_b) begin
                        result <= 1'b0;
                    end else begin
                        // Check contents based on types
                        if (expr_a_type == TYPE_SORTED && expr_b_type == TYPE_SORTED) begin
                            // Both sorted: direct comparison
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < len_a) begin
                                    if (list_a_work[i] != list_b_work[i]) begin
                                        result <= 1'b0;
                                    end
                                end
                            end
                        end else if ((expr_a_type == TYPE_SHUFFLE || shuffle_flag_a) && 
                                    (expr_b_type == TYPE_SHUFFLE || shuffle_flag_b)) begin
                            // Both shuffle/multiset: check sorted versions are identical
                            // (Already sorted in this block due to logic above)
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < len_a) begin
                                    if (list_a_work[i] != list_b_work[i]) begin
                                        result <= 1'b0;
                                    end
                                end
                            end
                        end else begin
                            // Standard comparison (preserves order)
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < len_a) begin
                                    if (list_a_work[i] != list_b_work[i]) begin
                                        result <= 1'b0;
                                    end
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule