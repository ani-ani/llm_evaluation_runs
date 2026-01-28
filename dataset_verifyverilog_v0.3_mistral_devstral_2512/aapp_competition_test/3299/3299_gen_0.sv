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
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP_COMBO = 3'd1;
    localparam [2:0] PROCESS_CELL = 3'd2;
    localparam [2:0] CHECK_COMBO = 3'd3;
    localparam [2:0] NEXT_COMBO = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state;
    reg [7:0] board_in [0:15];
    reg [7:0] filled_board [0:15];
    reg [3:0] cell_idx;
    reg [1:0] combo_idx;
    reg [15:0] min_sum;
    reg [15:0] sum;
    reg combo_error;
    
    wire [3:0] i = cell_idx[3:2];
    wire [3:0] j = cell_idx[1:0];
    
    wire [7:0] left_val = (j > 0) ? filled_board[cell_idx - 1] : 8'd0;
    wire [7:0] top_val = (i > 0) ? filled_board[cell_idx - 4] : 8'd0;
    
    wire [7:0] lower_bound = (j > 0 && i > 0) ? ((left_val + 1) > (top_val + 1) ? left_val + 1 : top_val + 1) :
                              (j > 0) ? (left_val + 1) :
                              (i > 0) ? (top_val + 1) : 8'd1;
    
    wire even_parity = combo_idx[0];
    wire odd_parity = combo_idx[1];
    
    wire component = (i + j) % 2;
    wire row_parity = i % 2;
    
    wire required_parity = (component == 0) ?
                           (row_parity == 0 ? even_parity : ~even_parity) :
                           (row_parity == 0 ? odd_parity : ~odd_parity);
    
    wire [7:0] new_val = (required_parity == lower_bound[0]) ? lower_bound : lower_bound + 1;
    wire val_ok = (new_val <= 8'hFF);
    
    integer idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            cell_idx <= 4'd0;
            combo_idx <= 2'd0;
            min_sum <= 16'd65535;
            sum <= 16'd0;
            combo_error <= 1'b0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                board_in[idx] <= 8'd0;
                filled_board[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        board_in[0] <= board_0;
                        board_in[1] <= board_1;
                        board_in[2] <= board_2;
                        board_in[3] <= board_3;
                        board_in[4] <= board_4;
                        board_in[5] <= board_5;
                        board_in[6] <= board_6;
                        board_in[7] <= board_7;
                        board_in[8] <= board_8;
                        board_in[9] <= board_9;
                        board_in[10] <= board_10;
                        board_in[11] <= board_11;
                        board_in[12] <= board_12;
                        board_in[13] <= board_13;
                        board_in[14] <= board_14;
                        board_in[15] <= board_15;
                        combo_idx <= 2'd0;
                        min_sum <= 16'd65535;
                        state <= SETUP_COMBO;
                    end
                end
                
                SETUP_COMBO: begin
                    combo_error <= 1'b0;
                    sum <= 16'd0;
                    cell_idx <= 4'd0;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        filled_board[idx] <= board_in[idx];
                    end
                    state <= PROCESS_CELL;
                end
                
                PROCESS_CELL: begin
                    if (!combo_error) begin
                        if (board_in[cell_idx] != 8'd0) begin
                            if (board_in[cell_idx] < lower_bound || board_in[cell_idx][0] != required_parity) begin
                                combo_error <= 1'b1;
                            end else begin
                                sum <= sum + board_in[cell_idx];
                            end
                        end else begin
                            if (!val_ok) begin
                                combo_error <= 1'b1;
                            end else begin
                                filled_board[cell_idx] <= new_val;
                                sum <= sum + new_val;
                            end
                        end
                    end
                    if (cell_idx < 15) begin
                        cell_idx <= cell_idx + 4'd1;
                    end else begin
                        state <= CHECK_COMBO;
                    end
                end
                
                CHECK_COMBO: begin
                    if (!combo_error && sum < min_sum) begin
                        min_sum <= sum;
                    end
                    state <= NEXT_COMBO;
                end
                
                NEXT_COMBO: begin
                    combo_idx <= combo_idx + 2'd1;
                    if (combo_idx < 2'd3) begin
                        state <= SETUP_COMBO;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= (min_sum == 16'd65535) ? 16'd65535 : min_sum;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule