module stan_eater (
    input clk,
    input rst_n,
    input start,
    input [7:0] course_0, course_1, course_2, course_3,
                 course_4, course_5, course_6, course_7,
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
reg [3:0] next_state;

// Registers
reg [3:0] i;          // Current course index (7 down to 0)
reg [7:0] r;          // Current rate (0 to 128)
reg [1:0] s;          // Skip count (0,1,2)
reg [8:0] copy_index; // 0 to 386 for 129*3 array

// DP arrays - using packed representation to avoid 2D array issues
reg [15:0] dp_next [0:386];     // Flattened: index = r*3 + s
reg [15:0] dp_current [0:386];  // Flattened: index = r*3 + s

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
reg [8:0] flat_index;

// Cycle counter to prevent infinite loops
reg [8:0] cycle_count;
localparam [8:0] MAX_CYCLES = 9'd500;

// FSM register update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        i <= 4'd0;
        r <= 8'd0;
        s <= 2'd0;
        copy_index <= 9'd0;
        cycle_count <= 9'd0;
    end else begin
        cycle_count <= cycle_count + 9'd1;
        state <= next_state;
    end
end

// FSM combinational logic
always @(*) begin
    // Default values
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT_DP;
            end
        end

        INIT_DP: begin
            next_state = INIT_COPY;
        end

        INIT_COPY: begin
            if (copy_index < 9'd386) begin
                next_state = INIT_COPY;
            end else begin
                next_state = COMPUTE_R;
            end
        end

        COMPUTE_R: begin
            if (r > 8'd128) begin
                next_state = NEXT_I_1;
            end else if (cycle_count >= MAX_CYCLES) begin
                next_state = DONE; // Safety timeout
            end else begin
                next_state = COMPUTE_S;
            end
        end

        COMPUTE_S: begin
            if (s > 2'd2) begin
                next_state = NEXT_R;
            end else begin
                next_state = NEXT_S;
            end
        end

        NEXT_S: begin
            next_state = COMPUTE_S;
        end

        NEXT_R: begin
            next_state = COMPUTE_R;
        end

        NEXT_I_1: begin
            next_state = COPY;
        end

        COPY: begin
            if (copy_index < 9'd386) begin
                next_state = COPY;
            end else begin
                next_state = NEXT_I_2;
            end
        end

        NEXT_I_2: begin
            if (i == 4'd0) begin
                next_state = DONE;
            end else begin
                next_state = COMPUTE_S;
            end
        end

        DONE: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

// Sequential operations
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all registers
        for (int j = 0; j < 8; j = j + 1) begin
            course_reg[j] <= 8'd0;
        end
        for (int j = 0; j < 387; j = j + 1) begin
            dp_next[j] <= 16'd0;
            dp_current[j] <= 16'd0;
        end
        flat_index <= 9'd0;
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
                end
            end

            INIT_DP: begin
                i <= 4'd7;  // Start from last course
                copy_index <= 9'd0;
            end

            INIT_COPY: begin
                // Initialize dp_next to zero
                flat_index <= (copy_index / 3) * 3 + (copy_index % 3);
                dp_next[flat_index] <= 16'd0;
                if (copy_index < 9'd386) begin
                    copy_index <= copy_index + 9'd1;
                end
            end

            COMPUTE_R: begin
                if (r <= 8'd128) begin
                    s <= 2'd0;
                end
            end

            COMPUTE_S: begin
                if (s <= 2'd2) begin
                    if (s == 2'd2 && r != m) begin
                        // Skip index calculation for safety
                        flat_index <= r * 3 + s;
                        dp_current[r * 3 + s] <= 16'd0;
                    end else begin
                        // Determine current rate
                        if (s == 2'd2)
                            current_rate = m;
                        else
                            current_rate = r;

                        // Eat option
                        if (current_rate < course_reg[i])
                            calories = current_rate;
                        else
                            calories = course_reg[i];
                        next_r = (current_rate * 8'd2) / 8'd3;
                        next_s = 2'd0;
                        value1 = calories + dp_next[next_r * 3 + next_s];

                        // Skip option
                        if (s < 2'd2) begin
                            next_s = s + 2'd1;
                            next_r = current_rate;
                        end else begin
                            next_s = 2'd2;
                            next_r = m;
                        end
                        value2 = dp_next[next_r * 3 + next_s];

                        // Max of eat vs skip
                        if (value1 > value2)
                            max_value = value1;
                        else
                            max_value = value2;

                        flat_index <= r * 3 + s;
                        dp_current[r * 3 + s] <= max_value;
                    end
                end
            end

            NEXT_S: begin
                s <= s + 2'd1;
            end

            NEXT_R: begin
                r <= r + 8'd1;
            end

            NEXT_I_1: begin
                copy_index <= 9'd0;
            end

            COPY: begin
                flat_index <= (copy_index / 3) * 3 + (copy_index % 3);
                dp_next[flat_index] <= dp_current[flat_index];
                if (copy_index < 9'd386) begin
                    copy_index <= copy_index + 9'd1;
                end
            end

            NEXT_I_2: begin
                if (i == 4'd0) begin
                    // Done
                end else begin
                    i <= i - 4'd1;
                    r <= 8'd0;
                    s <= 2'd0;
                end
            end

            DONE: begin
                result <= dp_next[m * 3];
                done <= 1'b1;
            end
        endcase
    end
end

endmodule