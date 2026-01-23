module magic_square_test(
    input clk,
    input rst_n,
    input start,
    input [7:0] matrix_cell_i,
    input [3:0] write_addr,
    input write_en,
    output reg result,
    output reg done
);

    localparam IDLE = 4'd0;
    localparam LOAD_MATRIX = 4'd1;
    localparam COMPUTE_ROWS = 4'd2;
    localparam COMPUTE_COLS = 4'd3;
    localparam COMPUTE_DIAG1 = 4'd4;
    localparam COMPUTE_DIAG2 = 4'd5;
    localparam CHECK_RESULT = 4'd6;
    localparam DONE = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] matrix [0:15];
    reg [9:0] sums [0:7]; 
    reg [9:0] diag_main;
    reg [9:0] diag_anti;
    
    reg [3:0] step; 
    reg [2:0] cnt;  // Row/Col index 0-3
    reg [2:0] check_idx;
    reg [9:0] temp_acc;
    reg mismatch;
    reg [3:0] load_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            load_cnt <= 0;
            mismatch <= 0;
            step <= 0;
            cnt <= 0;
            check_idx <= 0;
            temp_acc <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                    if (start) state <= LOAD_MATRIX;
                end

                LOAD_MATRIX: begin
                    if (write_en) matrix[write_addr] <= matrix_cell_i;
                    if (start) load_cnt <= load_cnt + 1;
                    if (start && load_cnt == 15) state <= COMPUTE_ROWS;
                    if (!start && load_cnt > 0) state <= COMPUTE_ROWS;
                end

                COMPUTE_ROWS: begin
                    case (step)
                        0: begin temp_acc <= 0; step <= 1; end
                        1, 2, 3, 4: begin
                            temp_acc <= temp_acc + matrix[cnt * 4 + (step - 1)];
                            step <= step + 1;
                        end
                        5: begin
                            sums[cnt] <= temp_acc;
                            cnt <= cnt + 1;
                            step <= 0;
                            if (cnt == 3) begin
                                cnt <= 0;
                                state <= COMPUTE_COLS;
                            end
                        end
                    endcase
                end

                COMPUTE_COLS: begin
                    case (step)
                        0: begin temp_acc <= 0; step <= 1; end
                        1, 2, 3, 4: begin
                            temp_acc <= temp_acc + matrix[(step - 1) * 4 + cnt];
                            step <= step + 1;
                        end
                        5: begin
                            sums[cnt + 4] <= temp_acc;
                            cnt <= cnt + 1;
                            step <= 0;
                            if (cnt == 3) begin
                                cnt <= 0;
                                state <= COMPUTE_DIAG1;
                            end
                        end
                    endcase
                end

                COMPUTE_DIAG1: begin
                    case (step)
                        0: begin temp_acc <= 0; step <= 1; end
                        1, 2, 3, 4: begin
                            temp_acc <= temp_acc + matrix[(step - 1) * 5];
                            step <= step + 1;
                        end
                        5: begin
                            diag_main <= temp_acc;
                            state <= COMPUTE_DIAG2;
                            step <= 0;
                        end
                    endcase
                end

                COMPUTE_DIAG2: begin
                    case (step)
                        0: begin temp_acc <= 0; step <= 1; end
                        1, 2, 3, 4: begin
                            temp_acc <= temp_acc + matrix[step * 3];
                            step <= step + 1;
                        end
                        5: begin
                            diag_anti <= temp_acc;
                            state <= CHECK_RESULT;
                            step <= 0;
                            check_idx <= 0;
                            mismatch <= 0;
                        end
                    endcase
                end

                CHECK_RESULT: begin
                    case (step)
                        0: begin
                            check_idx <= 0;
                            step <= 1;
                        end
                        1: begin
                            if (check_idx < 7) begin
                                if (sums[check_idx + 1] != sums[0]) mismatch <= 1;
                                check_idx <= check_idx + 1;
                            end else if (check_idx == 7) begin
                                if (diag_main != sums[0]) mismatch <= 1;
                                check_idx <= check_idx + 1;
                            end else if (check_idx == 8) begin
                                if (diag_anti != sums[0]) mismatch <= 1;
                                state <= DONE;
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                    if (!mismatch) result <= 1;
                    else result <= 0;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule