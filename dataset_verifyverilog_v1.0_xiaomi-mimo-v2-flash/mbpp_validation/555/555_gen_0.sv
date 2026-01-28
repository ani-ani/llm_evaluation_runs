module DifferenceOfCubesAndSums (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC_S = 3'd2;
    localparam [2:0] CALC_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] n_reg;
    reg [31:0] s_reg;
    reg [31:0] temp_result;
    reg [5:0] cycle_count; // Counter for timing (max 64 cycles)
    wire [31:0] n_plus_one;
    wire [31:0] product;
    wire [31:0] s_minus_one;
    wire [31:0] final_product;

    // Intermediate calculations
    assign n_plus_one = {24'd0, n_reg} + 32'd1;
    assign product = {24'd0, n_reg} * n_plus_one;
    assign s_reg_wire = product >> 1; // Division by 2
    assign s_minus_one = s_reg - 32'd1;
    assign final_product = s_reg * s_minus_one;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start && rst_n) ? LOAD : IDLE;
            LOAD: next_state = CALC_S;
            CALC_S: next_state = CALC_RESULT;
            CALC_RESULT: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 8'd0;
            s_reg <= 32'd0;
            temp_result <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 6'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        n_reg <= n;
                    end
                end

                LOAD: begin
                    // S = N * (N + 1) / 2
                    if (n_reg == 8'd0) begin
                        s_reg <= 32'd0;
                    end else begin
                        s_reg <= s_reg_wire;
                    end
                end

                CALC_S: begin
                    // Calculate S * (S - 1)
                    if (n_reg == 8'd0) begin
                        temp_result <= 32'd0;
                    end else begin
                        temp_result <= final_product;
                    end
                end

                CALC_RESULT: begin
                    // Clamp to max value if N > 128 (overflow check)
                    if (n_reg > 8'd128) begin
                        result <= 32'hFFFFFFFF; // Max 32-bit value
                    end else begin
                        result <= temp_result;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    n_reg <= 8'd0;
                    s_reg <= 32'd0;
                    temp_result <= 32'd0;
                    result <= 32'd0;
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                end
            endcase
        end
    end

endmodule