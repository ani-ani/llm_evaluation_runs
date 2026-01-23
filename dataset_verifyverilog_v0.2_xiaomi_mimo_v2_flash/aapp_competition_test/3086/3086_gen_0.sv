module event_duration_solver(
    input clk,
    input rst_n,
    input start,
    input [8:0] start_day,
    input [8:0] end_day,
    input [7:0] F [0:3],
    output reg [8:0] duration [0:3],
    output reg done,
    output reg valid
);

    // Parameters
    parameter MAX_ITER = 1000;
    parameter M = 4;
    parameter DAYS_PER_YEAR = 365;

    // State definitions
    localparam IDLE = 3'b000;
    localparam CALC_OBS = 3'b001;
    localparam SOLVE_INIT = 3'b010;
    localparam SOLVE_ITER = 3'b011;
    localparam CHECK = 3'b100;
    localparam OUTPUT = 3'b101;

    // Internal registers
    reg [2:0] state, next_state;
    reg [8:0] observation_window;
    reg [8:0] d_reg [0:3]; // Current candidate durations
    reg [8:0] sum_calc;
    reg [31:0] iter_count;
    reg check_pass;
    integer i;

    // Store input F for consistency during solve
    reg [7:0] F_store [0:3];

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            observation_window <= 0;
            iter_count <= 0;
            for (i = 0; i < M; i = i + 1) begin
                duration[i] <= 0;
                d_reg[i] <= 0;
                F_store[i] <= 0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    iter_count <= 0;
                    if (start) begin
                        // Store inputs
                        for (i = 0; i < M; i = i + 1) begin
                            F_store[i] <= F[i];
                        end
                    end
                end

                CALC_OBS: begin
                    // Calculate observation window
                    if (end_day >= start_day)
                        observation_window <= end_day - start_day;
                    else
                        observation_window <= end_day + DAYS_PER_YEAR - start_day;
                    // Initialize search
                    d_reg[0] <= 1;
                    d_reg[1] <= 1;
                    d_reg[2] <= 1;
                    d_reg[3] <= 1;
                end

                SOLVE_ITER: begin
                    // Increment counter
                    iter_count <= iter_count + 1;
                end

                CHECK: begin
                    // If check passed, load to output and prepare to finish (or continue if multiple solutions allowed)
                    if (check_pass) begin
                        for (i = 0; i < M; i = i + 1) begin
                            duration[i] <= d_reg[i];
                        end
                        valid <= 1;
                    end
                end

                OUTPUT: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_OBS;
                else next_state = IDLE;
            end

            CALC_OBS: begin
                next_state = SOLVE_INIT;
            end

            SOLVE_INIT: begin
                // Check if current config satisfies immediately or start search
                next_state = CHECK;
            end

            SOLVE_ITER: begin
                if (iter_count >= MAX_ITER) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                if (check_pass) begin
                    // Found a solution
                    next_state = OUTPUT;
                end else begin
                    // Increment durations to next candidate
                    // Simple linear search: increment d0, wrap around, increment d1, etc.
                    if (d_reg[0] < 365) next_state = SOLVE_ITER; // Just continue incrementing check state logic
                    else next_state = SOLVE_ITER; // Will handle increment in combinational block below
                end
            end

            OUTPUT: begin
                next_state = IDLE;
            end
        endcase
    end

    // Combinational Helper: Increment durations
    // This block modifies d_reg incrementally in SOLVE_ITER/COMB state
    // Note: Since we use d_reg as sequential, we need to compute the *next* value of d_reg in combinational logic
    // However, strictly sequential design prefers updating d_reg in the sequential block triggered by state.
    // Let's do the increment logic in the sequential block triggered by SOLVE_ITER state.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == SOLVE_ITER) begin
                // Increment logic: d[0]++ -> if 366, d[0]=1, d[1]++ ...
                if (d_reg[0] < 365) begin
                    d_reg[0] <= d_reg[0] + 1;
                end else begin
                    d_reg[0] <= 1;
                    if (d_reg[1] < 365) begin
                        d_reg[1] <= d_reg[1] + 1;
                    end else begin
                        d_reg[1] <= 1;
                        if (d_reg[2] < 365) begin
                            d_reg[2] <= d_reg[2] + 1;
                        end else begin
                            d_reg[2] <= 1;
                            if (d_reg[3] < 365) begin
                                d_reg[3] <= d_reg[3] + 1;
                            end else begin
                                d_reg[3] <= 1; // Loop back
                            end
                        end
                    end
                end
            end
        end
    end

    // Combinational Check Logic
    // Calculates sum(F[i] * d_reg[i]) and compares to observation_window
    always @(*) begin
        sum_calc = 0;
        for (i = 0; i < M; i = i + 1) begin
            sum_calc = sum_calc + (F_store[i] * d_reg[i]);
        end
        
        if (sum_calc == observation_window && observation_window != 0) begin
            check_pass = 1;
        end else begin
            check_pass = 0;
        end
    end

endmodule