module stan_eater(
    input clk,
    input rst_n,
    input start,
    input [7:0] course_0,
    input [7:0] course_1,
    input [7:0] course_2,
    input [7:0] course_3,
    input [7:0] course_4,
    input [7:0] course_5,
    input [7:0] course_6,
    input [7:0] course_7,
    input [7:0] m,
    output reg [15:0] result,
    output reg done
);

    // State machine definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_DP = 4'd1;
    localparam [3:0] INIT_COPY = 4'd2;
    localparam [3:0] COMPUTE_R = 4'd3;
    localparam [3:0] COMPUTE_S = 4'd4;
    localparam [3:0] NEXT_S = 4'd5;
    localparam [3:0] NEXT_R = 4'd6;
    localparam [3:0] NEXT_I_1 = 4'd7;
    localparam [3:0] COPY = 4'd8;
    localparam [3:0] NEXT_I_2 = 4'd9;
    localparam [3:0] DONE = 4'd10;

    reg [3:0] state;
    reg [3:0] i;
    reg [7:0] r;
    reg [1:0] s;
    reg [8:0] copy_index;

    // DP arrays
    reg [15:0] dp_current [0:128][0:2];
    reg [15:0] dp_next [0:128][0:2];

    // Course storage
    reg [7:0] course_reg [0:7];

    // Computation registers
    reg [7:0] current_rate;
    reg [15:0] calories;
    reg [7:0] next_r;
    reg [1:0] next_s;
    reg [15:0] value1, value2;
    reg [15:0] max_value;

    // Helper variables
    reg [8:0] r_copy, s_copy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 4'd0;
            r <= 8'd0;
            s <= 2'd0;
            copy_index <= 9'd0;

            // Initialize dp arrays
            integer j, k;
            for (j = 0; j < 129; j = j + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    dp_current[j][k] <= 16'd0;
                    dp_next[j][k] <= 16'd0;
                end
            end

            // Initialize course registers
            for (j = 0; j < 8; j = j + 1) begin
                course_reg[j] <= 8'd0;
            end

            current_rate <= 8'd0;
            calories <= 16'd0;
            next_r <= 8'd0;
            next_s <= 2'd0;
            value1 <= 16'd0;
            value2 <= 16'd0;
            max_value <= 16'd0;
            r_copy <= 9'd0;
            s_copy <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load courses into registers
                        course_reg[0] <= course_0;
                        course_reg[1] <= course_1;
                        course_reg[2] <= course_2;
                        course_reg[3] <= course_3;
                        course_reg[4] <= course_4;
                        course_reg[5] <= course_5;
                        course_reg[6] <= course_6;
                        course_reg[7] <= course_7;
                        state <= INIT_DP;
                    end
                end

                INIT_DP: begin
                    i <= 4'd7;
                    copy_index <= 9'd0;
                    state <= INIT_COPY;
                end

                INIT_COPY: begin
                    r_copy <= copy_index / 3;
                    s_copy <= copy_index % 3;
                    dp_next[r_copy][s_copy] <= 16'd0;
                    if (copy_index < 9'd386) begin
                        copy_index <= copy_index + 9'd1;
                    end else begin
                        state <= COMPUTE_R;
                    end
                end

                COMPUTE_R: begin
                    if (r > 8'd128) begin
                        state <= NEXT_I_1;
                    end else begin
                        s <= 2'd0;
                        state <= COMPUTE_S;
                    end
                end

                COMPUTE_S: begin
                    if (s > 2'd2) begin
                        state <= NEXT_R;
                    end else if (s == 2'd2 && r != m) begin
                        dp_current[r][s] <= 16'd0;
                        state <= NEXT_S;
                    end else begin
                        // Determine current rate
                        current_rate = (s == 2'd2) ? m : r;

                        // Eat option
                        if (current_rate < course_reg[i])
                            calories = current_rate;
                        else
                            calories = course_reg[i];
                        next_r = (current_rate * 2) / 3;
                        next_s = 2'd0;
                        value1 = calories + dp_next[next_r][next_s];

                        // Skip option
                        if (s < 2'd2) begin
                            next_s = s + 2'd1;
                            next_r = current_rate;
                        end else begin
                            next_s = 2'd2;
                            next_r = m;
                        end
                        value2 = dp_next[next_r][next_s];

                        // Max of eat vs skip
                        if (value1 > value2)
                            max_value = value1;
                        else
                            max_value = value2;

                        dp_current[r][s] <= max_value;
                        state <= NEXT_S;
                    end
                end

                NEXT_S: begin
                    s <= s + 2'd1;
                    state <= COMPUTE_S;
                end

                NEXT_R: begin
                    r <= r + 8'd1;
                    state <= COMPUTE_R;
                end

                NEXT_I_1: begin
                    copy_index <= 9'd0;
                    state <= COPY;
                end

                COPY: begin
                    r_copy <= copy_index / 3;
                    s_copy <= copy_index % 3;
                    dp_next[r_copy][s_copy] <= dp_current[r_copy][s_copy];
                    if (copy_index < 9'd386) begin
                        copy_index <= copy_index + 9'd1;
                    end else begin
                        state <= NEXT_I_2;
                    end
                end

                NEXT_I_2: begin
                    i <= i - 4'd1;
                    if (i == 4'd0) begin
                        state <= DONE;
                    end else begin
                        r <= 8'd0;
                        s <= 2'd0;
                        state <= COMPUTE_S;
                    end
                end

                DONE: begin
                    result <= dp_next[m][2'd0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule