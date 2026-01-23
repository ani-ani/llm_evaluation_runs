module right_triangle_counter (
input clk,
input rst_n, // active-low reset
input start,
input signed [15:0] points [0:7],
output reg [7:0] count,
output reg done
);

// State machine parameters
localparam IDLE = 2'd0, PROCESSING = 2'd1, WAIT = 2'd2, DONE_STATE = 2'd3;
reg [1:0] state;
reg [6:0] i, j, k;
reg [7:0] total_count, delay_counter;
reg [6:0] loop_counter; // Counts processed triplets (0-55)

// Default assignments on reset
always @(*) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 0;
        j <= 0;
        k <= 0;
        total_count <= 0;
        delay_counter <= 0;
        loop_counter <= 0;
        done <= 0;
    end
end

// State machine logic
always @(*) begin
    if (state == IDLE) begin
        if (start) begin
            state <= PROCESSING;
            i <= 0;
            j <= i + 1;
            k <= j + 1;
            loop_counter <= 0;
            total_count <= 0;
            delay_counter <= 0;
        end
        done <= 0;
    end else if (state == PROCESSING) begin
        if (loop_counter == 56) begin
            // All triplets processed, move to WAIT
            state <= WAIT;
            delay_counter <= 199; // 256 - 56 = 200 delay (adjusted to 199 for correct latency)
        end else begin
            // Process current triplet i,j,k
            // Check if indices are valid (i < j < k <8)
            if (k < 8) begin
                // Extract coordinates
                int x_i = points[2*i], y_i = points[2*i +1];
                int x_j = points[2*j], y_j = points[2*j +1];
                int x_k = points[2*k], y_k = points[2*k +1];

                // Calculate vectors and dot products for all three angles
                int dot_i, dot_j, dot_k;

                // Right angle at i
                int dx_ji = x_j - x_i;
                int dy_ji = y_j - y_i;
                int dx_ki = x_k - x_i;
                int dy_ki = y_k - y_i;
                dot_i = dx_ji * dx_ki + dy_ji * dy_ki;

                // Right angle at j
                int dx_ij = x_i - x_j;
                int dy_ij = y_i - y_j;
                int dx_kj = x_k - x_j;
                int dy_kj = y_k - y_j;
                dot_j = dx_ij * dx_kj + dy_ij * dy_kj;

                // Right angle at k
                int dx_ki2 = x_i - x_k;
                int dy_ki2 = y_i - y_k;
                int dx_kj2 = x_j - x_k;
                int dy_kj2 = y_j - y_k;
                dot_k = dx_ki2 * dx_kj2 + dy_ki2 * dy_kj2;

                // If any dot product is zero, increment count
                if (dot_i == 0 || dot_j == 0 || dot_k == 0) begin
                    total_count <= total_count + 1;
                end

                // Move to next triplet
                loop_counter <= loop_counter + 1;

                // Update indices to next triplet
                if (k < 7) begin
                    k <= k + 1;
                end else begin
                    k <= j + 1;
                    if (j < 6) begin
                        j <= j + 1;
                    end else begin
                        j <= i + 1;
                        if (i < 6) begin
                            i <= i + 1;
                        end
                    end
                end
            end
        end
        done <= 0;
    end else if (state == WAIT) begin
        if (delay_counter == 0) begin
            state <= DONE_STATE;
            done <= 1;
        end else begin
            delay_counter <= delay_counter - 1;
            done <= 0;
        end
    end else if (state == DONE_STATE) begin
        done <= 1;
    end
end

endmodule