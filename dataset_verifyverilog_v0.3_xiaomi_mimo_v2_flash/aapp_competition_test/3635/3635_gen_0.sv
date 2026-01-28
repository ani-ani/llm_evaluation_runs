module max_executables (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] N,
    output reg [7:0] result,
    output reg done
);

    parameter DATA_WIDTH = 8;
    parameter SUM_WIDTH = 32;
    parameter INDEX_WIDTH = 4;
    parameter RESULT_WIDTH = 8;

    // State definitions
    localparam [4:0] S_IDLE = 5'd0;
    localparam [4:0] S_COMPUTE_PREFIX = 5'd1;
    localparam [4:0] S_SET_BEST0 = 5'd2;
    localparam [4:0] S_INIT_I = 5'd3;
    localparam [4:0] S_LOOP_J_START = 5'd4;
    localparam [4:0] S_COMPUTE_S = 5'd5;
    localparam [4:0] S_COMPARE = 5'd6;
    localparam [4:0] S_UPDATE = 5'd7;
    localparam [4:0] S_NEXT_J = 5'd8;
    localparam [4:0] S_NEXT_I = 5'd9;
    localparam [4:0] S_DONE = 5'd10;

    reg [4:0] state, next_state;

    // Arrays (unpacked)
    reg [SUM_WIDTH-1:0] prefix_0;
    reg [SUM_WIDTH-1:0] prefix_1;
    reg [SUM_WIDTH-1:0] prefix_2;
    reg [SUM_WIDTH-1:0] prefix_3;
    reg [SUM_WIDTH-1:0] prefix_4;
    reg [SUM_WIDTH-1:0] prefix_5;
    reg [SUM_WIDTH-1:0] prefix_6;
    reg [SUM_WIDTH-1:0] prefix_7;
    reg [SUM_WIDTH-1:0] prefix_8;

    reg [RESULT_WIDTH-1:0] best_0;
    reg [RESULT_WIDTH-1:0] best_1;
    reg [RESULT_WIDTH-1:0] best_2;
    reg [RESULT_WIDTH-1:0] best_3;
    reg [RESULT_WIDTH-1:0] best_4;
    reg [RESULT_WIDTH-1:0] best_5;
    reg [RESULT_WIDTH-1:0] best_6;
    reg [RESULT_WIDTH-1:0] best_7;

    reg [SUM_WIDTH-1:0] sum_0;
    reg [SUM_WIDTH-1:0] sum_1;
    reg [SUM_WIDTH-1:0] sum_2;
    reg [SUM_WIDTH-1:0] sum_3;
    reg [SUM_WIDTH-1:0] sum_4;
    reg [SUM_WIDTH-1:0] sum_5;
    reg [SUM_WIDTH-1:0] sum_6;
    reg [SUM_WIDTH-1:0] sum_7;

    // Temporary registers
    reg [INDEX_WIDTH-1:0] i_idx;
    reg [INDEX_WIDTH-1:0] j_idx;
    reg [SUM_WIDTH-1:0] temp_s;
    reg [RESULT_WIDTH-1:0] candidate;
    reg [SUM_WIDTH-1:0] temp_sum_reg;
    reg [RESULT_WIDTH-1:0] temp_best_reg;
    reg [INDEX_WIDTH-1:0] prefix_idx;
    reg [INDEX_WIDTH-1:0] reset_counter;

    // Helper function to get arr value by index
    function [DATA_WIDTH-1:0] get_arr;
        input [INDEX_WIDTH-1:0] idx;
        begin
            case (idx)
                4'd0: get_arr = arr_0;
                4'd1: get_arr = arr_1;
                4'd2: get_arr = arr_2;
                4'd3: get_arr = arr_3;
                4'd4: get_arr = arr_4;
                4'd5: get_arr = arr_5;
                4'd6: get_arr = arr_6;
                4'd7: get_arr = arr_7;
                default: get_arr = 8'd0;
            endcase
        end
    endfunction

    // Helper function to read from prefix array
    function [SUM_WIDTH-1:0] get_prefix;
        input [INDEX_WIDTH-1:0] idx;
        begin
            case (idx)
                4'd0: get_prefix = prefix_0;
                4'd1: get_prefix = prefix_1;
                4'd2: get_prefix = prefix_2;
                4'd3: get_prefix = prefix_3;
                4'd4: get_prefix = prefix_4;
                4'd5: get_prefix = prefix_5;
                4'd6: get_prefix = prefix_6;
                4'd7: get_prefix = prefix_7;
                4'd8: get_prefix = prefix_8;
                default: get_prefix = 32'd0;
            endcase
        end
    endfunction

    // Helper function to read from best array
    function [RESULT_WIDTH-1:0] get_best;
        input [INDEX_WIDTH-1:0] idx;
        begin
            case (idx)
                4'd0: get_best = best_0;
                4'd1: get_best = best_1;
                4'd2: get_best = best_2;
                4'd3: get_best = best_3;
                4'd4: get_best = best_4;
                4'd5: get_best = best_5;
                4'd6: get_best = best_6;
                4'd7: get_best = best_7;
                default: get_best = 8'd0;
            endcase
        end
    endfunction

    // Helper function to read from sum array
    function [SUM_WIDTH-1:0] get_sum;
        input [INDEX_WIDTH-1:0] idx;
        begin
            case (idx)
                4'd0: get_sum = sum_0;
                4'd1: get_sum = sum_1;
                4'd2: get_sum = sum_2;
                4'd3: get_sum = sum_3;
                4'd4: get_sum = sum_4;
                4'd5: get_sum = sum_5;
                4'd6: get_sum = sum_6;
                4'd7: get_sum = sum_7;
                default: get_sum = 32'd0;
            endcase
        end
    endfunction

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_COMPUTE_PREFIX;
            end
            S_COMPUTE_PREFIX: begin
                if (prefix_idx > N)
                    next_state = S_SET_BEST0;
            end
            S_SET_BEST0: begin
                next_state = S_INIT_I;
            end
            S_INIT_I: begin
                next_state = S_LOOP_J_START;
            end
            S_LOOP_J_START: begin
                next_state = S_COMPUTE_S;
            end
            S_COMPUTE_S: begin
                next_state = S_COMPARE;
            end
            S_COMPARE: begin
                if (temp_s >= get_sum(j_idx))
                    next_state = S_UPDATE;
                else
                    next_state = S_NEXT_J;
            end
            S_UPDATE: begin
                next_state = S_NEXT_J;
            end
            S_NEXT_J: begin
                if (j_idx < i_idx)
                    next_state = S_LOOP_J_START;
                else
                    next_state = S_NEXT_I;
            end
            S_NEXT_I: begin
                if (i_idx < N-1)
                    next_state = S_INIT_I;
                else
                    next_state = S_DONE;
            end
            S_DONE: begin
                if (!start)
                    next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers and arrays
            prefix_idx <= 0;
            i_idx <= 0;
            j_idx <= 0;
            temp_s <= 32'd0;
            candidate <= 8'd0;
            temp_sum_reg <= 32'd0;
            temp_best_reg <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            reset_counter <= 0;
            
            // Initialize arrays to zero
            prefix_0 <= 32'd0;
            prefix_1 <= 32'd0;
            prefix_2 <= 32'd0;
            prefix_3 <= 32'd0;
            prefix_4 <= 32'd0;
            prefix_5 <= 32'd0;
            prefix_6 <= 32'd0;
            prefix_7 <= 32'd0;
            prefix_8 <= 32'd0;
            
            best_0 <= 8'd0;
            best_1 <= 8'd0;
            best_2 <= 8'd0;
            best_3 <= 8'd0;
            best_4 <= 8'd0;
            best_5 <= 8'd0;
            best_6 <= 8'd0;
            best_7 <= 8'd0;
            
            sum_0 <= 32'd0;
            sum_1 <= 32'd0;
            sum_2 <= 32'd0;
            sum_3 <= 32'd0;
            sum_4 <= 32'd0;
            sum_5 <= 32'd0;
            sum_6 <= 32'd0;
            sum_7 <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        prefix_idx <= 4'd1;
                        prefix_0 <= 32'd0;
                    end
                end

                S_COMPUTE_PREFIX: begin
                    if (prefix_idx <= N) begin
                        // Calculate prefix[prefix_idx] = prefix[prefix_idx-1] + arr[prefix_idx-1]
                        case (prefix_idx)
                            4'd1: prefix_1 <= prefix_0 + get_arr(4'd0);
                            4'd2: prefix_2 <= prefix_1 + get_arr(4'd1);
                            4'd3: prefix_3 <= prefix_2 + get_arr(4'd2);
                            4'd4: prefix_4 <= prefix_3 + get_arr(4'd3);
                            4'd5: prefix_5 <= prefix_4 + get_arr(4'd4);
                            4'd6: prefix_6 <= prefix_5 + get_arr(4'd5);
                            4'd7: prefix_7 <= prefix_6 + get_arr(4'd6);
                            4'd8: prefix_8 <= prefix_7 + get_arr(4'd7);
                        endcase
                        prefix_idx <= prefix_idx + 4'd1;
                    end
                end

                S_SET_BEST0: begin
                    best_0 <= 8'd1;
                    sum_0 <= prefix_1;
                    i_idx <= 4'd1;
                end

                S_INIT_I: begin
                    temp_best_reg <= 8'd1;
                    temp_sum_reg <= get_prefix(i_idx + 4'd1);
                    j_idx <= 4'd0;
                end

                S_LOOP_J_START: begin
                    // No operation needed here
                end

                S_COMPUTE_S: begin
                    temp_s <= get_prefix(i_idx + 4'd1) - get_prefix(j_idx + 4'd1);
                end

                S_COMPARE: begin
                    // Comparison logic in next_state decides branch
                end

                S_UPDATE: begin
                    candidate <= get_best(j_idx) + 8'd1;
                    if (get_best(j_idx) + 8'd1 > temp_best_reg) begin
                        temp_best_reg <= get_best(j_idx) + 8'd1;
                        temp_sum_reg <= temp_s;
                    end else if (get_best(j_idx) + 8'd1 == temp_best_reg && temp_s < temp_sum_reg) begin
                        temp_sum_reg <= temp_s;
                    end
                end

                S_NEXT_J: begin
                    j_idx <= j_idx + 4'd1;
                end

                S_NEXT_I: begin
                    // Store best[i_idx] and sum[i_idx]
                    case (i_idx)
                        4'd1: begin best_1 <= temp_best_reg; sum_1 <= temp_sum_reg; end
                        4'd2: begin best_2 <= temp_best_reg; sum_2 <= temp_sum_reg; end
                        4'd3: begin best_3 <= temp_best_reg; sum_3 <= temp_sum_reg; end
                        4'd4: begin best_4 <= temp_best_reg; sum_4 <= temp_sum_reg; end
                        4'd5: begin best_5 <= temp_best_reg; sum_5 <= temp_sum_reg; end
                        4'd6: begin best_6 <= temp_best_reg; sum_6 <= temp_sum_reg; end
                        4'd7: begin best_7 <= temp_best_reg; sum_7 <= temp_sum_reg; end
                    endcase
                    i_idx <= i_idx + 4'd1;
                end

                S_DONE: begin
                    // Store final result
                    case (N-4'd1)
                        4'd0: result <= best_0;
                        4'd1: result <= best_1;
                        4'd2: result <= best_2;
                        4'd3: result <= best_3;
                        4'd4: result <= best_4;
                        4'd5: result <= best_5;
                        4'd6: result <= best_6;
                        4'd7: result <= best_7;
                        default: result <= 8'd0;
                    endcase
                    done <= 1'b1;
                end

                default: begin
                    // No operation
                end
            endcase
        end
    end

endmodule