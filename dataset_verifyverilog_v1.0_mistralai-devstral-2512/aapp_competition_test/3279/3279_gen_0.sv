module BarCodeSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_val,
    input [3:0] row_spec [0:8][0:8],
    input [3:0] col_spec [0:8][0:8],
    input [3:0] row_spec_len [0:8],
    input [3:0] col_spec_len [0:8],
    output reg [0:8][0:9] vertical_bars,
    output reg [0:9][0:8] horizontal_bars,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SOLVE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] ERROR = 3'd5;

    reg [2:0] state, next_state;

    // Internal state
    reg [0:8][0:9] v_state;
    reg [0:9][0:8] h_state;
    reg [7:0] pos;
    reg [7:0] max_pos;
    reg [3:0] n;
    reg [3:0] row_idx, col_idx;
    reg [3:0] group_idx;
    reg [3:0] current_group;
    reg [3:0] group_count;
    reg [3:0] temp_count;
    reg valid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            pos <= 8'd0;
            max_pos <= 8'd0;
            n <= 4'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            group_idx <= 4'd0;
            current_group <= 4'd0;
            group_count <= 4'd0;
            temp_count <= 4'd0;
            valid <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize state arrays
            integer i, j;
            for (i = 0; i < 9; i = i + 1) begin
                for (j = 0; j < 10; j = j + 1) begin
                    v_state[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    h_state[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 9; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    vertical_bars[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    horizontal_bars[i][j] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    n <= n_val;
                    max_pos <= 8'd0;
                    // Calculate max position
                    max_pos <= (n * (n + 1)) + ((n + 1) * n);
                    pos <= 8'd0;
                    next_state <= SOLVE;
                end

                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= ERROR;
                    end else begin
                        if (pos < max_pos) begin
                            // Determine if current position is vertical or horizontal
                            if (pos < n * (n + 1)) begin
                                // Vertical bar
                                row_idx <= pos / (n + 1);
                                col_idx <= pos % (n + 1);
                                // Try 1 first
                                v_state[row_idx][col_idx] <= 1'b1;
                                valid <= check_constraints(row_idx, col_idx, 1'b1, 1'b0);
                                if (valid) begin
                                    pos <= pos + 8'd1;
                                end else begin
                                    v_state[row_idx][col_idx] <= 1'b0;
                                    valid <= check_constraints(row_idx, col_idx, 1'b0, 1'b0);
                                    if (valid) begin
                                        pos <= pos + 8'd1;
                                    end else begin
                                        // Backtrack
                                        pos <= pos - 8'd1;
                                    end
                                end
                            end else begin
                                // Horizontal bar
                                pos <= pos - (n * (n + 1));
                                row_idx <= pos / n;
                                col_idx <= pos % n;
                                pos <= pos + (n * (n + 1));
                                // Try 1 first
                                h_state[row_idx][col_idx] <= 1'b1;
                                valid <= check_constraints(row_idx, col_idx, 1'b0, 1'b1);
                                if (valid) begin
                                    pos <= pos + 8'd1;
                                end else begin
                                    h_state[row_idx][col_idx] <= 1'b0;
                                    valid <= check_constraints(row_idx, col_idx, 1'b0, 1'b0);
                                    if (valid) begin
                                        pos <= pos + 8'd1;
                                    end else begin
                                        // Backtrack
                                        pos <= pos - 8'd1;
                                    end
                                end
                            end
                        end else begin
                            next_state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // Verify all row and column specifications
                    valid <= 1'b1;
                    integer i, j;
                    for (i = 0; i < n; i = i + 1) begin
                        // Check row specifications
                        group_count <= 4'd0;
                        temp_count <= 4'd0;
                        for (j = 0; j < n; j = j + 1) begin
                            if (v_state[i][j]) begin
                                temp_count <= temp_count + 4'd1;
                            end else begin
                                if (temp_count > 4'd0) begin
                                    if (group_count < row_spec_len[i] && row_spec[i][group_count] == temp_count) begin
                                        group_count <= group_count + 4'd1;
                                    end else begin
                                        valid <= 1'b0;
                                    end
                                    temp_count <= 4'd0;
                                end
                            end
                        end
                        if (temp_count > 4'd0) begin
                            if (group_count < row_spec_len[i] && row_spec[i][group_count] == temp_count) begin
                                group_count <= group_count + 4'd1;
                            end else begin
                                valid <= 1'b0;
                            end
                        end
                        if (group_count != row_spec_len[i]) begin
                            valid <= 1'b0;
                        end
                    end

                    for (j = 0; j < n; j = j + 1) begin
                        // Check column specifications
                        group_count <= 4'd0;
                        temp_count <= 4'd0;
                        for (i = 0; i < n; i = i + 1) begin
                            if (h_state[i][j]) begin
                                temp_count <= temp_count + 4'd1;
                            end else begin
                                if (temp_count > 4'd0) begin
                                    if (group_count < col_spec_len[j] && col_spec[j][group_count] == temp_count) begin
                                        group_count <= group_count + 4'd1;
                                    end else begin
                                        valid <= 1'b0;
                                    end
                                    temp_count <= 4'd0;
                                end
                            end
                        end
                        if (temp_count > 4'd0) begin
                            if (group_count < col_spec_len[j] && col_spec[j][group_count] == temp_count) begin
                                group_count <= group_count + 4'd1;
                            end else begin
                                valid <= 1'b0;
                            end
                        end
                        if (group_count != col_spec_len[j]) begin
                            valid <= 1'b0;
                        end
                    end

                    if (valid) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= SOLVE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Copy internal state to outputs
                    integer i, j;
                    for (i = 0; i < 9; i = i + 1) begin
                        for (j = 0; j < 9; j = j + 1) begin
                            vertical_bars[i][j] <= v_state[i][j];
                        end
                    end
                    for (i = 0; i < 10; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            horizontal_bars[i][j] <= h_state[i][j];
                        end
                    end
                    next_state <= IDLE;
                end

                ERROR: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Constraint checking function
    function check_constraints;
        input [3:0] r, c;
        input is_vertical;
        input value;
        reg [3:0] i, j;
        reg valid;

        begin
            valid = 1'b1;

            // Check touching rule
            if (value && is_vertical) begin
                // Check adjacent horizontal bars
                if (r < n && c < n) begin
                    if (h_state[r][c] && h_state[r][c + 1] && v_state[r][c]) begin
                        valid = 1'b0;
                    end
                end
                if (r > 0 && c < n) begin
                    if (h_state[r - 1][c] && h_state[r - 1][c + 1] && v_state[r][c]) begin
                        valid = 1'b0;
                    end
                end
            end else if (value && !is_vertical) begin
                // Check adjacent vertical bars
                if (r < n && c < n) begin
                    if (v_state[r][c] && v_state[r + 1][c] && h_state[r][c]) begin
                        valid = 1'b0;
                    end
                end
                if (r < n && c > 0) begin
                    if (v_state[r][c - 1] && v_state[r + 1][c - 1] && h_state[r][c]) begin
                        valid = 1'b0;
                    end
                end
            end

            check_constraints = valid;
        end
    endfunction

endmodule