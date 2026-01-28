module critic_ordering(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [7:0] m,
    input wire [15:0] k,
    input wire [7:0] a [0:15],
    output reg [4:0] p [0:15],
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [9:0] iteration_count;
    reg [4:0] current_index;
    reg [4:0] temp_p [0:15];
    reg [15:0] current_sum;
    reg [7:0] current_avg;
    reg [7:0] critics_seen;
    reg found_valid;

    // Constants
    localparam [9:0] MAX_ITERATIONS = 10'd1024;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iteration_count <= 10'd0;
            current_index <= 5'd0;
            current_sum <= 16'd0;
            current_avg <= 8'd0;
            critics_seen <= 8'd0;
            found_valid <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;

            // Initialize permutation array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                p[i] <= 5'd0;
                temp_p[i] <= 5'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    iteration_count <= 10'd0;
                    current_index <= 5'd0;
                    current_sum <= 16'd0;
                    critics_seen <= 8'd0;
                    found_valid <= 1'b0;

                    // Initialize permutation (simple sequential for this example)
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_p[i] <= i;
                    end

                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    // Calculate current average (Q8.8 format)
                    if (critics_seen > 8'd0) begin
                        current_avg <= (current_sum << 8) / critics_seen;
                    end else begin
                        current_avg <= 8'd0;
                    end

                    // Determine score for current critic
                    reg [7:0] current_score;
                    if (current_index == 5'd0) begin
                        current_score <= m;  // First critic always scores m
                    end else begin
                        if (current_avg <= a[temp_p[current_index]]) begin
                            current_score <= m;
                        end else begin
                            current_score <= 8'd0;
                        end
                    end

                    // Update sum and critics seen
                    current_sum <= current_sum + current_score;
                    critics_seen <= critics_seen + 8'd1;

                    // Move to next critic or check result
                    if (current_index == n - 5'd1) begin
                        next_state <= CHECK;
                    end else begin
                        current_index <= current_index + 5'd1;
                        next_state <= COMPUTE;
                    end
                end

                CHECK: begin
                    // Check if we found a valid solution
                    if (current_sum == k) begin
                        found_valid <= 1'b1;
                        valid <= 1'b1;

                        // Copy the valid permutation to output
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            p[i] <= temp_p[i];
                        end

                        next_state <= FINISH;
                    end else begin
                        // Try next permutation (simple increment for this example)
                        iteration_count <= iteration_count + 10'd1;

                        if (iteration_count >= MAX_ITERATIONS) begin
                            next_state <= FINISH;
                        end else begin
                            // Generate next permutation (simple rotation for this example)
                            integer i;
                            reg [4:0] last;
                            last <= temp_p[15];
                            for (i = 15; i > 0; i = i - 1) begin
                                temp_p[i] <= temp_p[i - 1];
                            end
                            temp_p[0] <= last;

                            // Reset computation state
                            current_index <= 5'd0;
                            current_sum <= 16'd0;
                            critics_seen <= 8'd0;
                            next_state <= COMPUTE;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule