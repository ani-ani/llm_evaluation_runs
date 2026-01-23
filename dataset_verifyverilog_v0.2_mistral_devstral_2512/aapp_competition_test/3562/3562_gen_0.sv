module grade_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_subjects,
    input [7:0] total_time,
    input [9:0][31:0] params_a,
    input [9:0][31:0] params_b,
    input [9:0][31:0] params_c,
    output reg [31:0] avg_grade,
    output reg done
);

    // Constants
    localparam Q16_16_DT = 32'h000028F6; // 0.01 in Q16.16
    localparam MAX_ITERATIONS = 24000;

    // States
    typedef enum logic [3:0] {
        IDLE,
        CALC_DERIV,
        ALLOCATE_TIME,
        CHECK_DONE,
        DONE
    } state_t;

    // Registers
    state_t current_state, next_state;
    reg [31:0] time_allocated [0:9]; // Q16.16 per subject
    reg [31:0] total_time_q16; // Q16.16
    reg [31:0] iteration_count;
    reg [31:0] max_derivative;
    reg [3:0] max_subject;
    reg [31:0] sum_grades;

    // Saturating add
    function [31:0] sat_add;
        input [31:0] a, b;
        begin
            sat_add = a + b;
            if (sat_add[31] !== a[31] && sat_add[31] !== b[31])
                sat_add = (a[31] === b[31]) ? {a[31], {31{1'b1}}} : {a[31], {31{1'b0}}};
        end
    endfunction

    // Saturating subtract
    function [31:0] sat_sub;
        input [31:0] a, b;
        begin
            sat_sub = a - b;
            if (sat_sub[31] !== a[31] && sat_sub[31] === b[31])
                sat_sub = (a[31] === 1'b0) ? {1'b0, {31{1'b0}}} : {1'b1, {31{1'b1}}};
        end
    endfunction

    // Calculate derivative: 2*a_i*t + b_i
    function [31:0] calc_derivative;
        input [31:0] a, b, t;
        begin
            calc_derivative = sat_add(sat_add(a, a), b); // 2*a + b
        end
    endfunction

    // Calculate grade: a_i*t^2 + b_i*t + c_i
    function [31:0] calc_grade;
        input [31:0] a, b, c, t;
        reg [31:0] t_squared;
        begin
            t_squared = $signed(t) * $signed(t) >>> 16; // Q16.16 * Q16.16 = Q32.32, shift right 16
            calc_grade = sat_add(sat_add($signed(a) * $signed(t_squared) >>> 16, $signed(b) * $signed(t) >>> 16), c);
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            avg_grade <= 32'h00000000;
            for (int i = 0; i < 10; i++) begin
                time_allocated[i] <= 32'h00000000;
            end
            total_time_q16 <= 32'h00000000;
            iteration_count <= 32'h00000000;
            max_derivative <= 32'h00000000;
            max_subject <= 4'h0;
            sum_grades <= 32'h00000000;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        total_time_q16 <= {16'h0000, total_time}; // Convert to Q16.16
                        iteration_count <= 32'h00000000;
                        for (int i = 0; i < 10; i++) begin
                            time_allocated[i] <= 32'h00000000;
                        end
                        next_state <= CALC_DERIV;
                    end
                end

                CALC_DERIV: begin
                    max_derivative <= 32'h80000000; // Initialize to minimum
                    max_subject <= 4'h0;
                    for (int i = 0; i < num_subjects; i++) begin
                        reg [31:0] deriv = calc_derivative(params_a[i], params_b[i], time_allocated[i]);
                        if ($signed(deriv) > $signed(max_derivative)) begin
                            max_derivative <= deriv;
                            max_subject <= i;
                        end
                    end
                    next_state <= ALLOCATE_TIME;
                end

                ALLOCATE_TIME: begin
                    time_allocated[max_subject] <= sat_add(time_allocated[max_subject], Q16_16_DT);
                    iteration_count <= sat_add(iteration_count, 32'h00000001);
                    next_state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    reg [31:0] total_allocated = 32'h00000000;
                    for (int i = 0; i < num_subjects; i++) begin
                        total_allocated = sat_add(total_allocated, time_allocated[i]);
                    end

                    if (total_allocated >= total_time_q16 || iteration_count >= MAX_ITERATIONS) begin
                        sum_grades <= 32'h00000000;
                        for (int i = 0; i < num_subjects; i++) begin
                            sum_grades <= sat_add(sum_grades, calc_grade(params_a[i], params_b[i], params_c[i], time_allocated[i]));
                        end
                        avg_grade <= sum_grades / num_subjects; // Division in Q16.16
                        next_state <= DONE;
                    end else begin
                        next_state <= CALC_DERIV;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        done <= 1'b0;
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule