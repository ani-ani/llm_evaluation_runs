module grid_increment_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [15:0][7:0] grid,
    output reg valid,
    output reg [15:0] moves,
    output reg is_rows,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] SETUP_X  = 4'd1;
    localparam [3:0] COMP_COL = 4'd2;
    localparam [3:0] COMP_ROW = 4'd3;
    localparam [3:0] VERIFY   = 4'd4;
    localparam [3:0] UPDATE   = 4'd5;
    localparam [3:0] OUTPUT   = 4'd6;

    reg [3:0] state, next_state;
    reg [3:0] x_counter;  // 0 to 15
    reg [3:0] col_counter;  // 0 to m-1
    reg [3:0] row_counter;  // 0 to n-1
    reg [7:0] c [0:15];  // Column increments
    reg [7:0] r [0:15];  // Row increments
    reg [7:0] current_c;
    reg [7:0] current_r;
    reg [31:0] sum_r;
    reg [31:0] sum_c;
    reg [31:0] total_moves;
    reg [31:0] min_moves;
    reg valid_solution;
    reg [31:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_counter <= 4'd0;
            col_counter <= 4'd0;
            row_counter <= 4'd0;
            valid <= 1'b0;
            moves <= 16'd0;
            is_rows <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            min_moves <= 32'd0;
            valid_solution <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    next_state = SETUP_X;
                    x_counter = 4'd0;
                    cycle_count = 10'd0;
                end
            end

            SETUP_X: begin
                if (x_counter < 4'd16) begin
                    next_state = COMP_COL;
                    col_counter = 4'd0;
                end else begin
                    next_state = OUTPUT;
                end
            end

            COMP_COL: begin
                if (col_counter < m) begin
                    current_c = grid[0][col_counter] - x_counter;
                    if (current_c < 8'd0) begin
                        next_state = SETUP_X;
                        x_counter = x_counter + 4'd1;
                    end else begin
                        c[col_counter] = current_c;
                        col_counter = col_counter + 4'd1;
                    end
                end else begin
                    next_state = COMP_ROW;
                    row_counter = 4'd0;
                    sum_c = 32'd0;
                    for (integer i = 0; i < m; i = i + 1) begin
                        sum_c = sum_c + c[i];
                    end
                end
            end

            COMP_ROW: begin
                if (row_counter < n) begin
                    current_r = 8'd255;
                    for (integer j = 0; j < m; j = j + 1) begin
                        if (grid[row_counter][j] - c[j] < current_r) begin
                            current_r = grid[row_counter][j] - c[j];
                        end
                    end
                    if (current_r < 8'd0) begin
                        next_state = SETUP_X;
                        x_counter = x_counter + 4'd1;
                    end else begin
                        r[row_counter] = current_r;
                        row_counter = row_counter + 4'd1;
                    end
                end else begin
                    next_state = VERIFY;
                    sum_r = 32'd0;
                    for (integer i = 0; i < n; i = i + 1) begin
                        sum_r = sum_r + r[i];
                    end
                end
            end

            VERIFY: begin
                reg [7:0] temp;
                reg valid_flag = 1'b1;
                for (integer i = 0; i < n; i = i + 1) begin
                    for (integer j = 0; j < m; j = j + 1) begin
                        temp = r[i] + c[j] + x_counter;
                        if (temp != grid[i][j]) begin
                            valid_flag = 1'b0;
                        end
                    end
                end
                if (valid_flag) begin
                    next_state = UPDATE;
                    total_moves = x_counter * (n < m ? n : m) + sum_r + sum_c;
                end else begin
                    next_state = SETUP_X;
                    x_counter = x_counter + 4'd1;
                end
            end

            UPDATE: begin
                if (!valid_solution || total_moves < min_moves) begin
                    valid_solution = 1'b1;
                    min_moves = total_moves;
                    is_rows = (sum_r >= sum_c) ? 1'b1 : 1'b0;
                end
                next_state = SETUP_X;
                x_counter = x_counter + 4'd1;
            end

            OUTPUT: begin
                if (valid_solution) begin
                    valid <= 1'b1;
                    moves <= min_moves[15:0];
                end else begin
                    valid <= 1'b0;
                    moves <= 16'd0;
                end
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule