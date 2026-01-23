module gold_leaf_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] grid_row [15:0],
    output reg [3:0] r1,
    output reg [3:0] c1,
    output reg [3:0] r2,
    output reg [3:0] c2,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        H_CHECK,
        V_CHECK,
        D_CHECK,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [3:0] h_row;
    reg [3:0] v_col;
    reg [3:0] d_line;
    reg [3:0] d_start_row;
    reg [3:0] d_start_col;

    reg [3:0] temp_r1, temp_c1, temp_r2, temp_c2;
    reg temp_valid;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            h_row <= 0;
            v_col <= 0;
            d_line <= 0;
            d_start_row <= 0;
            d_start_col <= 0;
            temp_r1 <= 0;
            temp_c1 <= 0;
            temp_r2 <= 0;
            temp_c2 <= 0;
            temp_valid <= 0;
            r1 <= 0;
            c1 <= 0;
            r2 <= 0;
            c2 <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            if (state == H_CHECK && start) begin
                if (h_row == 15) begin
                    next_state <= V_CHECK;
                    h_row <= 0;
                end else begin
                    h_row <= h_row + 1;
                end
            end else if (state == V_CHECK && start) begin
                if (v_col == 15) begin
                    next_state <= D_CHECK;
                    v_col <= 0;
                end else begin
                    v_col <= v_col + 1;
                end
            end else if (state == D_CHECK && start) begin
                if (d_line == 15) begin
                    next_state <= DONE;
                    d_line <= 0;
                end else begin
                    d_line <= d_line + 1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = H_CHECK;
            end
            H_CHECK: begin
                if (check_horizontal(h_row + 1)) begin
                    next_state = DONE;
                end
            end
            V_CHECK: begin
                if (check_vertical(v_col + 1)) begin
                    next_state = DONE;
                end
            end
            D_CHECK: begin
                if (check_diagonal(d_line + 1)) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Check horizontal fold
    function automatic bit check_horizontal(input [3:0] row);
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (grid_row[row - 1][i] != grid_row[16 - row][i]) begin
                if (grid_row[row - 1][i] == 0) begin
                    return 0;
                end
            end
        end
        temp_r1 = row;
        temp_c1 = 1;
        temp_r2 = row;
        temp_c2 = 16;
        temp_valid = 1;
        return 1;
    endfunction

    // Check vertical fold
    function automatic bit check_vertical(input [3:0] col);
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (grid_row[i][col - 1] != grid_row[i][16 - col]) begin
                if (grid_row[i][col - 1] == 0) begin
                    return 0;
                end
            end
        end
        temp_r1 = 1;
        temp_c1 = col;
        temp_r2 = 16;
        temp_c2 = col;
        temp_valid = 1;
        return 1;
    endfunction

    // Check diagonal fold
    function automatic bit check_diagonal(input [3:0] line);
        integer i, j;
        for (i = 0; i < 16; i = i + 1) begin
            j = line - 1 + i;
            if (j >= 16) break;
            if (grid_row[i][j] != grid_row[15 - j][15 - i]) begin
                if (grid_row[i][j] == 0) begin
                    return 0;
                end
            end
        end
        temp_r1 = line;
        temp_c1 = 1;
        temp_r2 = 16 - line + 1;
        temp_c2 = 16;
        temp_valid = 1;
        return 1;
    endfunction

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1 <= 0;
            c1 <= 0;
            r2 <= 0;
            c2 <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            if (state == DONE && temp_valid) begin
                r1 <= temp_r1;
                c1 <= temp_c1;
                r2 <= temp_r2;
                c2 <= temp_c2;
                valid <= 1;
                done <= 1;
            end else begin
                valid <= 0;
                done <= 0;
            end
        end
    end

endmodule