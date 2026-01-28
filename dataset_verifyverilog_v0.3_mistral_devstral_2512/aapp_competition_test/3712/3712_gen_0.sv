module student_swap(
    input clk,
    input rst_n,
    input start,
    input [3:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] CALC1 = 3'd2;
    localparam [2:0] CALC2 = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [2:0] index;
    reg [3:0] cnt0, cnt1, cnt2, cnt3, cnt4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            index <= 2'd0;
            cnt0 <= 4'd0;
            cnt1 <= 4'd0;
            cnt2 <= 4'd0;
            cnt3 <= 4'd0;
            cnt4 <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 2'd0;
                        cnt0 <= 4'd0;
                        cnt1 <= 4'd0;
                        cnt2 <= 4'd0;
                        cnt3 <= 4'd0;
                        cnt4 <= 4'd0;
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    case (index)
                        2'd0: case(arr0)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd1: case(arr1)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd2: case(arr2)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd3: case(arr3)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd4: case(arr4)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd5: case(arr5)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd6: case(arr6)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: ;
                        endcase
                        2'd7: begin
                            case(arr7)
                                4'd0: cnt0 <= cnt0 + 4'd1;
                                4'd1: cnt1 <= cnt1 + 4'd1;
                                4'd2: cnt2 <= cnt2 + 4'd1;
                                4'd3: cnt3 <= cnt3 + 4'd1;
                                4'd4: cnt4 <= cnt4 + 4'd1;
                                default: ;
                            endcase
                            state <= CALC1;
                        end
                    endcase
                    index <= index + 2'd1;
                end

                CALC1: begin
                    reg [7:0] total;
                    total = cnt1 + (cnt2 << 1) + (cnt3 * 3) + (cnt4 << 2);
                    if (total < 3 || total == 5) begin
                        result <= 16'hFFFF;
                        state <= DONE_STATE;
                    end else begin
                        state <= CALC2;
                    end
                end

                CALC2: begin
                    reg [15:0] ans;
                    reg [3:0] t1, t2, t3, groups, rem;
                    if (cnt1 >= cnt2) begin
                        ans = cnt2;
                        t1 = cnt1 - cnt2;
                        t3 = cnt3 + cnt2;
                        groups = t1 / 3;
                        ans = ans + (groups << 1);
                        t3 = t3 + groups;
                        rem = t1 % 3;
                        if (rem == 0) result <= ans;
                        else if (t3 > 0) result <= ans + rem;
                        else result <= ans + 2;
                    end else begin
                        ans = cnt1;
                        t2 = cnt2 - cnt1;
                        groups = t2 / 3;
                        ans = ans + (groups << 1);
                        rem = t2 % 3;
                        if (rem == 0) result <= ans;
                        else if (cnt4 > 0) result <= ans + rem;
                        else result <= ans + 2;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule