module paint_the_numbers (
    input clk, rst_n, start,
    input [6:0] n,
    input [7:0] arr_0, arr_1, arr_2, arr_3,
    input [7:0] arr_4, arr_5, arr_6, arr_7,
    input [7:0] arr_8, arr_9, arr_10, arr_11,
    input [7:0] arr_12, arr_13, arr_14, arr_15,
    output reg [7:0] color_count,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_MIN = 4'd2;
    localparam [3:0] FIND_MIN_LOOP = 4'd3;
    localparam [3:0] FOUND_MIN = 4'd4;
    localparam [3:0] SET_COLOR = 4'd5;
    localparam [3:0] MARK_LOOP = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;
    reg [15:0] colored;
    reg [3:0] k;
    reg [3:0] j;
    reg [7:0] temp_min;
    reg [3:0] temp_index;
    reg [7:0] min_val;
    reg [7:0] arr_k_val;
    reg [7:0] arr_j_val;
    reg [7:0] remainder;

    always @(*) begin
        case (k)
            4'd0: arr_k_val = arr_0;
            4'd1: arr_k_val = arr_1;
            4'd2: arr_k_val = arr_2;
            4'd3: arr_k_val = arr_3;
            4'd4: arr_k_val = arr_4;
            4'd5: arr_k_val = arr_5;
            4'd6: arr_k_val = arr_6;
            4'd7: arr_k_val = arr_7;
            4'd8: arr_k_val = arr_8;
            4'd9: arr_k_val = arr_9;
            4'd10: arr_k_val = arr_10;
            4'd11: arr_k_val = arr_11;
            4'd12: arr_k_val = arr_12;
            4'd13: arr_k_val = arr_13;
            4'd14: arr_k_val = arr_14;
            4'd15: arr_k_val = arr_15;
            default: arr_k_val = 8'd0;
        endcase

        case (j)
            4'd0: arr_j_val = arr_0;
            4'd1: arr_j_val = arr_1;
            4'd2: arr_j_val = arr_2;
            4'd3: arr_j_val = arr_3;
            4'd4: arr_j_val = arr_4;
            4'd5: arr_j_val = arr_5;
            4'd6: arr_j_val = arr_6;
            4'd7: arr_j_val = arr_7;
            4'd8: arr_j_val = arr_8;
            4'd9: arr_j_val = arr_9;
            4'd10: arr_j_val = arr_10;
            4'd11: arr_j_val = arr_11;
            4'd12: arr_j_val = arr_12;
            4'd13: arr_j_val = arr_13;
            4'd14: arr_j_val = arr_14;
            4'd15: arr_j_val = arr_15;
            default: arr_j_val = 8'd0;
        endcase

        if (min_val == 8'd0) begin
            remainder = 8'd0;
        end else begin
            remainder = arr_j_val % min_val;
        end
    end

    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT : IDLE;
            INIT:       next_state = FIND_MIN;
            FIND_MIN:   next_state = FIND_MIN_LOOP;
            FIND_MIN_LOOP: begin
                if (k >= n[3:0]) next_state = FOUND_MIN;
                else if (colored[k]) next_state = FIND_MIN_LOOP;
                else next_state = FIND_MIN_LOOP;
            end
            FOUND_MIN:  next_state = (temp_min == 8'd255) ? DONE_STATE : SET_COLOR;
            SET_COLOR:  next_state = MARK_LOOP;
            MARK_LOOP:  begin
                if (j >= n[3:0]) next_state = FIND_MIN;
                else next_state = MARK_LOOP;
            end
            DONE_STATE: next_state = DONE_STATE;
            default:    next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            color_count <= 8'd0;
            done <= 1'b0;
            colored <= 16'd0;
            k <= 4'd0;
            j <= 4'd0;
            temp_min <= 8'd255;
            temp_index <= 4'd0;
            min_val <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    colored <= 16'd0;
                end
                INIT: begin
                    colored <= 16'd0;
                    color_count <= 8'd0;
                    k <= 4'd0;
                    j <= 4'd0;
                    temp_min <= 8'd255;
                    temp_index <= 4'd0;
                end
                FIND_MIN: begin
                    k <= 4'd0;
                    temp_min <= 8'd255;
                    temp_index <= 4'd0;
                end
                FIND_MIN_LOOP: begin
                    if (k < n[3:0]) begin
                        if (!colored[k]) begin
                            if (arr_k_val < temp_min) begin
                                temp_min <= arr_k_val;
                                temp_index <= k;
                            end
                        end
                        k <= k + 4'd1;
                    end
                end
                FOUND_MIN: begin
                end
                SET_COLOR: begin
                    color_count <= color_count + 8'd1;
                    min_val <= temp_min;
                    colored[temp_index] <= 1'b1;
                    j <= 4'd0;
                end
                MARK_LOOP: begin
                    if (j < n[3:0]) begin
                        if (!colored[j] && (remainder == 8'd0)) begin
                            colored[j] <= 1'b1;
                        end
                        j <= j + 4'd1;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule