module gold_leaf_fold (
    input clk,
    input rst_n,
    input start,
    input [3:0] n, m,  // max 8x8
    input [63:0] grid, // 8x8 packed: row-major, each cell 1 bit
    output reg [3:0] r1, c1, r2, c2,
    output reg done
);

// Internal state machine
reg [2:0] state;
reg [2:0] fold_type; // 0:horizontal, 1:vertical, 2:diag1(45), 3:diag2(135)
reg [3:0] fold_param; // i for horizontal, j for vertical, k for diagonal
reg [3:0] check_r, check_c;
reg [3:0] best_r1, best_c1, best_r2, best_c2;
reg valid_found;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK_FOLD = 3'd1;
localparam [2:0] NEXT_FOLD = 3'd2;
localparam [2:0] DONE = 3'd3;

// Helper function to get grid cell (0-indexed)
function get_cell;
    input [3:0] r, c;
    get_cell = grid[r * 8 + c];
endfunction

// Mirror calculation functions
function [7:0] mirror_horizontal; // returns {r2, c2}
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

function [7:0] mirror_diag1; // slope 1: r-c = k
    input [3:0] r, c, k;
    begin
        mirror_diag1 = {k + c, r - k};
    end
endfunction

function [7:0] mirror_diag2; // slope -1: r+c = k
    input [3:0] r, c, k;
    begin
        mirror_diag2 = {k - c, k - r};
    end
endfunction

// Check if fold is valid for current candidate
reg check_valid;

always @(*) begin
    check_valid = 1'b1;
    case (fold_type)
        0: begin // horizontal
            for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                    if (check_r < fold_param) begin
                        // Check mirror
                        if (mirror_horizontal(check_r, check_c, fold_param)[3:0] < n && mirror_horizontal(check_r, check_c, fold_param)[7:4] < m) begin
                            if (get_cell(check_r, check_c) && get_cell(mirror_horizontal(check_r, check_c, fold_param)[3:0], mirror_horizontal(check_r, check_c, fold_param)[7:4])) begin
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
                        if (mirror_vertical(check_r, check_c, fold_param)[3:0] < n && mirror_vertical(check_r, check_c, fold_param)[7:4] < m) begin
                            if (get_cell(check_r, check_c) && get_cell(mirror_vertical(check_r, check_c, fold_param)[3:0], mirror_vertical(check_r, check_c, fold_param)[7:4])) begin
                                check_valid = 1'b0;
                            end
                        end
                    end
                end
            end
        end
        2: begin // diag1 - check fold line cells are '#'
            // Check fold line cells
            for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                    if (check_r - check_c == fold_param) begin
                        if (!get_cell(check_r, check_c)) begin
                            check_valid = 1'b0;
                        end
                    end
                end
            end
            // Check pairs
            if (check_valid) begin
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_r - check_c != fold_param) begin
                            if (mirror_diag1(check_r, check_c, fold_param)[3:0] < n && mirror_diag1(check_r, check_c, fold_param)[7:4] < m) begin
                                if (get_cell(check_r, check_c) && get_cell(mirror_diag1(check_r, check_c, fold_param)[3:0], mirror_diag1(check_r, check_c, fold_param)[7:4])) begin
                                    check_valid = 1'b0;
                                end
                            end
                        end
                    end
                end
            end
        end
        3: begin // diag2 - check fold line cells are '#'
            // Check fold line cells
            for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                    if (check_r + check_c == fold_param) begin
                        if (!get_cell(check_r, check_c)) begin
                            check_valid = 1'b0;
                        end
                    end
                end
            end
            // Check pairs
            if (check_valid) begin
                for (check_r = 0; check_r < n; check_r = check_r + 1) begin
                    for (check_c = 0; check_c < m; check_c = check_c + 1) begin
                        if (check_r + check_c != fold_param) begin
                            if (mirror_diag2(check_r, check_c, fold_param)[3:0] < n && mirror_diag2(check_r, check_c, fold_param)[7:4] < m) begin
                                if (get_cell(check_r, check_c) && get_cell(mirror_diag2(check_r, check_c, fold_param)[3:0], mirror_diag2(check_r, check_c, fold_param)[7:4])) begin
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

// Update best fold
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid_found <= 1'b0;
        best_r1 <= 4'd0;
        best_c1 <= 4'd0;
        best_r2 <= 4'd0;
        best_c2 <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK_FOLD;
                    fold_type <= 3'd0;
                    fold_param <= 4'd1; // Start with i=1 for horizontal (between row 1-2)
                    done <= 1'b0;
                end
            end
            CHECK_FOLD: begin
                if (check_valid) begin
                    // Compute output coordinates
                    case (fold_type)
                        0: begin // horizontal: (i,1,i,m)
                            r1 <= fold_param;
                            c1 <= 4'd1;
                            r2 <= fold_param;
                            c2 <= m;
                        end
                        1: begin // vertical: (1,j,n,j)
                            r1 <= 4'd1;
                            c1 <= fold_param;
                            r2 <= n;
                            c2 <= fold_param;
                        end
                        2: begin // diag1: find endpoints
                            // Simplified: output (1,1,n,m) for now
                            r1 <= 4'd1; c1 <= 4'd1; r2 <= n; c2 <= m;
                        end
                        3: begin // diag2: output (n,1,1,m)
                            r1 <= n; c1 <= 4'd1; r2 <= 4'd1; c2 <= m;
                        end
                    endcase
                    state <= NEXT_FOLD;
                end else begin
                    state <= NEXT_FOLD;
                end
            end
            NEXT_FOLD: begin
                // Move to next candidate
                if (fold_type == 3'd0 && fold_param < n-1) begin
                    fold_param <= fold_param + 4'd1;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd0) begin
                    fold_type <= 3'd1;
                    fold_param <= 4'd1;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd1 && fold_param < m-1) begin
                    fold_param <= fold_param + 4'd1;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd1) begin
                    fold_type <= 3'd2;
                    fold_param <= 4'd0;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd2 && fold_param < 8) begin // Simplified range
                    fold_param <= fold_param + 4'd1;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd2) begin
                    fold_type <= 3'd3;
                    fold_param <= 4'd2;
                    state <= CHECK_FOLD;
                end else if (fold_type == 3'd3 && fold_param < 8) begin
                    fold_param <= fold_param + 4'd1;
                    state <= CHECK_FOLD;
                end else begin
                    state <= DONE;
                    done <= 1'b1;
                end
            end
            DONE: begin
                state <= IDLE;
                done <= 1'b0;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule