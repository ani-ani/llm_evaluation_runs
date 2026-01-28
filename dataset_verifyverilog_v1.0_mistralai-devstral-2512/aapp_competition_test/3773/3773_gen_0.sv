module StoneGameGrundy(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_i,
    input wire [31:0] k_i,
    output reg [15:0] grundy,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [31:0] a_reg;
    reg [31:0] q_reg;
    reg [31:0] r_reg;
    reg [31:0] q_plus_1_reg;
    reg [31:0] x_reg;
    reg [31:0] temp_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Division and modulo using iterative method
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [5:0] div_cycle;
    reg div_start;
    reg div_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a_reg <= 32'd0;
            q_reg <= 32'd0;
            r_reg <= 32'd0;
            q_plus_1_reg <= 32'd0;
            x_reg <= 32'd0;
            temp_reg <= 32'd0;
            cycle_count <= 8'd0;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            div_cycle <= 6'd0;
            div_start <= 1'b0;
            div_done <= 1'b0;
            grundy <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        a_reg <= a_i;
                        // Initialize division for first iteration
                        dividend <= a_i;
                        divisor <= k_i;
                        div_start <= 1'b1;
                        div_done <= 1'b0;
                        div_cycle <= 6'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Division and modulo calculation
                    if (div_start) begin
                        // Restoring division algorithm
                        remainder <= dividend;
                        quotient <= 32'd0;
                        div_cycle <= 6'd0;
                        div_start <= 1'b0;
                    end else if (!div_done) begin
                        if (div_cycle < 6'd32) begin
                            remainder <= {remainder[30:0], 1'b0};
                            quotient <= {quotient[30:0], remainder[31]};
                            if (remainder[31:0] >= divisor) begin
                                remainder <= remainder[31:0] - divisor;
                                quotient[0] <= 1'b1;
                            end
                            div_cycle <= div_cycle + 6'd1;
                        end else begin
                            div_done <= 1'b1;
                            q_reg <= quotient;
                            r_reg <= remainder;
                        end
                    end

                    // Check if division is done
                    if (div_done) begin
                        div_done <= 1'b0;
                        if (r_reg == 32'd0) begin
                            // Result is q
                            grundy <= q_reg[15:0];
                            state <= FINISH;
                        end else begin
                            // Calculate q_plus_1
                            q_plus_1_reg <= q_reg + 32'd1;

                            // Calculate x = ceil(r / q_plus_1)
                            // x = (r + q_plus_1 - 1) / q_plus_1
                            temp_reg <= r_reg + q_plus_1_reg - 32'd1;
                            dividend <= temp_reg;
                            divisor <= q_plus_1_reg;
                            div_start <= 1'b1;

                            // Wait for division to complete
                            if (div_done) begin
                                div_done <= 1'b0;
                                x_reg <= quotient;
                                if (x_reg == 32'd0) begin
                                    x_reg <= 32'd1;
                                end

                                // Update a_reg
                                temp_reg <= x_reg * q_plus_1_reg;
                                a_reg <= a_reg - temp_reg;

                                // Check if a_reg < k_i
                                if (a_reg < k_i) begin
                                    grundy <= 16'd0;
                                    state <= FINISH;
                                end else begin
                                    // Next iteration
                                    dividend <= a_reg;
                                    divisor <= k_i;
                                    div_start <= 1'b1;
                                end
                            end
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        grundy <= 16'd0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule