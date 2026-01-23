module polar_rect_converter (
    input clk,
    input rst_n,
    input start,
    input [1:0] mode,
    input [31:0] input_a,
    input [31:0] input_b,
    output reg [31:0] output_x,
    output reg [31:0] output_y,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CALCULATE_SQRT,
        CALCULATE_TRIG,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] r, theta;
    reg [31:0] x, y;
    reg [31:0] sqrt_result;
    reg [31:0] cos_result, sin_result;
    reg [31:0] atan2_result;

    // Iteration counters
    reg [3:0] sqrt_iter;
    reg [3:0] trig_iter;
    reg [3:0] atan2_iter;

    // Intermediate calculation registers (64-bit)
    reg [63:0] sqrt_temp;
    reg [63:0] trig_temp;
    reg [63:0] atan2_temp;

    // Lookup table for trigonometric functions (simplified)
    reg [31:0] sin_lut [0:15];
    reg [31:0] cos_lut [0:15];

    // Initialize lookup tables (simplified values)
    initial begin
        // Sin values for 0 to π/2 in Q16.16
        sin_lut[0] = 32'h00000000;  // sin(0)
        sin_lut[1] = 32'h00019220;  // sin(π/4)
        sin_lut[2] = 32'h0003243F;  // sin(π/2)
        // ... other values would be initialized here

        // Cos values for 0 to π/2 in Q16.16
        cos_lut[0] = 32'h0003243F;  // cos(0)
        cos_lut[1] = 32'h00019220;  // cos(π/4)
        cos_lut[2] = 32'h00000000;  // cos(π/2)
        // ... other values would be initialized here
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            output_x <= 0;
            output_y <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = (mode == 2'b00) ? CALCULATE_TRIG : CALCULATE_SQRT;
                end
            end
            CALCULATE_SQRT: begin
                if (sqrt_iter == 15) begin
                    next_state = CALCULATE_TRIG;
                end
            end
            CALCULATE_TRIG: begin
                if (trig_iter == 15) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            r <= 0;
            theta <= 0;
            x <= 0;
            y <= 0;
            sqrt_result <= 0;
            cos_result <= 0;
            sin_result <= 0;
            atan2_result <= 0;
            sqrt_iter <= 0;
            trig_iter <= 0;
            atan2_iter <= 0;
            sqrt_temp <= 0;
            trig_temp <= 0;
            atan2_temp <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        if (mode == 2'b00) begin
                            // Polar to Rectangular
                            r <= input_a;
                            theta <= input_b;
                        end else begin
                            // Rectangular to Polar
                            x <= input_a;
                            y <= input_b;
                        end
                    end
                end
                CALCULATE_SQRT: begin
                    // Square root calculation (simplified)
                    if (sqrt_iter == 0) begin
                        sqrt_temp <= {32'd0, x} + {32'd0, y};
                    end else begin
                        // Iterative approximation
                        sqrt_temp <= sqrt_temp - (sqrt_temp >> sqrt_iter);
                    end
                    sqrt_iter <= sqrt_iter + 1;
                    if (sqrt_iter == 15) begin
                        sqrt_result <= sqrt_temp[31:0];
                    end
                end
                CALCULATE_TRIG: begin
                    if (mode == 2'b00) begin
                        // Polar to Rectangular: compute cos and sin
                        if (trig_iter == 0) begin
                            trig_temp <= {32'd0, theta};
                        end else begin
                            // Lookup table approximation
                            cos_result <= cos_lut[trig_iter];
                            sin_result <= sin_lut[trig_iter];
                        end
                        trig_iter <= trig_iter + 1;
                        if (trig_iter == 15) begin
                            output_x <= (r * cos_result) >> 16;
                            output_y <= (r * sin_result) >> 16;
                        end
                    end else begin
                        // Rectangular to Polar: compute atan2
                        if (atan2_iter == 0) begin
                            atan2_temp <= {32'd0, y} / {32'd0, x};
                        end else begin
                            // CORDIC-like iteration
                            atan2_temp <= atan2_temp - (atan2_temp >> atan2_iter);
                        end
                        atan2_iter <= atan2_iter + 1;
                        if (atan2_iter == 15) begin
                            output_x <= sqrt_result;
                            output_y <= atan2_temp[31:0];
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Output done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule