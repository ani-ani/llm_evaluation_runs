module MinOperationsEqualizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] COUNT_ONES      = 4'd1;
    localparam [3:0] CHECK_COUNT     = 4'd2;
    localparam [3:0] COMPUTE_OVERALL = 4'd3;
    localparam [3:0] CHECK_GCD       = 4'd4;
    localparam [3:0] FIND_SUBARRAY   = 4'd5;
    localparam [3:0] COMPLETED       = 4'd6;
    localparam [3:0] GCD_CALC        = 4'd7;
    localparam [3:0] NEXT_I          = 4'd8;
    localparam [3:0] NEXT_J          = 4'd9;

    // Internal registers and variables
    reg [3:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg signed [15:0] result_reg;
    reg [15:0] count_ones;
    reg [31:0] overall_gcd;
    reg [31:0] subarray_gcd;
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg [15:0] min_ops;
    reg [15:0] current_ops;
    reg [7:0] cycle_count;
    reg gcd_start;
    reg gcd_done;
    reg [31:0] gcd_result;
    reg [7:0] gcd_cycles;

    localparam [7:0] MAX_CYCLES = 8'd250;
    localparam [7:0] GCD_MAX_CYCLES = 8'd32;

    // GCD computation state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            result_reg <= 16'sd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            count_ones <= 16'd0;
            overall_gcd <= 32'd0;
            subarray_gcd <= 32'd0;
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            min_ops <= 16'hFFFF;
            current_ops <= 16'd0;
            cycle_count <= 8'd0;
            gcd_start <= 1'b0;
            gcd_done <= 1'b0;
            gcd_result <= 32'd0;
            gcd_cycles <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    min_ops <= 16'hFFFF;
                    if (start) begin
                        if (len == 4'd0) begin
                            result_reg <= 16'sd0;
                            state <= COMPLETED;
                        end else begin
                            count_ones <= 16'd0;
                            i <= 4'd0;
                            state <= COUNT_ONES;
                        end
                    end
                end

                COUNT_ONES: begin
                    if (i < len) begin
                        if (arr[i] == 32'd1) begin
                            count_ones <= count_ones + 16'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= CHECK_COUNT;
                    end
                end

                CHECK_COUNT: begin
                    if (count_ones > 16'd0) begin
                        result_reg <= len - count_ones;
                        state <= COMPLETED;
                    end else begin
                        if (len == 4'd1) begin
                            if (arr[0] == 32'd1) begin
                                result_reg <= 16'sd0;
                            end else begin
                                result_reg <= -16'sd1;
                            end
                            state <= COMPLETED;
                        end else begin
                            i <= 4'd0;
                            k <= 4'd0;
                            state <= COMPUTE_OVERALL;
                        end
                    end
                end

                COMPUTE_OVERALL: begin
                    if (k == 4'd0) begin
                        overall_gcd <= arr[0];
                        k <= 4'd1;
                    end else if (k < len) begin
                        gcd_a <= overall_gcd;
                        gcd_b <= arr[k];
                        gcd_start <= 1'b1;
                        gcd_cycles <= 8'd0;
                        state <= GCD_CALC;
                        k <= k + 4'd1;
                    end else begin
                        state <= CHECK_GCD;
                    end
                end

                GCD_CALC: begin
                    gcd_start <= 1'b0;
                    if (gcd_cycles < GCD_MAX_CYCLES) begin
                        gcd_cycles <= gcd_cycles + 8'd1;
                        if (gcd_a == 32'd0) begin
                            gcd_result <= gcd_b;
                            gcd_done <= 1'b1;
                        end else if (gcd_b == 32'd0) begin
                            gcd_result <= gcd_a;
                            gcd_done <= 1'b1;
                        end else if (gcd_a > gcd_b) begin
                            gcd_a <= gcd_a - gcd_b;
                        end else begin
                            gcd_b <= gcd_b - gcd_a;
                        end
                    end else begin
                        gcd_done <= 1'b1;
                        gcd_result <= 32'd1;
                    end
                    if (gcd_done || (gcd_a == 32'd0) || (gcd_b == 32'd0)) begin
                        overall_gcd <= gcd_result;
                        gcd_done <= 1'b0;
                        state <= COMPUTE_OVERALL;
                    end else begin
                        state <= GCD_CALC;
                    end
                end

                CHECK_GCD: begin
                    if (overall_gcd != 32'd1) begin
                        result_reg <= -16'sd1;
                        state <= COMPLETED;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        min_ops <= 16'hFFFF;
                        subarray_gcd <= 32'd0;
                        state <= FIND_SUBARRAY;
                    end
                end

                FIND_SUBARRAY: begin
                    if (i < len) begin
                        j <= i;
                        subarray_gcd <= arr[i];
                        state <= NEXT_J;
                    end else begin
                        if (min_ops == 16'hFFFF) begin
                            result_reg <= -16'sd1;
                        end else begin
                            result_reg <= min_ops;
                        end
                        state <= COMPLETED;
                    end
                end

                NEXT_J: begin
                    if (subarray_gcd == 32'd1) begin
                        current_ops <= (j - i) + (len - 4'd1);
                        if (current_ops < min_ops) begin
                            min_ops <= current_ops;
                        end
                        i <= i + 4'd1;
                        state <= FIND_SUBARRAY;
                    end else if (j < len - 4'd1) begin
                        gcd_a <= subarray_gcd;
                        gcd_b <= arr[j + 4'd1];
                        gcd_start <= 1'b1;
                        gcd_cycles <= 8'd0;
                        state <= NEXT_I;
                    end else begin
                        i <= i + 4'd1;
                        state <= FIND_SUBARRAY;
                    end
                end

                NEXT_I: begin
                    gcd_start <= 1'b0;
                    if (gcd_cycles < GCD_MAX_CYCLES) begin
                        gcd_cycles <= gcd_cycles + 8'd1;
                        if (gcd_a == 32'd0) begin
                            gcd_result <= gcd_b;
                            gcd_done <= 1'b1;
                        end else if (gcd_b == 32'd0) begin
                            gcd_result <= gcd_a;
                            gcd_done <= 1'b1;
                        end else if (gcd_a > gcd_b) begin
                            gcd_a <= gcd_a - gcd_b;
                        end else begin
                            gcd_b <= gcd_b - gcd_a;
                        end
                    end else begin
                        gcd_done <= 1'b1;
                        gcd_result <= 32'd1;
                    end
                    if (gcd_done || (gcd_a == 32'd0) || (gcd_b == 32'd0)) begin
                        subarray_gcd <= gcd_result;
                        gcd_done <= 1'b0;
                        j <= j + 4'd1;
                        state <= NEXT_J;
                    end else begin
                        state <= NEXT_I;
                    end
                end

                COMPLETED: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                result <= 16'sd0;
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
endmodule