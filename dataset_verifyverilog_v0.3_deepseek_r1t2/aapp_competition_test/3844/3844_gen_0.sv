module game_outcome #(
    parameter N = 16,      // Maximum array size
    parameter W = 8         // Bit width for values
)(
    input clk,
    input rst_n,
    input start,
    input [W-1:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [W-1:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    input [4:0] len,
    output reg result,
    output reg done
);

    // State encoding
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] LOAD         = 4'd1;
    localparam [3:0] SORT_INIT    = 4'd2;
    localparam [3:0] SORT_COMPARE = 4'd3;
    localparam [3:0] SORT_NEXT_J  = 4'd4;
    localparam [3:0] SORT_NEXT_I  = 4'd5;
    localparam [3:0] SCAN_INIT    = 4'd6;
    localparam [3:0] SCAN_LOOP    = 4'd7;
    localparam [3:0] SCAN_CHECK   = 4'd8;
    localparam [3:0] DONE_STATE   = 4'd9;

    // Registers
    reg [3:0] state, next_state;
    reg [W-1:0] array_reg [0:N-1];
    reg [4:0] i, j;
    reg [W-1:0] prev_val;
    reg [3:0] run_len;
    reg found_odd;
    reg [4:0] load_idx;
    reg [4:0] scan_idx;
    reg start_dly;
    integer k;

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start_dly ? LOAD : IDLE;
            LOAD:       next_state = (load_idx < len) ? LOAD : (len > 1 ? SORT_INIT : SCAN_INIT);
            SORT_INIT:  next_state = SORT_COMPARE;
            SORT_COMPARE: next_state = SORT_NEXT_J;
            SORT_NEXT_J: begin
                if (j < len - 5'd1 - i)
                    next_state = SORT_COMPARE;
                else if (i < len - 5'd2)
                    next_state = SORT_NEXT_I;
                else
                    next_state = SCAN_INIT;
            end
            SORT_NEXT_I: next_state = SORT_COMPARE;
            SCAN_INIT:   next_state = SCAN_LOOP;
            SCAN_LOOP:   next_state = (scan_idx < len) ? SCAN_LOOP : SCAN_CHECK;
            SCAN_CHECK:  next_state = DONE_STATE;
            DONE_STATE:  next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            i <= 5'd0;
            j <= 5'd0;
            load_idx <= 5'd0;
            scan_idx <= 5'd0;
            run_len <= 4'd1;
            found_odd <= 1'b0;
            start_dly <= 1'b0;
            for (k = 0; k < N; k = k + 1) begin
                array_reg[k] <= {W{1'b0}};
            end
        end else begin
            state <= next_state;
            start_dly <= start;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_dly) begin
                        load_idx <= 5'd0;
                    end
                end

                LOAD: begin
                    if (load_idx < len) begin
                        case (load_idx)
                            5'd0:  array_reg[0] <= arr_0;
                            5'd1:  array_reg[1] <= arr_1;
                            5'd2:  array_reg[2] <= arr_2;
                            5'd3:  array_reg[3] <= arr_3;
                            5'd4:  array_reg[4] <= arr_4;
                            5'd5:  array_reg[5] <= arr_5;
                            5'd6:  array_reg[6] <= arr_6;
                            5'd7:  array_reg[7] <= arr_7;
                            5'd8:  array_reg[8] <= arr_8;
                            5'd9:  array_reg[9] <= arr_9;
                            5'd10: array_reg[10] <= arr_10;
                            5'd11: array_reg[11] <= arr_11;
                            5'd12: array_reg[12] <= arr_12;
                            5'd13: array_reg[13] <= arr_13;
                            5'd14: array_reg[14] <= arr_14;
                            5'd15: array_reg[15] <= arr_15;
                        endcase
                        load_idx <= load_idx + 5'd1;
                    end
                end

                SORT_INIT: begin
                    i <= 5'd0;
                    j <= 5'd0;
                end

                SORT_COMPARE: begin
                    if (array_reg[j] > array_reg[j + 5'd1]) begin
                        array_reg[j] <= array_reg[j + 5'd1];
                        array_reg[j + 5'd1] <= array_reg[j];
                    end
                end

                SORT_NEXT_J: begin
                    j <= j + 5'd1;
                    if (j >= len - 5'd1 - i && i < len - 5'd2) begin
                        j <= 5'd0;
                        i <= i + 5'd1;
                    end
                end

                SCAN_INIT: begin
                    prev_val <= array_reg[0];
                    run_len <= 4'd1;
                    found_odd <= 1'b0;
                    scan_idx <= 5'd1;
                end

                SCAN_LOOP: begin
                    if (array_reg[scan_idx] == prev_val) begin
                        run_len <= run_len + 4'd1;
                    end else begin
                        if (run_len[0]) found_odd <= 1'b1;
                        prev_val <= array_reg[scan_idx];
                        run_len <= 4'd1;
                    end
                    scan_idx <= scan_idx + 5'd1;
                end

                SCAN_CHECK: begin
                    if (run_len[0]) found_odd <= 1'b1;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= found_odd;
                end
            endcase
        end
    end
endmodule