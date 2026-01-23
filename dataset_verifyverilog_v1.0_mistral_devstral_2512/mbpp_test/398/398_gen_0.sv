module sum_of_digits (
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
    input wire [2:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [2:0] idx;
    reg [15:0] total_sum;
    reg [7:0] current_val;
    reg [7:0] abs_val;
    reg [3:0] digit_sum;
    reg [1:0] calc_state;
    reg [7:0] temp_val;
    reg [7:0] hundreds;
    reg [7:0] tens;
    reg [7:0] ones;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx <= 3'd0;
            total_sum <= 16'd0;
            digit_sum <= 4'd0;
            abs_val <= 8'd0;
            calc_state <= 2'd0;
            temp_val <= 8'd0;
            hundreds <= 8'd0;
            tens <= 8'd0;
            ones <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        idx <= 3'd0;
                        total_sum <= 16'd0;
                    end
                end

                PROCESS: begin
                    if (idx < len) begin
                        case (idx)
                            3'd0: current_val <= arr_0;
                            3'd1: current_val <= arr_1;
                            3'd2: current_val <= arr_2;
                            3'd3: current_val <= arr_3;
                            3'd4: current_val <= arr_4;
                            3'd5: current_val <= arr_5;
                            3'd6: current_val <= arr_6;
                            3'd7: current_val <= arr_7;
                        endcase
                        state <= CALCULATE;
                        calc_state <= 2'd0;
                        digit_sum <= 4'd0;
                    end else begin
                        state <= FINISH;
                    end
                end

                CALCULATE: begin
                    case (calc_state)
                        2'd0: begin
                            // Get absolute value
                            if (current_val[7]) begin
                                abs_val <= (~current_val + 8'd1);
                            end else begin
                                abs_val <= current_val;
                            end
                            temp_val <= abs_val;
                            calc_state <= 2'd1;
                        end
                        2'd1: begin
                            // Extract hundreds digit
                            if (temp_val >= 8'd100) begin
                                hundreds <= temp_val / 8'd100;
                                temp_val <= temp_val - (hundreds * 8'd100);
                                total_sum <= total_sum + {12'b0, hundreds[3:0]};
                            end
                            calc_state <= 2'd2;
                        end
                        2'd2: begin
                            // Extract tens digit
                            if (temp_val >= 8'd10) begin
                                tens <= temp_val / 8'd10;
                                temp_val <= temp_val - (tens * 8'd10);
                                total_sum <= total_sum + {12'b0, tens[3:0]};
                            end
                            calc_state <= 2'd3;
                        end
                        2'd3: begin
                            // Extract ones digit
                            ones <= temp_val;
                            total_sum <= total_sum + {12'b0, ones[3:0]};
                            idx <= idx + 1'b1;
                            state <= PROCESS;
                        end
                    endcase
                end

                FINISH: begin
                    result <= total_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule