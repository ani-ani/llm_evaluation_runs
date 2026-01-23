module student_swap(
    input clk,
    input rst_n,
    input start,
    input [3:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7,
    output reg [15:0] result,
    output reg done
);

// State encoding with explicit width
localparam [2:0] IDLE = 3'b000;
localparam [2:0] COUNT = 3'b001;
localparam [2:0] CALC1 = 3'b010;
localparam [2:0] CALC2 = 3'b011;
localparam [2:0] DONE = 3'b100;

reg [2:0] state;
reg [2:0] index;
reg [3:0] cnt0, cnt1, cnt2, cnt3, cnt4;
reg [15:0] temp_result;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        index <= 3'd0;
        cnt0 <= 4'd0; cnt1 <= 4'd0; cnt2 <= 4'd0; cnt3 <= 4'd0; cnt4 <= 4'd0;
        temp_result <= 16'd0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                index <= 3'd0;
                cnt0 <= 4'd0; cnt1 <= 4'd0; cnt2 <= 4'd0; cnt3 <= 4'd0; cnt4 <= 4'd0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= COUNT;
                end
            end

            COUNT: begin
                cycle_count <= cycle_count + 8'd1;
                case (index)
                    3'd0: begin
                        case(arr0)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd1: begin
                        case(arr1)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd2: begin
                        case(arr2)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd3: begin
                        case(arr3)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd4: begin
                        case(arr4)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd5: begin
                        case(arr5)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd6: begin
                        case(arr6)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        index <= index + 3'd1;
                    end
                    3'd7: begin
                        case(arr7)
                            4'd0: cnt0 <= cnt0 + 4'd1;
                            4'd1: cnt1 <= cnt1 + 4'd1;
                            4'd2: cnt2 <= cnt2 + 4'd1;
                            4'd3: cnt3 <= cnt3 + 4'd1;
                            4'd4: cnt4 <= cnt4 + 4'd1;
                            default: begin end
                        endcase
                        state <= CALC1;
                    end
                    default: state <= IDLE;
                endcase
            end

            CALC1: begin
                cycle_count <= cycle_count + 8'd1;
                if (((cnt1 + (cnt2 << 1) + (cnt3 * 3) + (cnt4 << 2)) < 16'd3) || 
                    ((cnt1 + (cnt2 << 1) + (cnt3 * 3) + (cnt4 << 2)) == 16'd5)) begin
                    result <= 16'hFFFF;
                    state <= DONE;
                end else begin
                    temp_result <= 16'd0;
                    state <= CALC2;
                end
            end

            CALC2: begin
                cycle_count <= cycle_count + 8'd1;
                if (cnt1 >= cnt2) begin
                    temp_result <= {8'd0, cnt2};
                    if ((cnt1 - cnt2) >= 16'd3) begin
                        if (cnt3 + cnt2 > 0) begin
                            result <= temp_result + {8'd0, cnt2} + (({12'd0, (cnt1 - cnt2)} / 16'd3) << 1) + (cnt1 - cnt2) - {8'd0, ((cnt1 - cnt2) / 16'd3) * 16'd3};
                        end else begin
                            result <= temp_result + {8'd0, cnt2} + (({12'd0, (cnt1 - cnt2)} / 16'd3) << 1) + 16'd2;
                        end
                    end else begin
                        if (cnt3 + cnt2 > 0) begin
                            result <= temp_result + {8'd0, cnt2} + {8'd0, (cnt1 - cnt2)};
                        end else begin
                            result <= temp_result + {8'd0, cnt2} + 16'd2;
                        end
                    end
                end else begin
                    temp_result <= {8'd0, cnt1};
                    if ((cnt2 - cnt1) >= 16'd3) begin
                        if (cnt4 > 0) begin
                            result <= temp_result + {8'd0, cnt1} + (({12'd0, (cnt2 - cnt1)} / 16'd3) << 1) + (cnt2 - cnt1) - {8'd0, ((cnt2 - cnt1) / 16'd3) * 16'd3};
                        end else begin
                            result <= temp_result + {8'd0, cnt1} + (({12'd0, (cnt2 - cnt1)} / 16'd3) << 1) + 16'd2;
                        end
                    end else begin
                        if (cnt4 > 0) begin
                            result <= temp_result + {8'd0, cnt1} + {8'd0, (cnt2 - cnt1)};
                        end else begin
                            result <= temp_result + {8'd0, cnt1} + 16'd2;
                        end
                    end
                end
                state <= DONE;
            end

            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule