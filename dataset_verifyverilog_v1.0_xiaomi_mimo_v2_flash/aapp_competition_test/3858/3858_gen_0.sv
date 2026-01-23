module compute_convex_score(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire [15:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire [15:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd998244353;
    localparam [3:0] MAX_POINTS = 4'd8;
    
    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD_POINTS    = 4'd1;
    localparam [3:0] CALC_BASE      = 4'd2;
    localparam [3:0] BASE_MOD       = 4'd3;
    localparam [3:0] INIT_I_LOOP    = 4'd4;
    localparam [3:0] CHECK_I_LOOP   = 4'd5;
    localparam [3:0] INIT_J_LOOP    = 4'd6;
    localparam [3:0] CHECK_J_LOOP   = 4'd7;
    localparam [3:0] INIT_K_LOOP    = 4'd8;
    localparam [3:0] CHECK_K_LOOP   = 4'd9;
    localparam [3:0] CALC_COLLINEAR = 4'd10;
    localparam [3:0] CHECK_COLL     = 4'd11;
    localparam [3:0] CALC_SUBTRACT  = 4'd12;
    localparam [3:0] FINISH         = 4'd13;

    // Registers
    reg [3:0] state;
    reg [3:0] i, j, k;
    reg [31:0] temp_result;
    reg [31:0] n_val;
    reg signed [31:0] x_diff1, x_diff2, y_diff1, y_diff2;
    reg signed [63:0] left_mult, right_mult;
    reg [31:0] subtract_val;
    reg [31:0] pow2_k;
    reg [2:0] point_count;
    reg [31:0] x_coords [0:7];
    reg [31:0] y_coords [0:7];
    reg [31:0] cycle_counter;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // Helper signals
    reg [31:0] pow2_temp;
    reg [31:0] sub_temp;
    reg [31:0] mod_temp;
    integer ii;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_result <= 32'd0;
            n_val <= 32'd0;
            point_count <= 3'd0;
            for (ii = 0; ii < 8; ii = ii + 1) begin
                x_coords[ii] <= 32'd0;
                y_coords[ii] <= 32'd0;
            end
            pow2_temp <= 32'd0;
            sub_temp <= 32'd0;
            mod_temp <= 32'd0;
            subtract_val <= 32'd0;
            pow2_k <= 32'd0;
            x_diff1 <= 32'd0;
            x_diff2 <= 32'd0;
            y_diff1 <= 32'd0;
            y_diff2 <= 32'd0;
            left_mult <= 64'd0;
            right_mult <= 64'd0;
        end else begin
            cycle_counter <= cycle_counter + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        state <= LOAD_POINTS;
                        result <= 32'd0;
                        n_val <= {29'd0, N};
                        point_count <= N;
                    end
                end

                LOAD_POINTS: begin
                    // Load all 8 points (some may be unused)
                    x_coords[0] <= {16'd0, x0};
                    x_coords[1] <= {16'd0, x1};
                    x_coords[2] <= {16'd0, x2};
                    x_coords[3] <= {16'd0, x3};
                    x_coords[4] <= {16'd0, x4};
                    x_coords[5] <= {16'd0, x5};
                    x_coords[6] <= {16'd0, x6};
                    x_coords[7] <= {16'd0, x7};
                    y_coords[0] <= {16'd0, y0};
                    y_coords[1] <= {16'd0, y1};
                    y_coords[2] <= {16'd0, y2};
                    y_coords[3] <= {16'd0, y3};
                    y_coords[4] <= {16'd0, y4};
                    y_coords[5] <= {16'd0, y5};
                    y_coords[6] <= {16'd0, y6};
                    y_coords[7] <= {16'd0, y7};
                    state <= CALC_BASE;
                end

                CALC_BASE: begin
                    // Calculate 2^N
                    pow2_temp <= 32'd1;
                    for (ii = 0; ii < 8; ii = ii + 1) begin
                        if (ii < N) begin
                            pow2_temp <= (pow2_temp << 1);
                        end
                    end
                    // Wait one cycle for pow2_temp calculation
                    state <= BASE_MOD;
                end

                BASE_MOD: begin
                    // (2^N - 1 - N - N*(N-1)/2)
                    temp_result <= pow2_temp - 32'd1 - n_val - ((n_val * (n_val - 32'd1)) >> 1);
                    state <= INIT_I_LOOP;
                end

                INIT_I_LOOP: begin
                    i <= 4'd0;
                    state <= CHECK_I_LOOP;
                end

                CHECK_I_LOOP: begin
                    if (i < (point_count - 3'd2)) begin
                        j <= i + 4'd1;
                        state <= INIT_J_LOOP;
                    end else begin
                        state <= FINISH;
                    end
                end

                INIT_J_LOOP: begin
                    // Initialize for j loop
                    // j was set in CHECK_I_LOOP
                    state <= CHECK_J_LOOP;
                end

                CHECK_J_LOOP: begin
                    if (j < (point_count - 3'd1)) begin
                        point_count <= 3'd2; // Count collinear points (i and j)
                        k <= j + 4'd1;
                        state <= INIT_K_LOOP;
                    end else begin
                        i <= i + 4'd1;
                        state <= CHECK_I_LOOP;
                    end
                end

                INIT_K_LOOP: begin
                    // k already incremented
                    state <= CHECK_K_LOOP;
                end

                CHECK_K_LOOP: begin
                    if (k < point_count) begin
                        // Check collinearity
                        x_diff1 <= x_coords[j] - x_coords[i];
                        y_diff1 <= y_coords[k] - y_coords[i];
                        x_diff2 <= x_coords[k] - x_coords[i];
                        y_diff2 <= y_coords[j] - y_coords[i];
                        state <= CALC_COLLINEAR;
                    end else begin
                        // Done with this (i,j), check if we found collinear points
                        if (point_count > 3'd2) begin
                            // Calculate subtraction value for found collinear points
                            // 2^point_count - 1 - point_count - point_count*(point_count-1)/2
                            pow2_k <= 32'd1;
                            for (ii = 0; ii < 8; ii = ii + 1) begin
                                if (ii < point_count) begin
                                    pow2_k <= (pow2_k << 1);
                                end
                            end
                            state <= CALC_SUBTRACT;
                        end else begin
                            j <= j + 4'd1;
                            state <= CHECK_J_LOOP;
                        end
                    end
                end

                CALC_COLLINEAR: begin
                    // Check: (x_j-x_i)*(y_k-y_i) == (x_k-x_i)*(y_j-y_i)
                    left_mult <= x_diff1 * y_diff1;
                    right_mult <= x_diff2 * y_diff2;
                    state <= CHECK_COLL;
                end

                CHECK_COLL: begin
                    if (left_mult == right_mult) begin
                        point_count <= point_count + 3'd1;
                    end
                    k <= k + 4'd1;
                    state <= CHECK_K_LOOP;
                end

                CALC_SUBTRACT: begin
                    // Calculate subtraction value
                    subtract_val <= pow2_k - 32'd1 - point_count - ((point_count * (point_count - 3'd1)) >> 1);
                    // Wait one cycle
                    state <= IDLE; // Temp state to process subtraction
                end

                // Need intermediate state for subtraction processing
                // Actually let's add a new state after CALC_SUBTRACT
                default: state <= IDLE;
            endcase
        end
    end

    // Additional always block for subtraction and modulo
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            if (state == CALC_SUBTRACT) begin
                // This will execute after CALC_SUBTRACT sets up subtract_val
            end
            else if (state == IDLE && cycle_counter > 16'd0 && start == 1'b0) begin
                // We hijack the IDLE state for processing subtraction
                // Need to find a better way - add a new state
            end
        end
    end

endmodule
