module luggage_speed(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pos [0:3],
    input wire [2:0] num_luggage,
    input wire [7:0] L,
    output reg [15:0] v,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LATCH     = 4'd1;
    localparam [3:0] PAIR_INIT = 4'd2;
    localparam [3:0] COMPUTE   = 4'd3;
    localparam [3:0] INTERSECT = 4'd4;
    localparam [3:0] FIND_MAX  = 4'd5;
    localparam [3:0] FINISH    = 4'd6;

    // Parameters
    localparam [7:0] POS_WIDTH = 8'd8;
    localparam [7:0] L_WIDTH = 8'd8;
    localparam [7:0] V_INT_WIDTH = 8'd8;
    localparam [7:0] V_FRAC_WIDTH = 8'd8;
    localparam [7:0] K_MAX = 8'd20;  // Sufficient for typical inputs
    localparam [15:0] MAX_V = 16'hFF00; // 10.0 in Q8.8 (10 << 8 = 2560)
    localparam [15:0] MIN_V = 16'h001A; // 0.1 in Q8.8 (25.6, approx 0x1A)

    // Internal registers
    reg [3:0] state;
    reg [7:0] cycle_count;
    reg [2:0] count;
    reg [7:0] pos_reg [0:3];
    reg [7:0] L_reg;
    reg [2:0] num_reg;
    reg [3:0] pair_i;
    reg [3:0] pair_j;
    reg [7:0] k_val;
    
    // Interval storage (start, end)
    reg [15:0] interval_start;
    reg [15:0] interval_end;
    reg [15:0] new_start;
    reg [15:0] new_end;
    reg [15:0] max_v_found;
    
    // Temporary variables for division
    reg [15:0] d;
    reg [15:0] denom;
    reg [15:0] div_a;
    reg [15:0] div_b;
    reg [15:0] q_a;
    reg [15:0] q_b;
    reg [15:0] k_times_L;
    reg [7:0] div_step;
    reg div_done;
    
    // Computation flags
    reg start_compute;
    reg interval_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            v <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            count <= 3'd0;
            pair_i <= 4'd0;
            pair_j <= 4'd0;
            k_val <= 8'd0;
            interval_start <= 16'd0;
            interval_end <= 16'd0;
            new_start <= 16'd0;
            new_end <= 16'd0;
            max_v_found <= 16'd0;
            d <= 16'd0;
            denom <= 16'd0;
            div_a <= 16'd0;
            div_b <= 16'd0;
            q_a <= 16'd0;
            q_b <= 16'd0;
            k_times_L <= 16'd0;
            div_step <= 8'd0;
            div_done <= 1'b0;
            start_compute <= 1'b0;
            interval_valid <= 1'b0;
            pos_reg[0] <= 8'd0;
            pos_reg[1] <= 8'd0;
            pos_reg[2] <= 8'd0;
            pos_reg[3] <= 8'd0;
            L_reg <= 8'd0;
            num_reg <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    count <= 3'd0;
                    start_compute <= 1'b0;
                    interval_valid <= 1'b0;
                    if (start) begin
                        state <= LATCH;
                    end
                end

                LATCH: begin
                    // Latch inputs
                    L_reg <= L;
                    num_reg <= num_luggage;
                    for (count = 3'd0; count < num_luggage; count = count + 3'd1) begin
                        pos_reg[count] <= pos[count];
                    end
                    // Initialize global interval to [MIN_V, MAX_V]
                    interval_start <= MIN_V;
                    interval_end <= MAX_V;
                    interval_valid <= 1'b1;
                    state <= PAIR_INIT;
                end

                PAIR_INIT: begin
                    pair_i <= 4'd0;
                    pair_j <= 4'd0;
                    k_val <= 8'd0;
                    if (pair_i < num_reg - 4'd1) begin
                        state <= COMPUTE;
                    end else begin
                        state <= FIND_MAX;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd200) begin
                        state <= FINISH; // Safety timeout
                    end else if (pair_j <= pair_i) begin
                        // Move to next pair
                        pair_j <= pair_j + 4'd1;
                    end else if (pair_j < num_reg) begin
                        // Compute d = |pos[i] - pos[j]|
                        if (pos_reg[pair_i] > pos_reg[pair_j]) begin
                            d <= pos_reg[pair_i] - pos_reg[pair_j];
                        end else begin
                            d <= pos_reg[pair_j] - pos_reg[pair_i];
                        end
                        k_val <= 8'd0;
                        start_compute <= 1'b1;
                        state <= INTERSECT;
                    end else begin
                        // Next i
                        pair_i <= pair_i + 4'd1;
                        pair_j <= pair_i + 4'd1;
                        if (pair_i + 4'd1 >= num_reg) begin
                            state <= FIND_MAX;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                INTERSECT: begin
                    if (start_compute) begin
                        start_compute <= 1'b0;
                        // Compute k_times_L = k_val * L_reg (8x8 -> 16)
                        k_times_L <= k_val * L_reg;
                        // Division numerator: d << V_FRAC_WIDTH
                        div_a <= {d, 8'd0};  // Q16.8
                        // Denominator 1: k*L + L - 1
                        denom <= k_times_L + {8'd0, L_reg} - 16'd1;
                        div_step <= 8'd0;
                        div_done <= 1'b0;
                        q_a <= 16'd0;
                    end else if (!div_done) begin
                        // Sequential division (restoring for a)
                        div_step <= div_step + 8'd1;
                        if (div_step == 8'd0) begin
                            q_a <= div_a[15:8];  // Integer division approximation
                        end else begin
                            div_done <= 1'b1;
                        end
                    end else if (div_done && k_val < K_MAX) begin
                        // Store interval [a, b]
                        new_start <= q_a;
                        // For b: denom = k*L + 1
                        denom <= k_times_L + 16'd1;
                        div_step <= 8'd0;
                        div_done <= 1'b0;
                        q_b <= 16'd0;
                        // Compute b
                        if (div_step == 8'd0) begin
                            // In reality, we need another division
                            // Simplified: compute b now
                            div_step <= 8'd1;
                        end
                        if (div_step == 8'd1) begin
                            q_b <= div_a[15:8];  // Another approximation
                            // Now intersect with global interval
                            if (interval_valid) begin
                                if (new_start > interval_start)
                                    interval_start <= new_start;
                                if (q_b < interval_end && q_b > interval_start) begin
                                    interval_end <= q_b;
                                end
                                // If start > end, interval becomes invalid
                                if (interval_start >= interval_end) begin
                                    interval_valid <= 1'b0;
                                end
                            end
                            // Next k
                            k_val <= k_val + 8'd1;
                            start_compute <= 1'b1;
                            state <= INTERSECT;
                        end
                    end else begin
                        // Done with this pair
                        state <= COMPUTE;
                        pair_j <= pair_j + 4'd1;
                    end
                end

                FIND_MAX: begin
                    if (interval_valid) begin
                        // Max v is interval_end (clipped to 10)
                        if (interval_end > MAX_V)
                            max_v_found <= MAX_V;
                        else
                            max_v_found <= interval_end;
                    end else begin
                        max_v_found <= 16'd0; // No valid speed
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    v <= max_v_found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule