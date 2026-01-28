module chess_kings_spread(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] board_packed,
    output reg [31:0] mirko_spread,
    output reg [31:0] slavko_spread,
    output reg done
);

    // Constants
    localparam [2:0] MAX_ROWS = 3'd8;
    localparam [2:0] MAX_COLS = 3'd8;
    localparam [3:0] MAX_PIECES = 4'd16;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] COMPUTE_M = 3'd2;
    localparam [2:0] CALC_DIST_M = 3'd3;
    localparam [2:0] COMPUTE_S = 3'd4;
    localparam [2:0] CALC_DIST_S = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // State register
    reg [2:0] state, next_state;

    // Scan counters
    reg [2:0] row_idx;
    reg [2:0] col_idx;

    // Piece counters
    reg [3:0] M_count;
    reg [3:0] S_count;

    // Piece positions
    reg [2:0] M_x [0:15];
    reg [2:0] M_y [0:15];
    reg [2:0] S_x [0:15];
    reg [2:0] S_y [0:15];

    // Distance calculation counters
    reg [3:0] i_idx;
    reg [3:0] j_idx;

    // Distance calculation registers
    reg [2:0] dx;
    reg [2:0] dy;
    reg [2:0] dist;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            M_count <= 4'd0;
            S_count <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            mirko_spread <= 32'd0;
            slavko_spread <= 32'd0;
            done <= 1'b0;

            // Initialize arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                M_x[k] <= 3'd0;
                M_y[k] <= 3'd0;
                S_x[k] <= 3'd0;
                S_y[k] <= 3'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state = SCAN;
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                        M_count <= 4'd0;
                        S_count <= 4'd0;
                    end else begin
                        next_state = IDLE;
                    end
                end

                SCAN: begin
                    // Read current cell
                    reg [1:0] cell_value;
                    integer cell_index;
                    cell_index = (row_idx * 8 + col_idx) * 2 + 1;
                    cell_value = board_packed[cell_index:cell_index-1];

                    // Store piece positions
                    if (cell_value == 2'b01 && M_count < MAX_PIECES) begin
                        M_x[M_count] <= row_idx;
                        M_y[M_count] <= col_idx;
                        M_count <= M_count + 4'd1;
                    end else if (cell_value == 2'b10 && S_count < MAX_PIECES) begin
                        S_x[S_count] <= row_idx;
                        S_y[S_count] <= col_idx;
                        S_count <= S_count + 4'd1;
                    end

                    // Move to next cell
                    if (col_idx == MAX_COLS - 1) begin
                        col_idx <= 3'd0;
                        if (row_idx == MAX_ROWS - 1) begin
                            next_state = COMPUTE_M;
                        end else begin
                            row_idx <= row_idx + 3'd1;
                        end
                    end else begin
                        col_idx <= col_idx + 3'd1;
                    end
                end

                COMPUTE_M: begin
                    if (M_count <= 1) begin
                        mirko_spread <= 32'd0;
                        next_state = COMPUTE_S;
                    end else begin
                        i_idx <= 4'd0;
                        j_idx <= 4'd1;
                        mirko_spread <= 32'd0;
                        next_state = CALC_DIST_M;
                    end
                end

                CALC_DIST_M: begin
                    // Calculate distance
                    dx <= (M_x[i_idx] > M_x[j_idx]) ? (M_x[i_idx] - M_x[j_idx]) : (M_x[j_idx] - M_x[i_idx]);
                    dy <= (M_y[i_idx] > M_y[j_idx]) ? (M_y[i_idx] - M_y[j_idx]) : (M_y[j_idx] - M_y[i_idx]);
                    dist <= (dx > dy) ? dx : dy;
                    mirko_spread <= mirko_spread + dist;

                    // Move to next pair
                    if (j_idx == M_count - 1) begin
                        i_idx <= i_idx + 4'd1;
                        if (i_idx == M_count - 1) begin
                            next_state = COMPUTE_S;
                        end else begin
                            j_idx <= i_idx + 4'd1;
                        end
                    end else begin
                        j_idx <= j_idx + 4'd1;
                    end
                end

                COMPUTE_S: begin
                    if (S_count <= 1) begin
                        slavko_spread <= 32'd0;
                        next_state = DONE_STATE;
                    end else begin
                        i_idx <= 4'd0;
                        j_idx <= 4'd1;
                        slavko_spread <= 32'd0;
                        next_state = CALC_DIST_S;
                    end
                end

                CALC_DIST_S: begin
                    // Calculate distance
                    dx <= (S_x[i_idx] > S_x[j_idx]) ? (S_x[i_idx] - S_x[j_idx]) : (S_x[j_idx] - S_x[i_idx]);
                    dy <= (S_y[i_idx] > S_y[j_idx]) ? (S_y[i_idx] - S_y[j_idx]) : (S_y[j_idx] - S_y[i_idx]);
                    dist <= (dx > dy) ? dx : dy;
                    slavko_spread <= slavko_spread + dist;

                    // Move to next pair
                    if (j_idx == S_count - 1) begin
                        i_idx <= i_idx + 4'd1;
                        if (i_idx == S_count - 1) begin
                            next_state = DONE_STATE;
                        end else begin
                            j_idx <= i_idx + 4'd1;
                        end
                    end else begin
                        j_idx <= j_idx + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

endmodule