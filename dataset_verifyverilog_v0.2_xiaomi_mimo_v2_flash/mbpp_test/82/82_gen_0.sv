module sphere_volume (
    input clk,
    input rst_n,
    input start,
    input [31:0] radius,
    output reg [31:0] volume,
    output reg done
);

    // Fixed-point constant C = (4/3) * pi in Q16.16 format
    // (4/3) * pi ≈ 4.188790205
    // 4.188790205 * 65536 = 274413.16... -> 0x0006487E
    localparam [31:0] C = 32'h0006_487E;

    // State definitions
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        CALC_SQ    = 3'b001,
        CALC_CUBE  = 3'b010,
        CALC_FINAL = 3'b011,
        DONE       = 3'b100
    } state_t;

    state_t current_state, next_state;

    // Intermediate registers
    reg [31:0] radius_reg;
    reg [63:0] r_squared;
    reg [63:0] r_cubed;
    reg [63:0] product;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            volume <= 32'b0;
            done <= 1'b0;
            radius_reg <= 32'b0;
            r_squared <= 64'b0;
            r_cubed <= 64'b0;
            product <= 64'b0;
        end else begin
            current_state <= next_state;

            // Sequential updates for pipeline registers
            case (current_state)
                IDLE: begin
                    if (start) begin
                        radius_reg <= radius;
                    end
                end

                CALC_SQ: begin
                    // r * r
                    r_squared <= radius_reg * radius_reg;
                end

                CALC_CUBE: begin
                    // r^2 * r
                    r_cubed <= r_squared[63:0] * radius_reg;
                end

                CALC_FINAL: begin
                    // r^3 * C
                    product <= r_cubed * C;
                end

                DONE: begin
                    // Extract bits [47:16] and shift right by 16 (keep upper 32 of [63:0])
                    // effectively taking bits [47:16] of the product
                    volume <= product[47:16];
                    done <= 1'b1;
                end
            endcase

            // Reset done flag when leaving DONE state
            if (next_state != DONE) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CALC_SQ;
                else
                    next_state = IDLE;
            end

            CALC_SQ: begin
                next_state = CALC_CUBE;
            end

            CALC_CUBE: begin
                next_state = CALC_FINAL;
            end

            CALC_FINAL: begin
                next_state = DONE;
            end

            DONE: begin
                if (start)
                    next_state = CALC_SQ;
                else
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule