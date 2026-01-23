module steward_support (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [3:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FIND_MIN_MAX = 2'd1;
    localparam [1:0] COUNT_SUPPORT = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    reg [2:0] idx;
    reg [7:0] min_val;
    reg [7:0] max_val;
    reg [3:0] count;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            idx <= 3'd0;
            min_val <= 8'd0;
            max_val <= 8'd0;
            count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n < 3'd2) begin
                            result <= 4'd0;
                            done <= 1'b1;
                            state <= FINISHED;
                        end else begin
                            idx <= 3'd1;
                            case (n)
                                3'd2: begin
                                    min_val <= (arr_0 < arr_1) ? arr_0 : arr_1;
                                    max_val <= (arr_0 > arr_1) ? arr_0 : arr_1;
                                end
                                3'd3: begin
                                    min_val <= (((arr_0 < arr_1) && (arr_0 < arr_2)) || ((arr_0 < arr_1) && (arr_0 >= arr_2)) || ((arr_0 >= arr_1) && (arr_0 < arr_2))) ? arr_0 : ((arr_1 < arr_2) ? arr_1 : arr_2);
                                    max_val <= (((arr_0 > arr_1) && (arr_0 > arr_2)) || ((arr_0 > arr_1) && (arr_0 <= arr_2)) || ((arr_0 <= arr_1) && (arr_0 > arr_2))) ? arr_0 : ((arr_1 > arr_2) ? arr_1 : arr_2);
                                end
                                default: begin
                                    min_val <= arr_0;
                                    max_val <= arr_0;
                                end
                            endcase
                            state <= FIND_MIN_MAX;
                        end
                    end
                end

                FIND_MIN_MAX: begin
                    if (idx < n) begin
                        case (idx)
                            3'd1: begin
                                if (arr_1 < min_val) min_val <= arr_1;
                                if (arr_1 > max_val) max_val <= arr_1;
                            end
                            3'd2: begin
                                if (arr_2 < min_val) min_val <= arr_2;
                                if (arr_2 > max_val) max_val <= arr_2;
                            end
                            3'd3: begin
                                if (arr_3 < min_val) min_val <= arr_3;
                                if (arr_3 > max_val) max_val <= arr_3;
                            end
                            3'd4: begin
                                if (arr_4 < min_val) min_val <= arr_4;
                                if (arr_4 > max_val) max_val <= arr_4;
                            end
                            3'd5: begin
                                if (arr_5 < min_val) min_val <= arr_5;
                                if (arr_5 > max_val) max_val <= arr_5;
                            end
                            3'd6: begin
                                if (arr_6 < min_val) min_val <= arr_6;
                                if (arr_6 > max_val) max_val <= arr_6;
                            end
                            3'd7: begin
                                if (arr_7 < min_val) min_val <= arr_7;
                                if (arr_7 > max_val) max_val <= arr_7;
                            end
                        endcase
                        idx <= idx + 1'b1;
                    end else begin
                        if (min_val == max_val) begin
                            result <= 4'd0;
                            done <= 1'b1;
                            state <= FINISHED;
                        end else begin
                            idx <= 3'd0;
                            count <= 4'd0;
                            state <= COUNT_SUPPORT;
                        end
                    end
                end

                COUNT_SUPPORT: begin
                    if (idx < n) begin
                        case (idx)
                            3'd0: if (arr_0 > min_val && arr_0 < max_val) count <= count + 1'b1;
                            3'd1: if (arr_1 > min_val && arr_1 < max_val) count <= count + 1'b1;
                            3'd2: if (arr_2 > min_val && arr_2 < max_val) count <= count + 1'b1;
                            3'd3: if (arr_3 > min_val && arr_3 < max_val) count <= count + 1'b1;
                            3'd4: if (arr_4 > min_val && arr_4 < max_val) count <= count + 1'b1;
                            3'd5: if (arr_5 > min_val && arr_5 < max_val) count <= count + 1'b1;
                            3'd6: if (arr_6 > min_val && arr_6 < max_val) count <= count + 1'b1;
                            3'd7: if (arr_7 > min_val && arr_7 < max_val) count <= count + 1'b1;
                        endcase
                        idx <= idx + 1'b1;
                    end else begin
                        result <= count;
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule