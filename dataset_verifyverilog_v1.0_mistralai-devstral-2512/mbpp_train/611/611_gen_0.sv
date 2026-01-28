module MatrixColumnMax(
    input clk,
    input rst_n,
    input start,
    input [2:0] col_idx,
    input [7:0] matrix_0_0, input [7:0] matrix_0_1, input [7:0] matrix_0_2, input [7:0] matrix_0_3,
    input [7:0] matrix_0_4, input [7:0] matrix_0_5, input [7:0] matrix_0_6, input [7:0] matrix_0_7,
    input [7:0] matrix_1_0, input [7:0] matrix_1_1, input [7:0] matrix_1_2, input [7:0] matrix_1_3,
    input [7:0] matrix_1_4, input [7:0] matrix_1_5, input [7:0] matrix_1_6, input [7:0] matrix_1_7,
    input [7:0] matrix_2_0, input [7:0] matrix_2_1, input [7:0] matrix_2_2, input [7:0] matrix_2_3,
    input [7:0] matrix_2_4, input [7:0] matrix_2_5, input [7:0] matrix_2_6, input [7:0] matrix_2_7,
    input [7:0] matrix_3_0, input [7:0] matrix_3_1, input [7:0] matrix_3_2, input [7:0] matrix_3_3,
    input [7:0] matrix_3_4, input [7:0] matrix_3_5, input [7:0] matrix_3_6, input [7:0] matrix_3_7,
    input [7:0] matrix_4_0, input [7:0] matrix_4_1, input [7:0] matrix_4_2, input [7:0] matrix_4_3,
    input [7:0] matrix_4_4, input [7:0] matrix_4_5, input [7:0] matrix_4_6, input [7:0] matrix_4_7,
    input [7:0] matrix_5_0, input [7:0] matrix_5_1, input [7:0] matrix_5_2, input [7:0] matrix_5_3,
    input [7:0] matrix_5_4, input [7:0] matrix_5_5, input [7:0] matrix_5_6, input [7:0] matrix_5_7,
    input [7:0] matrix_6_0, input [7:0] matrix_6_1, input [7:0] matrix_6_2, input [7:0] matrix_6_3,
    input [7:0] matrix_6_4, input [7:0] matrix_6_5, input [7:0] matrix_6_6, input [7:0] matrix_6_7,
    input [7:0] matrix_7_0, input [7:0] matrix_7_1, input [7:0] matrix_7_2, input [7:0] matrix_7_3,
    input [7:0] matrix_7_4, input [7:0] matrix_7_5, input [7:0] matrix_7_6, input [7:0] matrix_7_7,
    output reg [7:0] result,
    output reg done
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] row_counter;
    reg [7:0] current_max;
    reg [7:0] current_value;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            row_counter <= 3'd0;
            current_max <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        next_state <= LOAD;
                        current_max <= 8'd0;
                        row_counter <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    cycle_count <= cycle_count + 6'd1;
                    next_state <= CHECK;
                end

                CHECK: begin
                    cycle_count <= cycle_count + 6'd1;
                    case (row_counter)
                        3'd0: current_value = matrix_0_0;
                        3'd1: current_value = matrix_1_0;
                        3'd2: current_value = matrix_2_0;
                        3'd3: current_value = matrix_3_0;
                        3'd4: current_value = matrix_4_0;
                        3'd5: current_value = matrix_5_0;
                        3'd6: current_value = matrix_6_0;
                        3'd7: current_value = matrix_7_0;
                        default: current_value = 8'd0;
                    endcase

                    if (current_value > current_max) begin
                        current_max <= current_value;
                    end

                    if (row_counter == 3'd7) begin
                        next_state <= COMPLETE;
                    end else begin
                        row_counter <= row_counter + 3'd1;
                        next_state <= LOAD;
                    end
                end

                COMPLETE: begin
                    result <= current_max;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    always @(*) begin
        case (col_idx)
            3'd0: begin
                matrix_0_0 = matrix_0_0;
                matrix_1_0 = matrix_1_0;
                matrix_2_0 = matrix_2_0;
                matrix_3_0 = matrix_3_0;
                matrix_4_0 = matrix_4_0;
                matrix_5_0 = matrix_5_0;
                matrix_6_0 = matrix_6_0;
                matrix_7_0 = matrix_7_0;
            end
            3'd1: begin
                matrix_0_0 = matrix_0_1;
                matrix_1_0 = matrix_1_1;
                matrix_2_0 = matrix_2_1;
                matrix_3_0 = matrix_3_1;
                matrix_4_0 = matrix_4_1;
                matrix_5_0 = matrix_5_1;
                matrix_6_0 = matrix_6_1;
                matrix_7_0 = matrix_7_1;
            end
            3'd2: begin
                matrix_0_0 = matrix_0_2;
                matrix_1_0 = matrix_1_2;
                matrix_2_0 = matrix_2_2;
                matrix_3_0 = matrix_3_2;
                matrix_4_0 = matrix_4_2;
                matrix_5_0 = matrix_5_2;
                matrix_6_0 = matrix_6_2;
                matrix_7_0 = matrix_7_2;
            end
            3'd3: begin
                matrix_0_0 = matrix_0_3;
                matrix_1_0 = matrix_1_3;
                matrix_2_0 = matrix_2_3;
                matrix_3_0 = matrix_3_3;
                matrix_4_0 = matrix_4_3;
                matrix_5_0 = matrix_5_3;
                matrix_6_0 = matrix_6_3;
                matrix_7_0 = matrix_7_3;
            end
            3'd4: begin
                matrix_0_0 = matrix_0_4;
                matrix_1_0 = matrix_1_4;
                matrix_2_0 = matrix_2_4;
                matrix_3_0 = matrix_3_4;
                matrix_4_0 = matrix_4_4;
                matrix_5_0 = matrix_5_4;
                matrix_6_0 = matrix_6_4;
                matrix_7_0 = matrix_7_4;
            end
            3'd5: begin
                matrix_0_0 = matrix_0_5;
                matrix_1_0 = matrix_1_5;
                matrix_2_0 = matrix_2_5;
                matrix_3_0 = matrix_3_5;
                matrix_4_0 = matrix_4_5;
                matrix_5_0 = matrix_5_5;
                matrix_6_0 = matrix_6_5;
                matrix_7_0 = matrix_7_5;
            end
            3'd6: begin
                matrix_0_0 = matrix_0_6;
                matrix_1_0 = matrix_1_6;
                matrix_2_0 = matrix_2_6;
                matrix_3_0 = matrix_3_6;
                matrix_4_0 = matrix_4_6;
                matrix_5_0 = matrix_5_6;
                matrix_6_0 = matrix_6_6;
                matrix_7_0 = matrix_7_6;
            end
            3'd7: begin
                matrix_0_0 = matrix_0_7;
                matrix_1_0 = matrix_1_7;
                matrix_2_0 = matrix_2_7;
                matrix_3_0 = matrix_3_7;
                matrix_4_0 = matrix_4_7;
                matrix_5_0 = matrix_5_7;
                matrix_6_0 = matrix_6_7;
                matrix_7_0 = matrix_7_7;
            end
            default: begin
                matrix_0_0 = 8'd0;
                matrix_1_0 = 8'd0;
                matrix_2_0 = 8'd0;
                matrix_3_0 = 8'd0;
                matrix_4_0 = 8'd0;
                matrix_5_0 = 8'd0;
                matrix_6_0 = 8'd0;
                matrix_7_0 = 8'd0;
            end
        endcase
    end

endmodule