module CheckEvenArray (
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
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] arr_10,
    input wire [7:0] arr_11,
    input wire [7:0] arr_12,
    input wire [7:0] arr_13,
    input wire [7:0] arr_14,
    input wire [7:0] arr_15,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_0_1  = 3'd1;
    localparam [2:0] CHECK_2_3  = 3'd2;
    localparam [2:0] CHECK_4_5  = 3'd3;
    localparam [2:0] CHECK_6_7  = 3'd4;
    localparam [2:0] CHECK_8_9  = 3'd5;
    localparam [2:0] CHECK_10_11 = 3'd6;
    localparam [2:0] CHECK_12_13 = 3'd7;
    localparam [2:0] CHECK_14_15 = 3'd8;
    localparam [2:0] FINISH     = 3'd9;

    reg [2:0] state, next_state;
    reg current_result;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Check conditions for each pair
    wire check_0_1_pass;
    wire check_2_3_pass;
    wire check_4_5_pass;
    wire check_6_7_pass;
    wire check_8_9_pass;
    wire check_10_11_pass;
    wire check_12_13_pass;
    wire check_14_15_pass;

    // Check each pair (even index must be even, odd index must be odd)
    assign check_0_1_pass  = (arr_0[0] == 1'b0) && (arr_1[0] == 1'b1);
    assign check_2_3_pass  = (arr_2[0] == 1'b0) && (arr_3[0] == 1'b1);
    assign check_4_5_pass  = (arr_4[0] == 1'b0) && (arr_5[0] == 1'b1);
    assign check_6_7_pass  = (arr_6[0] == 1'b0) && (arr_7[0] == 1'b1);
    assign check_8_9_pass  = (arr_8[0] == 1'b0) && (arr_9[0] == 1'b1);
    assign check_10_11_pass = (arr_10[0] == 1'b0) && (arr_11[0] == 1'b1);
    assign check_12_13_pass = (arr_12[0] == 1'b0) && (arr_13[0] == 1'b1);
    assign check_14_15_pass = (arr_14[0] == 1'b0) && (arr_15[0] == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            temp_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    temp_result <= 16'd0;
                    if (start) begin
                        state <= CHECK_0_1;
                        temp_result[0] <= check_0_1_pass;
                    end
                end

                CHECK_0_1: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[0] <= check_0_1_pass;
                    if (check_0_1_pass) begin
                        state <= CHECK_2_3;
                        temp_result[1] <= check_2_3_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_2_3: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[1] <= check_2_3_pass;
                    if (check_2_3_pass) begin
                        state <= CHECK_4_5;
                        temp_result[2] <= check_4_5_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_4_5: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[2] <= check_4_5_pass;
                    if (check_4_5_pass) begin
                        state <= CHECK_6_7;
                        temp_result[3] <= check_6_7_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_6_7: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[3] <= check_6_7_pass;
                    if (check_6_7_pass) begin
                        state <= CHECK_8_9;
                        temp_result[4] <= check_8_9_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_8_9: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[4] <= check_8_9_pass;
                    if (check_8_9_pass) begin
                        state <= CHECK_10_11;
                        temp_result[5] <= check_10_11_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_10_11: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[5] <= check_10_11_pass;
                    if (check_10_11_pass) begin
                        state <= CHECK_12_13;
                        temp_result[6] <= check_12_13_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_12_13: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[6] <= check_12_13_pass;
                    if (check_12_13_pass) begin
                        state <= CHECK_14_15;
                        temp_result[7] <= check_14_15_pass;
                    end else begin
                        state <= FINISH;
                        result <= 1'b0;
                    end
                end

                CHECK_14_15: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_result[7] <= check_14_15_pass;
                    if (check_14_15_pass) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule