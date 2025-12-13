module complex_angle(
    input              clk,
    input              rst_n,      // async active-low reset
    input              start,      // start pulse
    input      [31:0]  real_part,  // Q16.16 signed
    input      [31:0]  imag_part,  // Q16.16 signed
    output reg [31:0]  angle,      // Q16.16 signed angle (-pi..pi)
    output reg         done        // 1-cycle pulse when angle valid
);

    // Internal signed views of inputs
    wire signed [31:0] real_in_s  = real_part;
    wire signed [31:0] imag_in_s  = imag_part;

    // Latched input values
    reg signed [31:0] x0;
    reg signed [31:0] y0;

    // CORDIC iterative registers (extended width for safety)
    reg signed [47:0] x;
    reg signed [47:0] y;
    reg signed [31:0] z;  // angle accumulator in Q16.16

    // Iteration counter
    reg [4:0] iter;       // need to count 0..16

    // State machine
    typedef enum logic [1:0] {
        S_IDLE  = 2'b00,
        S_PREP  = 2'b01,
        S_ITER  = 2'b10,
        S_DONE  = 2'b11
    } state_t;

    state_t state, next_state;

    // Precomputed arctan(2^-i) in Q16.16 (i = 0..15)
    // Values rounded to nearest LSB:
    // 0:  atan(1.0)        = 0.785398163 = 0x0000C90F
    // 1:  atan(0.5)        = 0.463647609 = 0x000076B1
    // 2:  atan(0.25)       = 0.244978663 = 0x00003EB6
    // 3:  atan(0.125)      = 0.124354995 = 0x00001FC9
    // 4:  atan(0.0625)     = 0.062418810 = 0x00000FFA
    // 5:  atan(0.03125)    = 0.031239833 = 0x000007FF
    // 6:  atan(0.015625)   = 0.015623729 = 0x00000400
    // 7:  atan(0.0078125)  = 0.007812341 = 0x00000200
    // 8:  atan(0.00390625) = 0.003906230 = 0x00000100
    // 9:  atan(0.001953125)= 0.001953123 = 0x00000080
    //10:  atan(0.0009765625)=0.000976562 = 0x00000040
    //11:  atan(0.00048828125)=0.000488281=0x00000020
    //12:  atan(0.00024414062)=0.000244141=0x00000010
    //13:  atan(0.00012207031)=0.000122070=0x00000008
    //14:  atan(0.00006103515)=0.000061035=0x00000004
    //15:  atan(0.00003051757)=0.000030518=0x00000002
    localparam signed [31:0] atan_table [0:15] = '{
        32'sh0000C90F,
        32'sh000076B1,
        32'sh00003EB6,
        32'sh00001FC9,
        32'sh00000FFA,
        32'sh000007FF,
        32'sh00000400,
        32'sh00000200,
        32'sh00000100,
        32'sh00000080,
        32'sh00000040,
        32'sh00000020,
        32'sh00000010,
        32'sh00000008,
        32'sh00000004,
        32'sh00000002
    };

    // Constants for quadrant adjustment
    // pi in Q16.16 ~ 3.1415926535 * 65536 = 205887.0 -> 0x000323F6
    // -pi -> 0xFFFFDC0A
    localparam signed [31:0] CONST_PI  = 32'sh000323F6;
    localparam signed [31:0] CONST_NEG_PI = -CONST_PI;

    // Quadrant info
    reg sign_x;
    reg sign_y;
    reg x_zero;
    reg y_zero;

    // Registered start edge not required: spec says start is a pulse, we sample directly.

    // Async reset + state, datapath sequencing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            x0      <= 32'sd0;
            y0      <= 32'sd0;
            x       <= 48'sd0;
            y       <= 48'sd0;
            z       <= 32'sd0;
            iter    <= 5'd0;
            angle   <= 32'sd0;
            done    <= 1'b0;
            sign_x  <= 1'b0;
            sign_y  <= 1'b0;
            x_zero  <= 1'b0;
            y_zero  <= 1'b0;
        end else begin
            state <= next_state;

            // Default strobes
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Latch inputs
                        x0     <= real_in_s;
                        y0     <= imag_in_s;

                        // Basic sign/zero flags for quadrant logic
                        sign_x <= real_in_s[31];
                        sign_y <= imag_in_s[31];
                        x_zero <= (real_in_s == 32'sd0);
                        y_zero <= (imag_in_s == 32'sd0);

                        // Initialize for CORDIC vectoring mode:
                        // Start (x,y) from input, z = 0
                        x      <= {{16{real_in_s[31]}}, real_in_s};
                        y      <= {{16{imag_in_s[31]}}, imag_in_s};
                        z      <= 32'sd0;
                        iter   <= 5'd0;
                    end
                end

                S_PREP: begin
                    // Handle special / quadrant-adjust cases at start of operation.
                    // Priority: pure axes, then general vectoring.
                    if (x_zero && y_zero) begin
                        // Angle undefined; return 0
                        angle <= 32'sd0;
                    end else if (x_zero) begin
                        // Pure imaginary: angle = +/-pi/2
                        if (sign_y)
                            angle <= -32'sh00019220; // -pi/2 ~= -1.570796327 * 65536 = -0x00019220
                        else
                            angle <=  32'sh00019220; // +pi/2
                    end else if (y_zero) begin
                        // Pure real: 0 or pi
                        if (sign_x)
                            angle <= CONST_PI;       // pi
                        else
                            angle <= 32'sd0;          // 0
                    end else begin
                        // For general case, initial (x,y,z) already loaded in S_IDLE.
                        // For standard vectoring CORDIC, no extra pre-rotation is required;
                        // algorithm naturally provides atan2 via sign of x across iterations.
                        // Proceed directly into iterations.
                    end
                end

                S_ITER: begin
                    // Perform one CORDIC vectoring iteration when not a trivial-axis case.
                    // Use sign of current y to drive rotation direction.
                    if (!(x_zero || (x_zero && y_zero) || (y_zero && !x_zero))) begin
                        if (y[47]) begin
                            // y < 0: rotate up
                            x   <= x - (y >>> iter);
                            y   <= y + (x >>> iter);
                            z   <= z - atan_table[iter];
                        end else begin
                            // y >= 0: rotate down
                            x   <= x + (y >>> iter);
                            y   <= y - (x >>> iter);
                            z   <= z + atan_table[iter];
                        end
                        iter <= iter + 5'd1;
                    end
                end

                S_DONE: begin
                    // Finalize output.
                    // For trivial axis cases, angle already assigned in S_PREP.
                    // For general case, z holds atan2(imag, real) in range [-pi, pi].
                    if (!(x_zero || (x_zero && y_zero) || (y_zero && !x_zero))) begin
                        // Ensure within [-pi, pi]; clamp if any slight overrun.
                        if (z > CONST_PI)
                            angle <= CONST_PI;
                        else if (z < CONST_NEG_PI)
                            angle <= CONST_NEG_PI;
                        else
                            angle <= z;
                    end
                    done <= 1'b1; // single cycle pulse
                end

                default: begin
                end
            endcase
        end
    end

    // Next-state logic
    always @* begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_PREP;
            end

            S_PREP: begin
                // If trivial cases, go directly to DONE next.
                if ((x_zero && y_zero) || x_zero || y_zero)
                    next_state = S_DONE;
                else
                    next_state = S_ITER;
            end

            S_ITER: begin
                // Run exactly 16 iterations (iter 0..15)
                if (iter == 5'd16)
                    next_state = S_DONE;
                else
                    next_state = S_ITER;
            end

            S_DONE: begin
                // Return to IDLE; new start can be accepted next cycle
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule