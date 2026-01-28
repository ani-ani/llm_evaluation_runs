module luggage_collision_avoidance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] L_val,
    input wire [3:0] N_val,
    input wire [15:0] pos [0:7],
    output reg [15:0] result,
    output reg valid,
    output reg no_fika
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BINARY_SEARCH = 3'd2;
    localparam [2:0] CHECK_COLLISION = 3'd3;
    localparam [2:0] SORT_TIMES = 3'd4;
    localparam [2:0] COMPUTE_DISTANCES = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;

    // Binary search parameters
    reg [15:0] low, high, mid;
    reg [5:0] iteration_count;
    localparam [5:0] MAX_ITERATIONS = 6'd64;

    // Internal registers for positions and times
    reg [15:0] x [0:7];
    reg [31:0] t [0:7];
    reg [3:0] N;
    reg [7:0] L;

    // Sorting variables
    reg [3:0] i, j;
    reg [31:0] temp_time;

    // Collision check variables
    reg collision_detected;
    reg [31:0] diff;

    // Fixed-point constants
    localparam [15:0] MIN_V = 16'd64;      // 0.1 * 64
    localparam [15:0] MAX_V = 16'd640;     // 10 * 64
    localparam [31:0] ONE_METER = 32'd64;   // 1 * 64

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            valid <= 1'b0;
            no_fika <= 1'b0;
            iteration_count <= 6'd0;
            low <= MIN_V;
            high <= MAX_V;
            N <= 4'd0;
            L <= 8'd0;
            collision_detected <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Load inputs
                N = N_val;
                L = L_val;
                // Copy positions
                integer k;
                for (k = 0; k < 8; k = k + 1) begin
                    x[k] = pos[k];
                end
                // Initialize binary search
                low = MIN_V;
                high = MAX_V;
                iteration_count = 6'd0;
                next_state = BINARY_SEARCH;
            end

            BINARY_SEARCH: begin
                if (iteration_count < MAX_ITERATIONS) begin
                    mid = (low + high) >> 1;
                    // Compute times t_i = x_i / v
                    integer k;
                    for (k = 0; k < N; k = k + 1) begin
                        if (mid != 16'd0) begin
                            t[k] = (x[k] << 16) / mid;  // Q16.16 division
                        end else begin
                            t[k] = 32'd0;
                        end
                    end
                    next_state = SORT_TIMES;
                end else begin
                    // Check if we found a valid v
                    if (low > MIN_V && !collision_detected) begin
                        result = low;
                        valid = 1'b1;
                        no_fika = 1'b0;
                    end else begin
                        result = 16'd32767;  // 0x7FFF
                        valid = 1'b1;
                        no_fika = 1'b1;
                    end
                    next_state = FINISH;
                end
            end

            SORT_TIMES: begin
                // Insertion sort for t[0..N-1]
                if (i < N) begin
                    temp_time = t[i];
                    j = i;
                    while (j > 0 && t[j - 1] > temp_time) begin
                        t[j] = t[j - 1];
                        j = j - 1;
                    end
                    t[j] = temp_time;
                    i = i + 1;
                end else begin
                    i = 4'd0;
                    j = 4'd0;
                    next_state = COMPUTE_DISTANCES;
                end
            end

            COMPUTE_DISTANCES: begin
                collision_detected = 1'b0;
                if (i < N - 1) begin
                    diff = t[i + 1] - t[i];
                    if (diff <= ONE_METER) begin
                        collision_detected = 1'b1;
                    end
                    i = i + 1;
                end else begin
                    // Check wrap-around
                    diff = (t[0] + (L << 16)) - t[N - 1];
                    if (diff <= ONE_METER) begin
                        collision_detected = 1'b1;
                    end
                    // Update binary search bounds
                    if (collision_detected) begin
                        high = mid;
                    end else begin
                        low = mid;
                    end
                    iteration_count = iteration_count + 6'd1;
                    i = 4'd0;
                    next_state = BINARY_SEARCH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule