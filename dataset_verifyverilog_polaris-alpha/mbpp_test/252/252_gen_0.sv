module complex_to_polar (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] real_part,   // Q16.16 signed
    input  wire [31:0] imag_part,   // Q16.16 signed
    output reg  [31:0] magnitude,   // Q16.16
    output reg  [31:0] phase,       // Q16.16 (-pi..pi)
    output reg         done
);

    // Signed views for inputs
    wire signed [31:0] real_in  = real_part;
    wire signed [31:0] imag_in  = imag_part;

    // FSM states
    localparam IDLE  = 2'd0;
    localparam CORDIC = 2'd1;
    localparam DONE  = 2'd2;

    reg [1:0] state, next_state;

    // Start edge detection
    reg start_d;
    wire start_rise = start & ~start_d;

    // CORDIC iteration index
    reg [5:0] iter; // 0..31

    // Internal CORDIC registers (Q16.16 signed)
    reg signed [31:0] x_reg; // will converge to magnitude * K
    reg signed [31:0] y_reg; // will converge to 0
    reg signed [31:0] z_reg; // angle accumulator

    // Working absolute value and quadrant handling
    reg signed [31:0] x0;
    reg signed [31:0] y0;
    reg signed [31:0] z0;

    // Precomputed constants (Q16.16)
    // pi = 3.14159265 -> 0x0003243F
    localparam signed [31:0] PI      = 32'sh0003_243F;
    localparam signed [31:0] NEG_PI  = -32'sh0003_243F;
    localparam signed [31:0] PI_BY_2 = 32'sh0001_921F;  // pi/2
    localparam signed [31:0] PI_MUL_3_DIV_2 = 32'sh0004_B65E; // 3*pi/2 (not used, but kept for clarity)

    // CORDIC gain K for 32 iterations (approx 0.607252935)
    // Q16.16: 0.607252935 * 2^16 ≈ 0x00009B74
    localparam signed [31:0] CORDIC_K = 32'sh0000_9B74;

    // atan table in Q16.16 for i = 0..31: atan(2^-i)
    // Values computed and truncated to 32-bit signed Q16.16
    localparam signed [31:0] atan_table [0:31] = '{
        32'sh0000_C910, // atan(2^-0)  = 0.785398163397
        32'sh0000_76B1, // atan(2^-1)  = 0.463647609001
        32'sh0000_3EB6, // atan(2^-2)  = 0.244978663127
        32'sh0000_1FD5, // atan(2^-3)  = 0.124354994547
        32'sh0000_0FFA, // atan(2^-4)  = 0.062418809996
        32'sh0000_07FF, // atan(2^-5)  = 0.031239833430
        32'sh0000_03FF, // atan(2^-6)  = 0.015623728620
        32'sh0000_01FF, // atan(2^-7)  = 0.007812341061
        32'sh0000_00FF, // atan(2^-8)  = 0.003906230132
        32'sh0000_007F, // atan(2^-9)  = 0.001953122516
        32'sh0000_003F, // atan(2^-10) = 0.000976562189
        32'sh0000_001F, // atan(2^-11) = 0.000488281211
        32'sh0000_000F, // atan(2^-12) = 0.000244140620
        32'sh0000_0007, // atan(2^-13) = 0.000122070312
        32'sh0000_0003, // atan(2^-14) = 0.000061035156
        32'sh0000_0001, // atan(2^-15) = 0.000030517578
        32'sh0000_0001, // atan(2^-16)
        32'sh0000_0000, // atan(2^-17)
        32'sh0000_0000, // atan(2^-18)
        32'sh0000_0000, // atan(2^-19)
        32'sh0000_0000, // atan(2^-20)
        32'sh0000_0000, // atan(2^-21)
        32'sh0000_0000, // atan(2^-22)
        32'sh0000_0000, // atan(2^-23)
        32'sh0000_0000, // atan(2^-24)
        32'sh0000_0000, // atan(2^-25)
        32'sh0000_0000, // atan(2^-26)
        32'sh0000_0000, // atan(2^-27)
        32'sh0000_0000, // atan(2^-28)
        32'sh0000_0000, // atan(2^-29)
        32'sh0000_0000, // atan(2^-30)
        32'sh0000_0000  // atan(2^-31)
    };

    // FSM next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_rise)
                    next_state = CORDIC;
            end
            CORDIC: begin
                if (iter == 6'd31)
                    next_state = DONE;
            end
            DONE: begin
                if (start_rise)
                    next_state = CORDIC;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            start_d    <= 1'b0;
            iter       <= 6'd0;
            x_reg      <= 32'sd0;
            y_reg      <= 32'sd0;
            z_reg      <= 32'sd0;
            x0         <= 32'sd0;
            y0         <= 32'sd0;
            z0         <= 32'sd0;
            magnitude  <= 32'sd0;
            phase      <= 32'sd0;
            done       <= 1'b0;
        end else begin
            // register start for edge detect
            start_d <= start;

            state <= next_state;

            case (state)
                IDLE: begin
                    done <= (done & ~start_rise); // clear done on new start
                    if (start_rise) begin
                        // Prepare inputs for CORDIC: abs, initial angle
                        // Handle special cases for quadrant using atan2 rules
                        if (real_in == 32'sd0 && imag_in == 32'sd0) begin
                            x0 <= 32'sd0;
                            y0 <= 32'sd0;
                            z0 <= 32'sd0;
                        end else begin
                            // Start with vector (abs(real), abs(imag)), adjust z0 for quadrant
                            // Basic: use initial angle from signs
                            if (real_in > 0) begin
                                // x > 0: angle based solely on CORDIC result
                                x0 <= (real_in[31]) ? -real_in : real_in; // abs(real)
                                y0 <= (imag_in[31]) ? -imag_in : imag_in; // abs(imag)
                                if (imag_in < 0)
                                    z0 <= -32'sd0;
                                else
                                    z0 <= 32'sd0;
                            end else if (real_in < 0) begin
                                // x < 0: atan2 adjustment by +/-pi
                                x0 <= (real_in[31]) ? -real_in : real_in;
                                y0 <= (imag_in[31]) ? -imag_in : imag_in;
                                if (imag_in >= 0)
                                    z0 <= PI;   // y>=0, x<0 -> +pi
                                else
                                    z0 <= NEG_PI; // y<0, x<0 -> -pi
                            end else begin
                                // real_in == 0
                                x0 <= (real_in[31]) ? -real_in : real_in; // 0
                                y0 <= (imag_in[31]) ? -imag_in : imag_in;
                                if (imag_in > 0)
                                    z0 <= PI_BY_2;    // +pi/2
                                else if (imag_in < 0)
                                    z0 <= -PI_BY_2;   // -pi/2
                                else
                                    z0 <= 32'sd0;     // already handled above (0,0)
                            end
                        end

                        // Initialize CORDIC registers
                        x_reg <= ((real_in[31]) ? -real_in : real_in); // |real|
                        y_reg <= ((imag_in[31]) ? -imag_in : imag_in); // |imag|
                        z_reg <= z0; // quadrant base
                        iter  <= 6'd0;
                    end
                end

                CORDIC: begin
                    // Perform one CORDIC vectoring iteration per cycle
                    // Direction depends on sign of y_reg (drive towards zero)
                    if (y_reg[31] == 1'b0) begin
                        // y >= 0: rotate clockwise
                        x_reg <= x_reg + (y_reg >>> iter);
                        y_reg <= y_reg - (x_reg >>> iter);
                        z_reg <= z_reg + atan_table[iter];
                    end else begin
                        // y < 0: rotate counter-clockwise
                        x_reg <= x_reg - (y_reg >>> iter);
                        y_reg <= y_reg + (x_reg >>> iter);
                        z_reg <= z_reg - atan_table[iter];
                    end

                    if (iter != 6'd31)
                        iter <= iter + 6'd1;
                end

                DONE: begin
                    // Latch outputs once when entering DONE
                    if (state != DONE) begin
                        // Protect: but this block executes only after transition
                    end
                    // Keep outputs stable until next start
                    done <= 1'b1;
                end

                default: ;
            endcase

            // On transition into DONE (from CORDIC when iter == 31)
            if (state == CORDIC && next_state == DONE) begin
                // Compute magnitude = |x_reg| / K (since CORDIC gain)
                // x_reg is Q16.16, CORDIC_K is Q16.16
                // magnitude = (x_reg << 16) / CORDIC_K -> Q16.16
                // Implement as signed division (synthesis-friendly if tool supports)
                // Guard sign, but x_reg should be >=0 for vectoring mode
                if (x_reg[31]) begin
                    magnitude <= 32'sd0;
                end else begin
                    magnitude <= ( (x_reg <<< 16) / CORDIC_K );
                end

                // Phase is z_reg (already Q16.16 within [-pi, pi])
                phase <= z_reg;

                done <= 1'b1;
            end
        end
    end

endmodule