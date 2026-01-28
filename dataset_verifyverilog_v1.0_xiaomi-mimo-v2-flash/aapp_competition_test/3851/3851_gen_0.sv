module CircularTraversalSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [9:0] k,
    input wire [8:0] a,
    input wire [8:0] b,
    output reg [31:0] result_min,
    output reg [31:0] result_max,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] SETUP        = 4'd1;
    localparam [3:0] COMPUTE_L    = 4'd2;
    localparam [3:0] GCD_START    = 4'd3;
    localparam [3:0] GCD_LOOP     = 4'd4;
    localparam [3:0] CALC_STOPS   = 4'd5;
    localparam [3:0] UPDATE_MIN   = 4'd6;
    localparam [3:0] UPDATE_MAX   = 4'd7;
    localparam [3:0] NEXT_ITER    = 4'd8;
    localparam [3:0] DONE_STATE   = 4'd9;

    reg [3:0] state, next_state;

    // Internal registers
    reg [15:0] C;              // Circumference: n * k (max 64*1024=65536)
    reg [5:0] i_counter;       // Iteration counter 0..n-1
    reg [1:0] offset_idx;      // 0: +a/+b, 1: +a/-b, 2: -a/+b, 3: -a/-b
    
    // Temporary storage for L calculation
    reg signed [16:0] s_offset; // -512 to 65536+512
    reg signed [16:0] p_offset;
    reg [15:0] L;              // Absolute distance
    reg [15:0] gcd_a, gcd_b;   // For GCD computation
    reg [15:0] gcd_temp;
    reg [15:0] g_result;       // GCD result
    reg [31:0] stops;          // C / g
    reg [31:0] cycle_count;    // Safety counter
    localparam [31:0] MAX_CYCLES = 32'd10000;

    // For GCD loop
    reg gcd_done_flag;

    // Helper: signed absolute
    wire [15:0] abs_val;
    assign abs_val = (s_offset < 0) ? -s_offset[15:0] : s_offset[15:0];

    // Helper: convert p_offset - s_offset mod C to positive
    wire signed [16:0] diff_temp;
    assign diff_temp = p_offset - s_offset;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_min <= 32'hFFFF_FFFF; // Initialize to max
            result_max <= 32'd0;
            done <= 1'b0;
            i_counter <= 6'd0;
            offset_idx <= 2'd0;
            C <= 16'd0;
            L <= 16'd0;
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            g_result <= 16'd0;
            stops <= 32'd0;
            cycle_count <= 32'd0;
            s_offset <= 17'sd0;
            p_offset <= 17'sd0;
            gcd_done_flag <= 1'b0;
        end else begin
            // Safety counter
            if (state != IDLE && state != DONE_STATE)
                cycle_count <= cycle_count + 32'd1;
            else
                cycle_count <= 32'd0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                        result_min <= 32'hFFFF_FFFF;
                        result_max <= 32'd0;
                        i_counter <= 6'd0;
                        offset_idx <= 2'd0;
                        C <= n * k; // 15-bit max
                    end
                end

                SETUP: begin
                    // Calculate s_offset and p_offset based on i and offset_idx
                    // s = (i*k) mod C, then +/- a
                    // p = (i*k) mod C, then +/- b
                    case (offset_idx)
                        2'd0: begin // +a, +b
                            s_offset <= {1'b0, (i_counter * k)} + {8'd0, a};
                            p_offset <= {1'b0, (i_counter * k)} + {8'd0, b};
                        end
                        2'd1: begin // +a, -b
                            s_offset <= {1'b0, (i_counter * k)} + {8'd0, a};
                            p_offset <= {1'b0, (i_counter * k)} - {8'd0, b};
                        end
                        2'd2: begin // -a, +b
                            s_offset <= {1'b0, (i_counter * k)} - {8'd0, a};
                            p_offset <= {1'b0, (i_counter * k)} + {8'd0, b};
                        end
                        2'd3: begin // -a, -b
                            s_offset <= {1'b0, (i_counter * k)} - {8'd0, a};
                            p_offset <= {1'b0, (i_counter * k)} - {8'd0, b};
                        end
                    endcase
                    state <= COMPUTE_L;
                end

                COMPUTE_L: begin
                    // L = (p - s) mod C
                    // diff_temp = p_offset - s_offset
                    // We need positive value modulo C
                    if (diff_temp < 0) begin
                        // (diff + C) mod C. But diff is negative small (-1024 to 1024)
                        // Just add C twice to be safe, then mod C is just take lower bits if we know it's positive
                        L <= (diff_temp + {1'b0, C} + 17'sd1024)[15:0] % C;
                    end else begin
                        L <= diff_temp[15:0] % C;
                    end
                    gcd_done_flag <= 1'b0;
                    state <= GCD_START;
                end

                GCD_START: begin
                    // Skip L=0 (start and stop same position)
                    if (L == 16'd0) begin
                        state <= NEXT_ITER;
                    end else begin
                        // Initialize GCD: gcd(C, L)
                        gcd_a <= C;
                        gcd_b <= L;
                        state <= GCD_LOOP;
                    end
                end

                GCD_LOOP: begin
                    // Euclidean algorithm
                    if (!gcd_done_flag) begin
                        if (gcd_b == 16'd0) begin
                            g_result <= gcd_a;
                            gcd_done_flag <= 1'b1;
                        end else begin
                            if (gcd_a > gcd_b) begin
                                gcd_a <= gcd_b;
                                gcd_b <= gcd_a % gcd_b;
                            end else begin
                                gcd_b <= gcd_b % gcd_a;
                            end
                        end
                    end else begin
                        state <= CALC_STOPS;
                    end
                    // Loop until done
                    if (gcd_b == 16'd0 && !gcd_done_flag) begin
                         state <= CALC_STOPS;
                         g_result <= gcd_a;
                    end else if (gcd_a == 16'd0 && gcd_b == 16'd0) begin
                         // Should not happen if L!=0
                         state <= NEXT_ITER;
                    end
                end

                CALC_STOPS: begin
                    stops <= C / g_result;
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    if (stops < result_min) begin
                        result_min <= stops;
                    end
                    state <= UPDATE_MAX;
                end

                UPDATE_MAX: begin
                    if (stops > result_max) begin
                        result_max <= stops;
                    end
                    state <= NEXT_ITER;
                end

                NEXT_ITER: begin
                    // Check if all combinations done
                    if (offset_idx == 2'd3) begin
                        offset_idx <= 2'd0;
                        if (i_counter == n - 6'd1) begin
                            state <= DONE_STATE;
                        end else begin
                            i_counter <= i_counter + 6'd1;
                            state <= SETUP;
                        end
                    end else begin
                        offset_idx <= offset_idx + 2'd1;
                        state <= SETUP;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Timeout safety
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
            end
        end
    end

endmodule