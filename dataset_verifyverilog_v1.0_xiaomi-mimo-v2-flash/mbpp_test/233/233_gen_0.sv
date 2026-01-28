module CylinderArea (
    input clk,
    input rst_n,
    input start,
    input [15:0] radius,
    input [15:0] height,
    output reg [31:0] area,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MULTIPLY1 = 3'd1;    // constant * radius
    localparam [2:0] MULTIPLY2 = 3'd2;    // result * height
    localparam [2:0] SHIFT = 3'd3;        // shift right by 16
    localparam [2:0] FINISH = 3'd4;

    // Constant: 2 * PI * 2^16 = 205891
    localparam [47:0] PI_CONST = 48'd205891;  // 2*PI in Q16.16

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Pipeline registers
    reg [47:0] mult1_result;      // constant * radius (47:0)
    reg [47:0] mult2_result;      // (constant * radius) * height
    reg [31:0] shift_result;      // final result

    reg start_dly;
    wire start_pulse;

    // Detect start pulse
    assign start_pulse = start & ~start_dly;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_pulse) begin
                    next_state = MULTIPLY1;
                end else begin
                    next_state = IDLE;
                end
            end
            MULTIPLY1: begin
                next_state = MULTIPLY2;
            end
            MULTIPLY2: begin
                next_state = SHIFT;
            end
            SHIFT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            area <= 32'd0;
            cycle_count <= 8'd0;
            mult1_result <= 48'd0;
            mult2_result <= 48'd0;
            shift_result <= 32'd0;
            start_dly <= 1'b0;
        end else begin
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    mult1_result <= 48'd0;
                    mult2_result <= 48'd0;
                    shift_result <= 32'd0;
                end

                MULTIPLY1: begin
                    // PI_CONST (47:0) * radius (15:0) = 63:0
                    // We store lower 48 bits
                    mult1_result <= PI_CONST * radius;
                    cycle_count <= cycle_count + 8'd1;
                end

                MULTIPLY2: begin
                    // mult1_result (47:0) * height (15:0) = 63:0
                    // Take lower 48 bits (enough for result)
                    mult2_result <= mult1_result * height;
                    cycle_count <= cycle_count + 8'd1;
                end

                SHIFT: begin
                    // Right shift by 16: (mult2_result >> 16)
                    // Q16.16 result in lower 32 bits
                    shift_result <= mult2_result[47:16];
                    cycle_count <= cycle_count + 8'd1;
                end

                FINISH: begin
                    area <= shift_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // State transition
            if (state != FINISH) begin
                state <= next_state;
            end
        end
    end

endmodule