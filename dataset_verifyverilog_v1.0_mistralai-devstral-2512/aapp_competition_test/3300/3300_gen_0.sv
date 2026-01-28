module cheetah_pack(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_valid,
    input wire [31:0] t_arr [0:15],
    input wire [31:0] v_arr [0:15],
    output reg [31:0] min_length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONVERT = 3'd1;
    localparam [2:0] COMPUTE_TSTART = 3'd2;
    localparam [2:0] COMPUTE_LENGTHS = 3'd3;
    localparam [2:0] FIND_MIN = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [31:0] t_q16 [0:15];
    reg [31:0] v_q16 [0:15];
    reg [31:0] t_start;
    reg [31:0] current_length;
    reg [31:0] min_length_reg;
    reg [31:0] num, den;
    reg [31:0] t_int;
    reg [31:0] pos [0:15];
    reg [31:0] max_pos, min_pos;

    // Counters
    reg [3:0] i, j, k;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // Division state
    localparam [1:0] DIV_IDLE = 2'd0;
    localparam [1:0] DIV_COMPUTE = 2'd1;
    reg [1:0] div_state;
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [31:0] divisor;
    reg [31:0] dividend;
    reg [4:0] div_cycle;

    // Fixed-point conversion
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            min_length <= 32'd0;
            min_length_reg <= 32'd0;
            cycle_count <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            div_state <= DIV_IDLE;
            quotient <= 32'd0;
            remainder <= 32'd0;
            divisor <= 32'd0;
            dividend <= 32'd0;
            div_cycle <= 5'd0;
            for (k = 0; k < 16; k = k + 1) begin
                t_q16[k] <= 32'd0;
                v_q16[k] <= 32'd0;
                pos[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block above
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= CONVERT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CONVERT: begin
                    // Convert t and v to Q16.16
                    if (i < n_valid) begin
                        t_q16[i] <= t_arr[i] << 16;
                        v_q16[i] <= v_arr[i] << 16;
                        i <= i + 1'b1;
                        next_state <= CONVERT;
                    end else begin
                        i <= 4'd0;
                        next_state <= COMPUTE_TSTART;
                    end
                end

                COMPUTE_TSTART: begin
                    // Find max t (t_start)
                    if (i == 0) begin
                        t_start <= t_q16[0];
                        i <= i + 1'b1;
                    end else if (i < n_valid) begin
                        if (t_q16[i] > t_start) begin
                            t_start <= t_q16[i];
                        end
                        i <= i + 1'b1;
                    end else begin
                        i <= 4'd0;
                        next_state <= COMPUTE_LENGTHS;
                    end
                end

                COMPUTE_LENGTHS: begin
                    // Compute pack length at t_start
                    if (i == 0) begin
                        max_pos <= 32'd0;
                        min_pos <= 32'd0;
                        pos[i] <= v_q16[i] * (t_start - t_q16[i]);
                        max_pos <= pos[i];
                        min_pos <= pos[i];
                        i <= i + 1'b1;
                    end else if (i < n_valid) begin
                        pos[i] <= v_q16[i] * (t_start - t_q16[i]);
                        if (pos[i] > max_pos) begin
                            max_pos <= pos[i];
                        end
                        if (pos[i] < min_pos) begin
                            min_pos <= pos[i];
                        end
                        i <= i + 1'b1;
                    end else begin
                        current_length <= max_pos - min_pos;
                        min_length_reg <= current_length;
                        i <= 4'd0;
                        j <= 4'd1;
                        next_state <= COMPUTE_LENGTHS;
                    end

                    // Compute intersections
                    if (i < n_valid && j < n_valid && i != j) begin
                        if (v_q16[i] != v_q16[j]) begin
                            // Compute numerator and denominator
                            num <= v_q16[i] * t_q16[i] - v_q16[j] * t_q16[j];
                            den <= v_q16[i] - v_q16[j];

                            // Set up division
                            dividend <= num;
                            divisor <= den;
                            div_state <= DIV_COMPUTE;
                            div_cycle <= 5'd0;
                            quotient <= 32'd0;
                            remainder <= 32'd0;

                            next_state <= COMPUTE_LENGTHS;
                        end else begin
                            j <= j + 1'b1;
                            if (j >= n_valid) begin
                                j <= 4'd0;
                                i <= i + 1'b1;
                            end
                        end
                    end else if (i >= n_valid) begin
                        i <= 4'd0;
                        next_state <= FIND_MIN;
                    end
                end

                FIND_MIN: begin
                    // Compare current_length with min_length_reg
                    if (current_length < min_length_reg) begin
                        min_length_reg <= current_length;
                    end

                    // Move to next pair
                    j <= j + 1'b1;
                    if (j >= n_valid) begin
                        j <= 4'd0;
                        i <= i + 1'b1;
                        if (i >= n_valid) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= COMPUTE_LENGTHS;
                        end
                    end else begin
                        next_state <= COMPUTE_LENGTHS;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    min_length <= min_length_reg;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Division logic (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    // Idle
                end

                DIV_COMPUTE: begin
                    if (div_cycle < 32) begin
                        // Shift remainder and quotient
                        remainder <= {remainder[30:0], dividend[31]};
                        quotient <= {quotient[30:0], 1'b0};

                        // Subtract if possible
                        if (remainder[31] == divisor[31]) begin
                            if (remainder >= divisor) begin
                                remainder <= remainder - divisor;
                                quotient[0] <= 1'b1;
                            end
                        end else begin
                            if (remainder <= divisor) begin
                                remainder <= remainder - divisor;
                                quotient[0] <= 1'b1;
                            end
                        end

                        div_cycle <= div_cycle + 1'b1;
                    end else begin
                        // Division complete
                        t_int <= quotient;

                        // Check if t_int >= t_start
                        if (t_int >= t_start) begin
                            // Compute positions at t_int
                            for (k = 0; k < n_valid; k = k + 1) begin
                                pos[k] <= v_q16[k] * (t_int - t_q16[k]);
                            end

                            // Find max and min
                            max_pos <= pos[0];
                            min_pos <= pos[0];
                            for (k = 1; k < n_valid; k = k + 1) begin
                                if (pos[k] > max_pos) begin
                                    max_pos <= pos[k];
                                end
                                if (pos[k] < min_pos) begin
                                    min_pos <= pos[k];
                                end
                            end

                            current_length <= max_pos - min_pos;
                        end

                        div_state <= DIV_IDLE;
                    end
                end

                default: begin
                    div_state <= DIV_IDLE;
                end
            endcase
        end
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 16'd0;
        end else begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1'b1;
            end else begin
                // Force completion if max cycles reached
                if (state != IDLE && state != DONE_STATE) begin
                    next_state <= DONE_STATE;
                    done <= 1'b1;
                    min_length <= min_length_reg;
                end
            end
        end
    end

endmodule