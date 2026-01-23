module gold_leaf_fold (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [63:0] grid,
    output reg [3:0] r1,
    output reg [3:0] c1,
    output reg [3:0] r2,
    output reg [3:0] c2,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_FOLD = 3'd1;
    localparam [2:0] NEXT_FOLD = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal state
    reg [2:0] state;
    reg [2:0] fold_type; // 0:horizontal, 1:vertical, 2:diag1, 3:diag2
    reg [3:0] fold_param;
    reg [3:0] check_r;
    reg [3:0] check_c;
    reg check_valid;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd7;

    // Helper function to get grid cell (0-indexed)
    function get_cell;
        input [3:0] r, c;
        begin
            get_cell = grid[r * 8 + c];
        end
    endfunction

    // Mirror calculation functions
    function [7:0] mirror_horizontal;
        input [3:0] r, c, i;
        begin
            mirror_horizontal = {2*i + 1 - r, c};
        end
    endfunction

    function [7:0] mirror_vertical;
        input [3:0] r, c, j;
        begin
            mirror_vertical = {r, 2*j + 1 - c};
        end
    endfunction

    function [7:0] mirror_diag1;
        input [3:0] r, c, k;
        begin
            mirror_diag1 = {k + c, r - k};
        end
    endfunction

    function [7:0] mirror_diag2;
        input [3:0] r, c, k;
        begin
            mirror_diag2 = {k - c, k - r};
        end
    endfunction

    always @(*) begin
        check_valid = 1'b1;
        case (fold_type)
            0: begin // horizontal
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_r < fold_param) begin
                            if (mirror_horizontal(check_r, check_c, fold_param) < {n, m}) begin
                                if (get_cell(check_r, check_c) && get_cell(mirror_horizontal(check_r, check_c, fold_param))) begin
                                    check_valid = 1'b0;
                                end
                            end
                        end
                    end
                end
            end
            1: begin // vertical
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_c < fold_param) begin
                            if (mirror_vertical(check_r, check_c, fold_param) < {n, m}) begin
                                if (get_cell(check_r, check_c) && get_cell(mirror_vertical(check_r, check_c, fold_param))) begin
                                    check_valid = 1'b0;
                                end
                            end
                        end
                    end
                end
            end
            2: begin // diag1
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_r - check_c == fold_param) begin
                            if (!get_cell(check_r, check_c)) begin
                                check_valid = 1'b0;
                            end
                        end
                    end
                end
                if (check_valid) begin
                    for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                        for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                            if (check_r - check_c != fold_param) begin
                                if (mirror_diag1(check_r, check_c, fold_param) < {n, m}) begin
                                    if (get_cell(check_r, check_c) && get_cell(mirror_diag1(check_r, check_c, fold_param))) begin
                                        check_valid = 1'b0;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            3: begin // diag2
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_r + check_c == fold_param) begin
                            if (!get_cell(check_r, check_c)) begin
                                check_valid = 1'b0;
                            end
                        end
                    end
                end
                if (check_valid) begin
                    for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                        for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                            if (check_r + check_c != fold_param) begin
                                if (mirror_diag2(check_r, check_c, fold_param) < {n, m}) begin
                                    if (get_cell(check_r, check_c) && get_cell(mirror_diag2(check_r, check_c, fold_param))) begin
                                        check_valid = 1'b0;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            r1 <= 4'd15;
            c1 <= 4'd15;
            r2 <= 4'd15;
            c2 <= 4'd15;
            fold_type <= 3'd0;
            fold_param <= 4'd0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= CHECK_FOLD;
                        fold_type <= 3'd0;
                        fold_param <= 4'd1;
                    end
                end
                CHECK_FOLD: begin
                    if (check_valid) begin
                        case (fold_type)
                            0: begin // horizontal
                                r1 <= fold_param;
                                c1 <= 4'd1;
                                r2 <= fold_param;
                                c2 <= m;
                            end
                            1: begin // vertical
                                r1 <= 4'd1;
                                c1 <= fold_param;
                                r2 <= n;
                                c2 <= fold_param;
                            end
                            2: begin // diag1
                                r1 <= 4'd1;
                                c1 <= 4'd1;
                                r2 <= n;
                                c2 <= m;
                            end
                            3: begin // diag2
                                r1 <= n;
                                c1 <= 4'd1;
                                r2 <= 4'd1;
                                c2 <= m;
                            end
                        endcase
                    end
                    state <= NEXT_FOLD;
                end
                NEXT_FOLD: begin
                    cycle_count <= cycle_count + 3'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        if (fold_type == 3'd0 && fold_param < n - 4'd1) begin
                            fold_param <= fold_param + 4'd1;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd0) begin
                            fold_type <= 3'd1;
                            fold_param <= 4'd1;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd1 && fold_param < m - 4'd1) begin
                            fold_param <= fold_param + 4'd1;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd1) begin
                            fold_type <= 3'd2;
                            fold_param <= 4'd0;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd2 && fold_param < 4'd8) begin
                            fold_param <= fold_param + 4'd1;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd2) begin
                            fold_type <= 3'd3;
                            fold_param <= 4'd2;
                            state <= CHECK_FOLD;
                        end else if (fold_type == 3'd3 && fold_param < 4'd8) begin
                            fold_param <= fold_param + 4'd1;
                            state <= CHECK_FOLD;
                        end else begin
                            state <= DONE;
                            done <= 1'b1;
                        end
                    end
                end
                DONE: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule