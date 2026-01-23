module cheerleader_optimizer (
    input clk,
    input rst_n,
    input start,
    input [1:0] num_cheerleaders,
    input [7:0] cheer_time,
    input [7:0] opponent_pattern,
    output reg [3:0] sportify_goals,
    output reg [3:0] spoilify_goals,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        EVALUATE_SCHEDULES,
        COMPUTE_GOALS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Schedule encoding variables
    reg [7:0] schedule1, schedule2;
    reg [7:0] best_schedule1, best_schedule2;

    // Counters and tracking variables
    reg [15:0] schedule_counter;
    reg [2:0] minute_counter;
    reg [2:0] sportify_streak, spoilify_streak;
    reg [3:0] current_sportify_goals, current_spoilify_goals;
    reg [3:0] best_sportify_goals, best_spoilify_goals;
    reg [3:0] best_goal_diff;

    // Temporary variables for computation
    reg [1:0] sportify_cheers, spoilify_cheers;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            schedule_counter <= 0;
            minute_counter <= 0;
            sportify_streak <= 0;
            spoilify_streak <= 0;
            current_sportify_goals <= 0;
            current_spoilify_goals <= 0;
            best_sportify_goals <= 0;
            best_spoilify_goals <= 0;
            best_goal_diff <= 0;
            schedule1 <= 0;
            schedule2 <= 0;
            best_schedule1 <= 0;
            best_schedule2 <= 0;
            sportify_goals <= 0;
            spoilify_goals <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        schedule_counter <= 0;
                        minute_counter <= 0;
                        current_sportify_goals <= 0;
                        current_spoilify_goals <= 0;
                        best_sportify_goals <= 0;
                        best_spoilify_goals <= 0;
                        best_goal_diff <= 0;
                        schedule1 <= 0;
                        schedule2 <= 0;
                        best_schedule1 <= 0;
                        best_schedule2 <= 0;
                        done <= 0;
                    end
                end

                EVALUATE_SCHEDULES: begin
                    // Generate next schedule
                    if (schedule_counter < 500) begin
                        schedule_counter <= schedule_counter + 1;
                        schedule1 <= $random;
                        schedule2 <= $random;
                    end
                end

                COMPUTE_GOALS: begin
                    // Compute goals for current schedule
                    if (minute_counter < 8) begin
                        // Count cheers for current minute
                        sportify_cheers = (schedule1[minute_counter] ? 1 : 0) + (schedule2[minute_counter] ? 1 : 0);
                        spoilify_cheers = opponent_pattern[minute_counter] ? 1 : 0;

                        // Update streaks
                        if (sportify_cheers > spoilify_cheers) begin
                            sportify_streak <= sportify_streak + 1;
                            spoilify_streak <= 0;
                        end else if (spoilify_cheers > sportify_cheers) begin
                            spoilify_streak <= spoilify_streak + 1;
                            sportify_streak <= 0;
                        end else begin
                            sportify_streak <= 0;
                            spoilify_streak <= 0;
                        end

                        // Check for goals
                        if (sportify_streak == 3) begin
                            current_sportify_goals <= current_sportify_goals + 1;
                            sportify_streak <= 0;
                        end
                        if (spoilify_streak == 3) begin
                            current_spoilify_goals <= current_spoilify_goals + 1;
                            spoilify_streak <= 0;
                        end

                        minute_counter <= minute_counter + 1;
                    end else begin
                        // Evaluate if this is the best schedule
                        if (current_sportify_goals - current_spoilify_goals > best_goal_diff ||
                            (current_sportify_goals - current_spoilify_goals == best_goal_diff &&
                             current_sportify_goals > best_sportify_goals)) begin
                            best_goal_diff <= current_sportify_goals - current_spoilify_goals;
                            best_sportify_goals <= current_sportify_goals;
                            best_spoilify_goals <= current_spoilify_goals;
                            best_schedule1 <= schedule1;
                            best_schedule2 <= schedule2;
                        end

                        // Reset for next schedule
                        minute_counter <= 0;
                        sportify_streak <= 0;
                        spoilify_streak <= 0;
                        current_sportify_goals <= 0;
                        current_spoilify_goals <= 0;
                    end
                end

                DONE: begin
                    sportify_goals <= best_sportify_goals;
                    spoilify_goals <= best_spoilify_goals;
                    done <= 1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = EVALUATE_SCHEDULES;
            end

            EVALUATE_SCHEDULES: begin
                if (schedule_counter < 500) begin
                    next_state = COMPUTE_GOALS;
                end else begin
                    next_state = DONE;
                end
            end

            COMPUTE_GOALS: begin
                if (minute_counter < 8) begin
                    next_state = COMPUTE_GOALS;
                end else begin
                    next_state = EVALUATE_SCHEDULES;
                end
            end

            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule