module dance_complexity_calc(
    input clk,
    input rst_n,
    input start,
    input [7:0] x_mask,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] SHIFT = 32'd128; // 2^7

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] x_reg;
    reg [31:0] temp_result;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC;
                else
                    next_state = IDLE;
            end
            CALC: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            x_reg <= 8'd0;
            temp_result <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x_mask;
                    end
                end

                CALC: begin
                    // Formula: (x * 2^7) % MOD
                    // Since x <= 255, x * 128 <= 32640
                    // Since 32640 < 1000000007, result is just x * 128
                    // Calculation: {24'b0, x_reg} << 7
                    temp_result <= ({24'd0, x_reg} << 7);
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule