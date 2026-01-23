module burger_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    input [9:0] k_in,
    input [9:0] a_in,
    input [9:0] b_in,
    output reg [31:0] min_stops,
    output reg [31:0] max_stops,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        ITERATE_LOOP,
        CALC_GCD,
        UPDATE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] i_reg;
    reg [9:0] s1, s2, s3, s4;
    reg [9:0] step_value;
    reg [31:0] gcd_result;
    reg [31:0] stops;
    reg [31:0] total_cities;
    reg [1:0] sub_iter;

    // GCD computation registers
    reg [31:0] gcd_a, gcd_b;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            i_reg <= 0;
            sub_iter <= 0;
            min_stops <= 32'hFFFFFFFF;
            max_stops <= 32'h00000000;
            done <= 0;
            gcd_result <= 0;
            total_cities <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = ITERATE_LOOP;
                    i_reg = 0;
                    sub_iter = 0;
                    total_cities = n_in * k_in;
                    min_stops = 32'hFFFFFFFF;
                    max_stops = 32'h00000000;
                    done = 0;
                end
            end
            ITERATE_LOOP: begin
                if (i_reg == n_in - 1 && sub_iter == 3) begin
                    next_state = DONE;
                end else begin
                    // Compute step values
                    s1 = (i_reg * k_in + b_in - a_in) % total_cities;
                    s2 = (i_reg * k_in + b_in + a_in) % total_cities;
                    s3 = (i_reg * k_in - b_in - a_in) % total_cities;
                    s4 = (i_reg * k_in - b_in + a_in) % total_cities;

                    // Handle negative modulo
                    if (s1 < 0) s1 = s1 + total_cities;
                    if (s2 < 0) s2 = s2 + total_cities;
                    if (s3 < 0) s3 = s3 + total_cities;
                    if (s4 < 0) s4 = s4 + total_cities;

                    // Select step value based on sub_iter
                    case (sub_iter)
                        0: step_value = s1;
                        1: step_value = s2;
                        2: step_value = s3;
                        3: step_value = s4;
                    endcase

                    // Proceed to GCD calculation
                    next_state = CALC_GCD;
                end
            end
            CALC_GCD: begin
                // Initialize GCD registers
                gcd_a = total_cities;
                gcd_b = step_value;
                next_state = UPDATE_RESULT;
            end
            UPDATE_RESULT: begin
                // Compute GCD iteratively
                if (gcd_b == 0) begin
                    if (gcd_a == 0) begin
                        gcd_result = 1;
                    end else begin
                        gcd_result = gcd_a;
                    end
                end else begin
                    // Euclidean algorithm step
                    if (gcd_a > gcd_b) begin
                        gcd_a = gcd_a - gcd_b;
                    end else begin
                        gcd_b = gcd_b - gcd_a;
                    end
                    next_state = UPDATE_RESULT;
                end

                // If GCD is done, compute stops
                if (gcd_result != 0) begin
                    stops = total_cities / gcd_result;
                    // Update min and max
                    if (stops < min_stops) min_stops = stops;
                    if (stops > max_stops) max_stops = stops;

                    // Move to next sub_iter or i
                    if (sub_iter == 3) begin
                        i_reg = i_reg + 1;
                        sub_iter = 0;
                    end else begin
                        sub_iter = sub_iter + 1;
                    end
                    next_state = ITERATE_LOOP;
                end
            end
            DONE: begin
                done = 1;
                next_state = IDLE;
            end
        endcase
    end

endmodule