module magic_checkerboard (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] board_0, board_1, board_2, board_3,
    input wire [7:0] board_4, board_5, board_6, board_7,
    input wire [7:0] board_8, board_9, board_10, board_11,
    input wire [7:0] board_12, board_13, board_14, board_15,
    output reg [15:0] result,
    output reg done
);
    localparam NUM_CELLS = 16;
    localparam MAX_SUM = 16'hFFFF;

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP_COMBO = 4'd1;
    localparam [3:0] PROCESS_CELL = 4'd2;
    localparam [3:0] CHECK_COMBO = 4'd3;
    localparam [3:0] NEXT_COMBO = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Registers
    reg [3:0] state;
    reg [7:0] board_in [0:15];
    reg [7:0] filled_board [0:15];
    reg [3:0] cell_idx;
    reg [1:0] combo_idx;
    reg [15:0] min_sum;
    reg [15:0] sum;
    reg combo_error;
    reg [7:0] cycle_count;

    // Combinational helpers
    wire [1:0] i = cell_idx[3:2];   // row (0..3)
    wire [1:0] j = cell_idx[1:0];   // column (0..3)

    wire [7:0] left_val = (j > 0) ? filled_board[cell_idx - 1] : 8'd0;
    wire [7:0] top_val  = (i > 0) ? filled_board[cell_idx - 4] : 8'd0;

    wire [7:0] lower_bound = (j > 0 && i > 0) ? ((left_val + 1) > (top_val + 1) ? left_val + 1 : top_val + 1) :
                              (j > 0) ? (left_val + 1) :
                              (i > 0) ? (top_val + 1) : 8'd1;

    // Parity assignment bits for current combo
    wire even_parity = combo_idx[0];   // 0: color0 even, 1: color0 odd
    wire odd_parity  = combo_idx[1];   // same for odd component

    wire component = (i + j) % 2;      // 0: even i+j, 1: odd i+j
    wire row_parity = i % 2;           // 0 or 1

    wire required_parity = (component == 0) ?
                           (row_parity == 0 ? even_parity : ~even_parity) :
                           (row_parity == 0 ? odd_parity  : ~odd_parity);

    wire [7:0] new_val = (required_parity == lower_bound[0]) ? lower_bound : lower_bound + 1;
    wire val_ok = (new_val <= 8'hFF);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            cell_idx <= 4'd0;
            combo_idx <= 2'b00;
            min_sum <= MAX_SUM;
            sum <= 16'd0;
            combo_error <= 1'b0;
            cycle_count <= 8'd0;
            // Clear arrays
            for (integer idx = 0; idx < 16; idx = idx + 1) begin
                board_in[idx] <= 8'd0;
                filled_board[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input board
                        board_in[0] <= board_0;  board_in[1] <= board_1;  board_in[2] <= board_2;  board_in[3] <= board_3;
                        board_in[4] <= board_4;  board_in[5] <= board_5;  board_in[6] <= board_6;  board_in[7] <= board_7;
                        board_in[8] <= board_8;  board_in[9] <= board_9;  board_in[10] <= board_10; board_in[11] <= board_11;
                        board_in[12] <= board_12; board_in[13] <= board_13; board_in[14] <= board_14; board_in[15] <= board_15;
                        combo_idx <= 2'b00;
                        min_sum <= MAX_SUM;
                        state <= SETUP_COMBO;
                        cycle_count <= 8'd0;
                    end
                end

                SETUP_COMBO: begin
                    combo_error <= 1'b0;
                    sum <= 16'd0;
                    cell_idx <= 4'd0;
                    // Copy input to filled_board
                    for (integer idx = 0; idx < 16; idx = idx + 1) begin
                        filled_board[idx] <= board_in[idx];
                    end
                    state <= PROCESS_CELL;
                end

                PROCESS_CELL: begin
                    if (!combo_error) begin
                        if (board_in[cell_idx] != 8'd0) begin
                            // Given cell: verify constraints
                            if (board_in[cell_idx] < lower_bound) combo_error <= 1'b1;
                            else if (board_in[cell_idx][0] != required_parity) combo_error <= 1'b1;
                            else sum <= sum + board_in[cell_idx];
                        end else begin
                            // Fill zero cell
                            if (!val_ok) combo_error <= 1'b1;
                            else begin
                                filled_board[cell_idx] <= new_val;
                                sum <= sum + new_val;
                            end
                        end
                    end
                    if (cell_idx < 15) cell_idx <= cell_idx + 1;
                    else state <= CHECK_COMBO;
                end

                CHECK_COMBO: begin
                    if (!combo_error && sum < min_sum) min_sum <= sum;
                    state <= NEXT_COMBO;
                end

                NEXT_COMBO: begin
                    combo_idx <= combo_idx + 1;
                    if (combo_idx < 3) state <= SETUP_COMBO;
                    else state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= (min_sum == MAX_SUM) ? 16'hFFFF : min_sum;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule