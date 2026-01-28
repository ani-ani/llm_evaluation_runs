module MaxPolygonArea(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] lengths [0:15],
    input wire [3:0] valid_count,
    output reg [15:0] area,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] SORT      = 4'd2;
    localparam [3:0] DP_INIT   = 4'd3;
    localparam [3:0] DP_LOOP   = 4'd4;
    localparam [3:0] DP_CHECK  = 4'd5;
    localparam [3:0] DP_AREA   = 4'd6;
    localparam [3:0] DP_MAX    = 4'd7;
    localparam [3:0] SQRT      = 4'd8;
    localparam [3:0] FINISH    = 4'd9;

    reg [3:0] state, next_state;

    // Internal registers
    reg [7:0] sorted_lengths [0:15];
    reg [15:0] current_mask;
    reg [3:0] subset_size;
    reg [15:0] subset_sum;
    reg [7:0] max_len;
    reg [15:0] semi_perimeter;
    reg [31:0] product;
    reg [15:0] current_area;
    reg [15:0] max_area;
    reg [15:0] sqrt_input;
    reg [15:0] sqrt_result;

    // Sorting registers
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [7:0] temp_length;

    // DP registers
    reg [15:0] mask;
    reg [3:0] bit_count;
    reg [3:0] bit_index;
    reg [15:0] temp_sum;
    reg [7:0] temp_len;

    // Square root registers
    reg [15:0] x;
    reg [15:0] y;
    reg [3:0] sqrt_iter;

    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            area <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 10'd0;

            // Initialize all internal registers
            for (integer i = 0; i < 16; i = i + 1) begin
                sorted_lengths[i] <= 8'd0;
            end
            current_mask <= 16'd0;
            subset_size <= 4'd0;
            subset_sum <= 16'd0;
            max_len <= 8'd0;
            semi_perimeter <= 16'd0;
            product <= 32'd0;
            current_area <= 16'd0;
            max_area <= 16'd0;
            sqrt_input <= 16'd0;
            sqrt_result <= 16'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            temp_length <= 8'd0;
            mask <= 16'd0;
            bit_count <= 4'd0;
            bit_index <= 4'd0;
            temp_sum <= 16'd0;
            temp_len <= 8'd0;
            x <= 16'd0;
            y <= 16'd0;
            sqrt_iter <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        next_state <= LOAD;
                        ready <= 1'b0;
                    end
                end

                LOAD: begin
                    // Load input lengths
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (i < valid_count)
                            sorted_lengths[i] <= lengths[i];
                        else
                            sorted_lengths[i] <= 8'd0;
                    end
                    next_state <= SORT;
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                end

                SORT: begin
                    // Bubble sort - outer loop
                    if (sort_i < valid_count - 1) begin
                        if (sort_j < valid_count - sort_i - 1) begin
                            // Compare and swap
                            if (sorted_lengths[sort_j] < sorted_lengths[sort_j + 1]) begin
                                temp_length <= sorted_lengths[sort_j];
                                sorted_lengths[sort_j] <= sorted_lengths[sort_j + 1];
                                sorted_lengths[sort_j + 1] <= temp_length;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    current_mask <= 16'd0;
                    max_area <= 16'd0;
                    next_state <= DP_LOOP;
                end

                DP_LOOP: begin
                    if (current_mask < (16'd1 << valid_count)) begin
                        mask <= current_mask;
                        bit_count <= 4'd0;
                        bit_index <= 4'd0;
                        temp_sum <= 16'd0;
                        max_len <= 8'd0;
                        next_state <= DP_CHECK;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                DP_CHECK: begin
                    // Count bits and calculate sum
                    if (bit_index < valid_count) begin
                        if (mask[bit_index]) begin
                            bit_count <= bit_count + 1;
                            temp_len <= sorted_lengths[bit_index];
                            temp_sum <= temp_sum + temp_len;
                            if (temp_len > max_len) begin
                                max_len <= temp_len;
                            end
                        end
                        bit_index <= bit_index + 1;
                    end else begin
                        subset_size <= bit_count;
                        subset_sum <= temp_sum;
                        if (subset_size >= 3) begin
                            // Check polygon inequality
                            if (max_len < (subset_sum - max_len)) begin
                                semi_perimeter <= subset_sum >> 1;
                                product <= 32'd1;
                                next_state <= DP_AREA;
                                bit_index <= 4'd0;
                            end else begin
                                next_state <= DP_MAX;
                            end
                        end else begin
                            next_state <= DP_MAX;
                        end
                    end
                end

                DP_AREA: begin
                    // Calculate product of (S - a_i)
                    if (bit_index < valid_count) begin
                        if (mask[bit_index]) begin
                            temp_len <= sorted_lengths[bit_index];
                            if (semi_perimeter > temp_len) begin
                                product <= product * (semi_perimeter - temp_len);
                            end else begin
                                product <= 32'd0;
                            end
                        end
                        bit_index <= bit_index + 1;
                    end else begin
                        // Calculate area = sqrt(product) / 4^(N-2)
                        // For Q8.8, we'll use sqrt_input = product >> (16 - subset_size)
                        sqrt_input <= product[31:16];
                        next_state <= SQRT;
                        x <= 16'd0;
                        y <= sqrt_input;
                        sqrt_iter <= 4'd0;
                    end
                end

                SQRT: begin
                    // Newton-Raphson square root approximation
                    if (sqrt_iter < 8) begin
                        if (x !== 16'd0) begin
                            y <= (x + (sqrt_input / x)) >> 1;
                        end else begin
                            y <= sqrt_input >> 1;
                        end
                        x <= y;
                        sqrt_iter <= sqrt_iter + 1;
                    end else begin
                        sqrt_result <= y;
                        // Scale for Q8.8 output
                        current_area <= sqrt_result >> (8 - (subset_size >> 1));
                        next_state <= DP_MAX;
                    end
                end

                DP_MAX: begin
                    // Update max area
                    if (current_area > max_area) begin
                        max_area <= current_area;
                    end
                    current_mask <= current_mask + 1;
                    next_state <= DP_LOOP;
                end

                FINISH: begin
                    area <= max_area;
                    done <= 1'b1;
                    ready <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end

    // Timeout check
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state !== IDLE) begin
            next_state <= IDLE;
            ready <= 1'b1;
            done <= 1'b1;
            area <= 16'd0;
        end
    end

endmodule