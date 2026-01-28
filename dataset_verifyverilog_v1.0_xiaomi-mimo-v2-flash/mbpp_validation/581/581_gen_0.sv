module pyramid_surface_area (
    input clk,
    input rst_n,
    input start,
    input [31:0] base_edge_q16,
    input [31:0] slant_height_q16,
    output reg [31:0] result_q16,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_TERM1 = 3'd1;  // Compute term1 = 2 * base_edge * slant_height
    localparam [2:0] CALC_TERM2 = 3'd2;  // Compute term2 = base_edge * base_edge
    localparam [2:0] ADD_TERM1  = 3'd3;  // Add term1 to accumulated result
    localparam [2:0] ADD_TERM2  = 3'd4;  // Add term2 to accumulated result
    localparam [2:0] FINISH     = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers for fixed-point operations
    reg [63:0] mult_temp;      // 64-bit for multiplication result
    reg [31:0] term1;          // Q16.16 term1 = 2 * base_edge * slant_height
    reg [31:0] term2;          // Q16.16 term2 = base_edge * base_edge
    reg [31:0] result_reg;     // Accumulated result
    reg [31:0] base_reg;       // Store base_edge for reuse
    reg [31:0] slant_reg;      // Store slant_height for reuse

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_q16 <= 32'd0;
            cycle_count <= 8'd0;
            // Initialize all intermediate registers
            mult_temp <= 64'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            result_reg <= 32'd0;
            base_reg <= 32'd0;
            slant_reg <= 32'd0;
        end else begin
            // Default next state
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        base_reg <= base_edge_q16;
                        slant_reg <= slant_height_q16;
                        result_reg <= 32'd0;
                        term1 <= 32'd0;
                        term2 <= 32'd0;
                        state <= CALC_TERM1;
                    end
                end

                CALC_TERM1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute: base_edge * slant_height (Q16.16 * Q16.16 = Q32.32)
                    // Result: base_reg[15:0] * slant_reg[15:0] -> Q32.32
                    // For Q16.16, multiply then shift right by 16 to get Q16.16
                    mult_temp <= base_reg * slant_reg;
                    // Multiply by 2 (add shifted result to itself)
                    term1 <= (mult_temp[47:16] << 1);  // Take Q16.16 part and double
                    state <= CALC_TERM2;
                end

                CALC_TERM2: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute: base_edge * base_edge
                    mult_temp <= base_reg * base_reg;
                    // Take upper 32 bits (Q16.16)
                    term2 <= mult_temp[47:16];
                    state <= ADD_TERM1;
                end

                ADD_TERM1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Add term1 to result_reg (both Q16.16)
                    result_reg <= result_reg + term1;
                    state <= ADD_TERM2;
                end

                ADD_TERM2: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Add term2 to result_reg (both Q16.16)
                    result_reg <= result_reg + term2;
                    // Check if done or timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_q16 <= result_reg;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result_q16 <= 32'd0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_TERM1;
                else next_state = IDLE;
            end

            CALC_TERM1: next_state = CALC_TERM2;

            CALC_TERM2: next_state = ADD_TERM1;

            ADD_TERM1: next_state = ADD_TERM2;

            ADD_TERM2: next_state = FINISH;

            FINISH: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

endmodule