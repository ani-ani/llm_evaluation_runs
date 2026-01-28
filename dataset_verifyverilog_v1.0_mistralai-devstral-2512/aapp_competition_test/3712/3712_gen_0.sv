module student_compartment_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] data_in,
    input wire valid_in,
    input wire last_in,
    output reg [15:0] result,
    output reg done,
    output reg idle
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state;
    reg [15:0] c1, c2, c3, c4;
    reg [15:0] S;
    reg [15:0] cnt;
    reg [15:0] temp;
    reg [15:0] remainder;
    reg [15:0] result_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            c1 <= 16'd0;
            c2 <= 16'd0;
            c3 <= 16'd0;
            c4 <= 16'd0;
            S <= 16'd0;
            cnt <= 16'd0;
            temp <= 16'd0;
            remainder <= 16'd0;
            result_temp <= 16'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            idle <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    idle <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        state <= INPUT;
                        idle <= 1'b0;
                    end
                end

                INPUT: begin
                    if (valid_in) begin
                        case (data_in)
                            4'd1: c1 <= c1 + 16'd1;
                            4'd2: c2 <= c2 + 16'd1;
                            4'd3: c3 <= c3 + 16'd1;
                            4'd4: c4 <= c4 + 16'd1;
                            default: ; // 0 students, do nothing
                        endcase
                    end
                    if (last_in) begin
                        state <= CALCULATE;
                        cycle_count <= 8'd0;
                        S <= c1 + (c2 << 1) + (c3 * 3'd3) + (c4 << 2);
                        result_temp <= 16'd0;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    case (cycle_count)
                        8'd0: begin
                            // Check feasibility
                            if (S < 3'd3 || S == 3'd5) begin
                                result_temp <= 16'd65535; // -1 represented as max 16-bit
                                state <= OUTPUT;
                            end
                        end

                        8'd1: begin
                            // Pair 1s and 2s
                            cnt <= (c1 < c2) ? c1 : c2;
                            result_temp <= result_temp + cnt;
                            c1 <= c1 - cnt;
                            c2 <= c2 - cnt;
                            c3 <= c3 + cnt;
                        end

                        8'd2: begin
                            // Form groups of 3 from 1s
                            cnt <= c1 / 3'd3;
                            result_temp <= result_temp + (cnt << 1);
                            c1 <= c1 - (cnt * 3'd3);
                            c3 <= c3 + cnt;
                        end

                        8'd3: begin
                            // Handle remainder 1s
                            if (c1 > 16'd0) begin
                                if (c3 > 16'd0) begin
                                    c3 <= c3 - 16'd1;
                                    c1 <= c1 - 16'd1;
                                    result_temp <= result_temp + 16'd1;
                                end else if (c4 > 16'd0) begin
                                    c4 <= c4 - 16'd1;
                                    c1 <= c1 - 16'd1;
                                    result_temp <= result_temp + 16'd2;
                                end
                            end
                        end

                        8'd4: begin
                            // Form groups of 3 from 2s
                            cnt <= c2 / 3'd3;
                            result_temp <= result_temp + (cnt << 1);
                            c2 <= c2 - (cnt * 3'd3);
                            c3 <= c3 + cnt;
                        end

                        8'd5: begin
                            // Handle remainder 2s
                            if (c2 > 16'd0) begin
                                if (c4 > 16'd0) begin
                                    c4 <= c4 - 16'd1;
                                    c2 <= c2 - 16'd1;
                                    result_temp <= result_temp + 16'd1;
                                end
                            end
                        end

                        8'd6: begin
                            // Final check for remaining 1s and 2s
                            if (c1 > 16'd0 || c2 > 16'd0) begin
                                result_temp <= 16'd65535; // -1 if not possible
                            end
                            state <= OUTPUT;
                        end

                        default: begin
                            if (cycle_count >= MAX_CYCLES) begin
                                state <= OUTPUT;
                            end
                        end
                    endcase
                end

                OUTPUT: begin
                    result <= result_temp;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule