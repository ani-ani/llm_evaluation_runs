module triangle_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] a,
    input wire [4:0] b,
    input wire [4:0] c,
    input wire [4:0] l,
    output reg [15:0] result,
    output reg done
);

    // State Definitions
    localparam [3:0] IDLE                = 4'd0;
    localparam [3:0] COMPUTE_TOTAL       = 4'd1;
    localparam [3:0] COMPUTE_DELTAS      = 4'd2;
    localparam [3:0] LOOP_X_A            = 4'd3;
    localparam [3:0] LOOP_X_B            = 4'd4;
    localparam [3:0] LOOP_X_C            = 4'd5;
    localparam [3:0] CALC_SUM_INVALID    = 4'd6;
    localparam [3:0] SUBTRACT_INVALID    = 4'd7;
    localparam [3:0] FINISH              = 4'd8;

    reg [3:0] state;
    reg [15:0] total;
    reg [15:0] sum_invalid;
    reg [15:0] invalid_a, invalid_b, invalid_c;
    reg [15:0] current_term;
    reg [4:0] x_counter;
    reg [15:0] temp_product;
    reg [15:0] l_extended;

    // Delta calculations
    wire signed [5:0] delta_a = a - b - c;
    wire signed [5:0] delta_b = b - a - c;
    wire signed [5:0] delta_c = c - a - b;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total <= 16'd0;
            sum_invalid <= 16'd0;
            invalid_a <= 16'd0;
            invalid_b <= 16'd0;
            invalid_c <= 16'd0;
            x_counter <= 5'd0;
            current_term <= 16'd0;
            temp_product <= 16'd0;
            result <= 16'd0;
            cycle_count <= 8'd0;
            l_extended <= {11'd0, l};
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        cycle_count <= 8'd0;
                        state <= COMPUTE_TOTAL;
                        l_extended <= {11'd0, l};
                    end
                end

                COMPUTE_TOTAL: begin
                    // total = (l+3)(l+2)(l+1)/6
                    temp_product <= (l_extended + 16'd3) * (l_extended + 16'd2);
                    state <= COMPUTE_DELTAS;
                end

                COMPUTE_DELTAS: begin
                    total <= (temp_product * (l_extended + 16'd1)) / 16'd6;
                    invalid_a <= 16'd0;
                    invalid_b <= 16'd0;
                    invalid_c <= 16'd0;
                    x_counter <= 5'd0;
                    state <= LOOP_X_A;
                end

                LOOP_X_A: begin
                    if ($signed({1'b0, x_counter}) >= delta_a) begin
                        // M = min(l - x_counter, x_counter - delta_a)
                        reg [4:0] M;
                        reg [4:0] term1 = l - x_counter;
                        reg [5:0] term2 = {1'b0, x_counter} - delta_a;
                        M = (term1 < term2[4:0]) ? term1 : term2[4:0];
                        current_term <= (M + 5'd1) * (M + 5'd2) / 5'd2;
                        invalid_a <= invalid_a + ((M + 5'd1) * (M + 5'd2) / 5'd2);
                    end

                    if (x_counter == l) begin
                        x_counter <= 5'd0;
                        state <= LOOP_X_B;
                    end else begin
                        x_counter <= x_counter + 5'd1;
                    end
                end

                LOOP_X_B: begin
                    if ($signed({1'b0, x_counter}) >= delta_b) begin
                        reg [4:0] M;
                        reg [4:0] term1 = l - x_counter;
                        reg [5:0] term2 = {1'b0, x_counter} - delta_b;
                        M = (term1 < term2[4:0]) ? term1 : term2[4:0];
                        invalid_b <= invalid_b + ((M + 5'd1) * (M + 5'd2) / 5'd2);
                    end

                    if (x_counter == l) begin
                        x_counter <= 5'd0;
                        state <= LOOP_X_C;
                    end else begin
                        x_counter <= x_counter + 5'd1;
                    end
                end

                LOOP_X_C: begin
                    if ($signed({1'b0, x_counter}) >= delta_c) begin
                        reg [4:0] M;
                        reg [4:0] term1 = l - x_counter;
                        reg [5:0] term2 = {1'b0, x_counter} - delta_c;
                        M = (term1 < term2[4:0]) ? term1 : term2[4:0];
                        invalid_c <= invalid_c + ((M + 5'd1) * (M + 5'd2) / 5'd2);
                    end

                    if (x_counter == l) begin
                        x_counter <= 5'd0;
                        state <= CALC_SUM_INVALID;
                    end else begin
                        x_counter <= x_counter + 5'd1;
                    end
                end

                CALC_SUM_INVALID: begin
                    sum_invalid <= invalid_a + invalid_b + invalid_c;
                    state <= SUBTRACT_INVALID;
                end

                SUBTRACT_INVALID: begin
                    result <= total > sum_invalid ? total - sum_invalid : 16'd0;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule