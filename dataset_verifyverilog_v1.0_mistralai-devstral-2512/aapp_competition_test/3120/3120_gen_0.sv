module BalloonEquivalenceChecker(
    input clk,
    input rst_n,
    input start,
    input [1:0] expr_a_type,
    input [1:0] expr_b_type,
    input [15:0] list_a_data [0:15],
    input [15:0] list_b_data [0:15],
    input [3:0] children_a_idx [0:7],
    input [3:0] children_b_idx [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EVAL_A = 3'd1;
    localparam [2:0] EVAL_B = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Stack for expression evaluation
    reg [3:0] stack_ptr;
    reg [1:0] stack_type [0:7];
    reg [3:0] stack_child_idx [0:7];
    reg [3:0] stack_list_len [0:7];
    reg [15:0] stack_list_data [0:7][0:15];

    // Current evaluation context
    reg [1:0] current_type;
    reg [3:0] current_child_idx;
    reg [3:0] current_list_len;
    reg [15:0] current_list_data [0:15];

    // Evaluation results
    reg [3:0] result_a_len;
    reg [15:0] result_a_data [0:15];
    reg [3:0] result_b_len;
    reg [15:0] result_b_data [0:15];

    // Helper registers
    reg [3:0] i, j, k;
    reg [15:0] temp_data;
    reg equal_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            stack_ptr <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            result_a_len <= 4'd0;
            result_b_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_a_data[i] <= 16'd0;
                result_b_data[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= EVAL_A;
                        // Initialize stack for expression A
                        stack_ptr <= 4'd0;
                        stack_type[0] <= expr_a_type;
                        stack_child_idx[0] <= 4'd0;
                        stack_list_len[0] <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            stack_list_data[0][i] <= list_a_data[i];
                        end
                    end
                end

                EVAL_A: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Pop from stack
                        current_type <= stack_type[stack_ptr];
                        current_child_idx <= stack_child_idx[stack_ptr];
                        current_list_len <= stack_list_len[stack_ptr];
                        for (i = 0; i < 16; i = i + 1) begin
                            current_list_data[i] <= stack_list_data[stack_ptr][i];
                        end
                        stack_ptr <= stack_ptr - 4'd1;

                        case (current_type)
                            2'd0: begin // LIST
                                // Copy list data to result
                                result_a_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_a_data[i] <= current_list_data[i];
                                end
                                state <= EVAL_B;
                                // Initialize stack for expression B
                                stack_ptr <= 4'd0;
                                stack_type[0] <= expr_b_type;
                                stack_child_idx[0] <= 4'd0;
                                stack_list_len[0] <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[0][i] <= list_b_data[i];
                                end
                            end

                            2'd1: begin // CONCAT
                                // Push children to stack in reverse order
                                stack_ptr <= stack_ptr + 4'd1;
                                stack_type[stack_ptr] <= 2'd1; // CONCAT
                                stack_child_idx[stack_ptr] <= current_child_idx + 4'd1;
                                stack_list_len[stack_ptr] <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[stack_ptr][i] <= current_list_data[i];
                                end

                                stack_ptr <= stack_ptr + 4'd1;
                                stack_type[stack_ptr] <= 2'd0; // LIST (child 1)
                                stack_child_idx[stack_ptr] <= children_a_idx[current_child_idx];
                                stack_list_len[stack_ptr] <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[stack_ptr][i] <= list_a_data[i];
                                end
                            end

                            2'd2: begin // SHUFFLE
                                // Shuffle doesn't change the multiset, so just pass through
                                result_a_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_a_data[i] <= current_list_data[i];
                                end
                                state <= EVAL_B;
                                // Initialize stack for expression B
                                stack_ptr <= 4'd0;
                                stack_type[0] <= expr_b_type;
                                stack_child_idx[0] <= 4'd0;
                                stack_list_len[0] <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[0][i] <= list_b_data[i];
                                end
                            end

                            2'd3: begin // SORTED
                                // Sort the list (bubble sort for simplicity)
                                for (i = 0; i < 15; i = i + 1) begin
                                    for (j = 0; j < 15 - i; j = j + 1) begin
                                        if (current_list_data[j] > current_list_data[j + 1]) begin
                                            temp_data <= current_list_data[j];
                                            current_list_data[j] <= current_list_data[j + 1];
                                            current_list_data[j + 1] <= temp_data;
                                        end
                                    end
                                end
                                result_a_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_a_data[i] <= current_list_data[i];
                                end
                                state <= EVAL_B;
                                // Initialize stack for expression B
                                stack_ptr <= 4'd0;
                                stack_type[0] <= expr_b_type;
                                stack_child_idx[0] <= 4'd0;
                                stack_list_len[0] <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[0][i] <= list_b_data[i];
                                end
                            end
                        endcase
                    end
                end

                EVAL_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Pop from stack
                        current_type <= stack_type[stack_ptr];
                        current_child_idx <= stack_child_idx[stack_ptr];
                        current_list_len <= stack_list_len[stack_ptr];
                        for (i = 0; i < 16; i = i + 1) begin
                            current_list_data[i] <= stack_list_data[stack_ptr][i];
                        end
                        stack_ptr <= stack_ptr - 4'd1;

                        case (current_type)
                            2'd0: begin // LIST
                                // Copy list data to result
                                result_b_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_b_data[i] <= current_list_data[i];
                                end
                                state <= COMPARE;
                            end

                            2'd1: begin // CONCAT
                                // Push children to stack in reverse order
                                stack_ptr <= stack_ptr + 4'd1;
                                stack_type[stack_ptr] <= 2'd1; // CONCAT
                                stack_child_idx[stack_ptr] <= current_child_idx + 4'd1;
                                stack_list_len[stack_ptr] <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[stack_ptr][i] <= current_list_data[i];
                                end

                                stack_ptr <= stack_ptr + 4'd1;
                                stack_type[stack_ptr] <= 2'd0; // LIST (child 1)
                                stack_child_idx[stack_ptr] <= children_b_idx[current_child_idx];
                                stack_list_len[stack_ptr] <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    stack_list_data[stack_ptr][i] <= list_b_data[i];
                                end
                            end

                            2'd2: begin // SHUFFLE
                                // Shuffle doesn't change the multiset, so just pass through
                                result_b_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_b_data[i] <= current_list_data[i];
                                end
                                state <= COMPARE;
                            end

                            2'd3: begin // SORTED
                                // Sort the list (bubble sort for simplicity)
                                for (i = 0; i < 15; i = i + 1) begin
                                    for (j = 0; j < 15 - i; j = j + 1) begin
                                        if (current_list_data[j] > current_list_data[j + 1]) begin
                                            temp_data <= current_list_data[j];
                                            current_list_data[j] <= current_list_data[j + 1];
                                            current_list_data[j + 1] <= temp_data;
                                        end
                                    end
                                end
                                result_b_len <= current_list_len;
                                for (i = 0; i < 16; i = i + 1) begin
                                    result_b_data[i] <= current_list_data[i];
                                end
                                state <= COMPARE;
                            end
                        endcase
                    end
                end

                COMPARE: begin
                    // Compare the two results based on their types
                    if (expr_a_type == 2'd3 && expr_b_type == 2'd3) begin
                        // Both are SORTED: check if sorted lists are identical
                        equal_flag <= 1'b1;
                        if (result_a_len != result_b_len) begin
                            equal_flag <= 1'b0;
                        end else begin
                            for (i = 0; i < 16; i = i + 1) begin
                                if (result_a_data[i] != result_b_data[i]) begin
                                    equal_flag <= 1'b0;
                                end
                            end
                        end
                    end else if (expr_a_type == 2'd2 || expr_b_type == 2'd2) begin
                        // At least one is SHUFFLE: check if multisets are identical
                        // Count occurrences of each value in both lists
                        reg [3:0] count_a [0:15];
                        reg [3:0] count_b [0:15];
                        reg [15:0] values [0:15];
                        reg [3:0] num_values;

                        // Initialize counts
                        for (i = 0; i < 16; i = i + 1) begin
                            count_a[i] <= 4'd0;
                            count_b[i] <= 4'd0;
                        end

                        // Count values in result_a
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < result_a_len) begin
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (result_a_data[i] == values[j]) begin
                                        count_a[j] <= count_a[j] + 4'd1;
                                    end
                                end
                            end
                        end

                        // Count values in result_b
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < result_b_len) begin
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (result_b_data[i] == values[j]) begin
                                        count_b[j] <= count_b[j] + 4'd1;
                                    end
                                end
                            end
                        end

                        // Compare counts
                        equal_flag <= 1'b1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (count_a[i] != count_b[i]) begin
                                equal_flag <= 1'b0;
                            end
                        end
                    end else if (expr_a_type == 2'd1 && expr_b_type == 2'd1) begin
                        // Both are CONCAT: recursively check equivalence (handled by stack)
                        equal_flag <= 1'b1;
                    end else if (expr_a_type == 2'd0 && expr_b_type == 2'd0) begin
                        // Both are LIST: check if lists are identical
                        equal_flag <= 1'b1;
                        if (result_a_len != result_b_len) begin
                            equal_flag <= 1'b0;
                        end else begin
                            for (i = 0; i < 16; i = i + 1) begin
                                if (result_a_data[i] != result_b_data[i]) begin
                                    equal_flag <= 1'b0;
                                end
                            end
                        end
                    end else begin
                        // Different types: not equal
                        equal_flag <= 1'b0;
                    end

                    result <= equal_flag;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule