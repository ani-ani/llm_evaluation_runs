module traffic_light_time (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] t_0, t_1, t_2, t_3, t_4, t_5, t_6, t_7, t_8, t_9, t_10, t_11, t_12, t_13, t_14,
    input wire [7:0] g_0, g_1, g_2, g_3, g_4, g_5, g_6, g_7, g_8, g_9, g_10, g_11, g_12, g_13, g_14,
    input wire [7:0] r_0, r_1, r_2, r_3, r_4, r_5, r_6, r_7, r_8, r_9, r_10, r_11, r_12, r_13, r_14,
    output reg [31:0] total_time,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_LIGHT = 3'd1;
    localparam [2:0] COMPUTE_SEG = 3'd2;
    localparam [2:0] CHECK_GREEN = 3'd3;
    localparam [2:0] WAIT_GREEN = 3'd4;
    localparam [2:0] NEXT_LIGHT = 3'd5;
    localparam [2:0] FINAL_SEG = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state;
    reg [3:0] light_idx;
    reg [31:0] current_time;
    reg [31:0] current_velocity;
    reg [31:0] seg_time;
    reg [31:0] arrival_time;
    reg [31:0] period_fp;
    reg [31:0] t_fp;
    reg [31:0] green_end_fp;
    reg [31:0] phase;
    reg [31:0] wait_time;

    localparam [31:0] SQRT_2000 = 32'd2930012;
    localparam [31:0] MAX_VELOCITY = 32'd200;

    reg [31:0] sqrt_lut [0:200];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_time <= 32'd0;
            current_time <= 32'd0;
            current_velocity <= 32'd0;
            light_idx <= 4'd0;
            for (i = 0; i < 201; i = i + 1) begin
                sqrt_lut[i] <= 32'd0;
            end
            sqrt_lut[0] <= 32'd2930012;
            sqrt_lut[1] <= 32'd1465006;
            sqrt_lut[2] <= 32'd977216;
        end else begin
            case (state)
                IDLE: begin
                    if (start && n > 1) begin
                        state <= LOAD_LIGHT;
                        light_idx <= 4'd0;
                        current_time <= 32'd0;
                        current_velocity <= 32'd0;
                    end else if (start && n == 1) begin
                        state <= FINAL_SEG;
                        current_time <= 32'd0;
                        current_velocity <= 32'd0;
                    end else begin
                        done <= 1'b0;
                    end
                end

                LOAD_LIGHT: begin
                    case (light_idx)
                        4'd0: begin
                            t_fp <= {16'd0, t_0};
                            period_fp <= {16'd0, g_0 + r_0};
                            green_end_fp <= {16'd0, t_0 + g_0};
                        end
                        4'd1: begin
                            t_fp <= {16'd0, t_1};
                            period_fp <= {16'd0, g_1 + r_1};
                            green_end_fp <= {16'd0, t_1 + g_1};
                        end
                        4'd2: begin
                            t_fp <= {16'd0, t_2};
                            period_fp <= {16'd0, g_2 + r_2};
                            green_end_fp <= {16'd0, t_2 + g_2};
                        end
                        4'd3: begin
                            t_fp <= {16'd0, t_3};
                            period_fp <= {16'd0, g_3 + r_3};
                            green_end_fp <= {16'd0, t_3 + g_3};
                        end
                        4'd4: begin
                            t_fp <= {16'd0, t_4};
                            period_fp <= {16'd0, g_4 + r_4};
                            green_end_fp <= {16'd0, t_4 + g_4};
                        end
                        4'd5: begin
                            t_fp <= {16'd0, t_5};
                            period_fp <= {16'd0, g_5 + r_5};
                            green_end_fp <= {16'd0, t_5 + g_5};
                        end
                        4'd6: begin
                            t_fp <= {16'd0, t_6};
                            period_fp <= {16'd0, g_6 + r_6};
                            green_end_fp <= {16'd0, t_6 + g_6};
                        end
                        4'd7: begin
                            t_fp <= {16'd0, t_7};
                            period_fp <= {16'd0, g_7 + r_7};
                            green_end_fp <= {16'd0, t_7 + g_7};
                        end
                        4'd8: begin
                            t_fp <= {16'd0, t_8};
                            period_fp <= {16'd0, g_8 + r_8};
                            green_end_fp <= {16'd0, t_8 + g_8};
                        end
                        4'd9: begin
                            t_fp <= {16'd0, t_9};
                            period_fp <= {16'd0, g_9 + r_9};
                            green_end_fp <= {16'd0, t_9 + g_9};
                        end
                        4'd10: begin
                            t_fp <= {16'd0, t_10};
                            period_fp <= {16'd0, g_10 + r_10};
                            green_end_fp <= {16'd0, t_10 + g_10};
                        end
                        4'd11: begin
                            t_fp <= {16'd0, t_11};
                            period_fp <= {16'd0, g_11 + r_11};
                            green_end_fp <= {16'd0, t_11 + g_11};
                        end
                        4'd12: begin
                            t_fp <= {16'd0, t_12};
                            period_fp <= {16'd0, g_12 + r_12};
                            green_end_fp <= {16'd0, t_12 + g_12};
                        end
                        4'd13: begin
                            t_fp <= {16'd0, t_13};
                            period_fp <= {16'd0, g_13 + r_13};
                            green_end_fp <= {16'd0, t_13 + g_13};
                        end
                        4'd14: begin
                            t_fp <= {16'd0, t_14};
                            period_fp <= {16'd0, g_14 + r_14};
                            green_end_fp <= {16'd0, t_14 + g_14};
                        end
                        default: begin
                            t_fp <= 32'd0;
                            period_fp <= 32'd0;
                            green_end_fp <= 32'd0;
                        end
                    endcase
                    state <= COMPUTE_SEG;
                end

                COMPUTE_SEG: begin
                    if (current_velocity == 32'd0) begin
                        seg_time <= 32'd2930012;
                    end else begin
                        seg_time <= sqrt_lut[current_velocity[31:16]];
                    end
                    arrival_time <= current_time + seg_time;
                    state <= CHECK_GREEN;
                end

                CHECK_GREEN: begin
                    phase <= arrival_time;
                    if (arrival_time >= period_fp) begin
                        state <= WAIT_GREEN;
                        wait_time <= 32'd0;
                    end else begin
                        phase <= arrival_time;
                        if (phase >= t_fp && phase <= green_end_fp) begin
                            current_velocity <= current_velocity + seg_time;
                            current_time <= arrival_time;
                            state <= NEXT_LIGHT;
                        end else begin
                            if (t_fp >= phase) begin
                                wait_time <= t_fp - phase;
                            end else begin
                                wait_time <= t_fp + period_fp - phase;
                            end
                            state <= WAIT_GREEN;
                        end
                    end
                end

                WAIT_GREEN: begin
                    if (arrival_time >= period_fp && wait_time == 32'd0) begin
                        phase <= phase - period_fp;
                        arrival_time <= arrival_time - period_fp;
                        if (arrival_time - period_fp >= period_fp) begin
                        end else begin
                            state <= CHECK_GREEN;
                        end
                    end else begin
                        current_time <= current_time + wait_time;
                        current_velocity <= 32'd0;
                        state <= NEXT_LIGHT;
                    end
                end

                NEXT_LIGHT: begin
                    light_idx <= light_idx + 4'd1;
                    if (light_idx + 4'd1 >= n - 4'd1) begin
                        state <= FINAL_SEG;
                    end else begin
                        state <= LOAD_LIGHT;
                    end
                end

                FINAL_SEG: begin
                    if (current_velocity == 32'd0) begin
                        seg_time <= 32'd2930012;
                    end else begin
                        seg_time <= sqrt_lut[current_velocity[31:16]];
                    end
                    total_time <= current_time + seg_time;
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