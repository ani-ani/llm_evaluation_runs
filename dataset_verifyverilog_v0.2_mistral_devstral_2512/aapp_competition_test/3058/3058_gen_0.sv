module evolution_solver(
    input clk,
    input rst_n,
    input start,
    input [15:0][15:0][7:0] fossils,
    input [4:0] num_fossils,
    input [15:0][7:0] target,
    output reg [15:0] result_mask1,
    output reg [15:0] result_mask2,
    output reg valid,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        TRY_ASSIGN,
        CHECK_SUBSEQUENCE,
        BACKTRACK,
        SOLUTION,
        IMPOSSIBLE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] mask1, mask2;
    reg [3:0] current_fossil;
    reg [3:0] path1_count, path2_count;
    reg [3:0] check_index;
    reg [3:0] backtrack_index;
    reg [3:0] path1_fossils [0:15];
    reg [3:0] path2_fossils [0:15];
    reg path1_valid, path2_valid;
    reg [3:0] temp_fossil;
    reg [3:0] temp_path;

    // Helper function to check if seq1 is a subsequence of seq2
    function automatic bit is_subsequence;
        input [15:0][7:0] seq1;
        input [15:0][7:0] seq2;
        integer i, j;
        begin
            i = 0;
            j = 0;
            while (seq1[i] != 8'b0 && seq2[j] != 8'b0) begin
                if (seq1[i] == seq2[j]) begin
                    i = i + 1;
                end
                j = j + 1;
            end
            is_subsequence = (seq1[i] == 8'b0);
        end
    endfunction

    // Helper function to check if a fossil can be added to a path
    function automatic bit can_add_to_path;
        input [3:0] fossil_idx;
        input [3:0] path_idx;
        input [15:0] path_mask;
        integer k;
        begin
            can_add_to_path = 1'b1;
            for (k = 0; k < 16; k = k + 1) begin
                if (path_mask[k] && (k != fossil_idx)) begin
                    if (!is_subsequence(fossils[fossil_idx], fossils[k]) && 
                        !is_subsequence(fossils[k], fossils[fossil_idx])) begin
                        can_add_to_path = 1'b0;
                        break;
                    end
                end
            end
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            mask1 <= 16'b0;
            mask2 <= 16'b0;
            current_fossil <= 4'b0;
            path1_count <= 4'b0;
            path2_count <= 4'b0;
            check_index <= 4'b0;
            backtrack_index <= 4'b0;
            valid <= 1'b0;
            impossible <= 1'b0;
        end else begin
            current_state <= next_state;
            case (current_state)
                INIT: begin
                    mask1 <= 16'b0;
                    mask2 <= 16'b0;
                    current_fossil <= 4'b0;
                    path1_count <= 4'b0;
                    path2_count <= 4'b0;
                    check_index <= 4'b0;
                    backtrack_index <= 4'b0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                end
                TRY_ASSIGN: begin
                    if (current_fossil < num_fossils) begin
                        temp_fossil <= current_fossil;
                        temp_path <= 1'b0;
                    end
                end
                CHECK_SUBSEQUENCE: begin
                    if (temp_path == 1'b0) begin
                        if (can_add_to_path(temp_fossil, 1'b0, mask1)) begin
                            mask1[temp_fossil] <= 1'b1;
                            path1_fossils[path1_count] <= temp_fossil;
                            path1_count <= path1_count + 1'b1;
                            current_fossil <= current_fossil + 1'b1;
                        end else begin
                            temp_path <= 1'b1;
                        end
                    end else begin
                        if (can_add_to_path(temp_fossil, 1'b1, mask2)) begin
                            mask2[temp_fossil] <= 1'b1;
                            path2_fossils[path2_count] <= temp_fossil;
                            path2_count <= path2_count + 1'b1;
                            current_fossil <= current_fossil + 1'b1;
                        end else begin
                            backtrack_index <= current_fossil;
                        end
                    end
                end
                BACKTRACK: begin
                    if (backtrack_index > 0) begin
                        current_fossil <= backtrack_index - 1'b1;
                        if (mask1[current_fossil]) begin
                            mask1[current_fossil] <= 1'b0;
                            path1_count <= path1_count - 1'b1;
                        end else begin
                            mask2[current_fossil] <= 1'b0;
                            path2_count <= path2_count - 1'b1;
                        end
                    end else begin
                        impossible <= 1'b1;
                    end
                end
                SOLUTION: begin
                    result_mask1 <= mask1;
                    result_mask2 <= mask2;
                    valid <= 1'b1;
                end
                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = TRY_ASSIGN;
            end
            TRY_ASSIGN: begin
                if (current_fossil < num_fossils) begin
                    next_state = CHECK_SUBSEQUENCE;
                end else begin
                    next_state = SOLUTION;
                end
            end
            CHECK_SUBSEQUENCE: begin
                if (temp_path == 1'b0 && can_add_to_path(temp_fossil, 1'b0, mask1)) begin
                    next_state = TRY_ASSIGN;
                end else if (temp_path == 1'b1 && can_add_to_path(temp_fossil, 1'b1, mask2)) begin
                    next_state = TRY_ASSIGN;
                end else begin
                    next_state = BACKTRACK;
                end
            end
            BACKTRACK: begin
                if (backtrack_index > 0) begin
                    next_state = TRY_ASSIGN;
                end else begin
                    next_state = IMPOSSIBLE;
                end
            end
            SOLUTION: begin
                next_state = IDLE;
            end
            IMPOSSIBLE: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule