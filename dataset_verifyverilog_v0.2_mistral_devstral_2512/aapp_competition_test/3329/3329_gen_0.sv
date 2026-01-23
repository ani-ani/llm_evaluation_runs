module pebble_transform (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [3:0] K,
    input [7:0] target_circle,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT_CANDIDATE,
        APPLY_TRANSFORM,
        CHECK_EQUIVALENCE,
        INCREMENT_RESULT,
        NEXT_CANDIDATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Candidate circle and transformation registers
    reg [7:0] candidate_circle;
    reg [7:0] transformed_circle;
    reg [7:0] temp_circle;

    // Counters
    reg [7:0] candidate_counter;
    reg [3:0] transform_counter;
    reg [2:0] rotation_counter;

    // Flags
    reg match_found;
    reg [7:0] shifted_target;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            candidate_counter <= 0;
            transform_counter <= 0;
            rotation_counter <= 0;
            match_found <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_CANDIDATE;
                    result = 0;
                    done = 0;
                    candidate_counter = 0;
                end
            end
            INIT_CANDIDATE: begin
                next_state = APPLY_TRANSFORM;
                transform_counter = 0;
                candidate_circle = candidate_counter;
            end
            APPLY_TRANSFORM: begin
                if (transform_counter == K - 1) begin
                    next_state = CHECK_EQUIVALENCE;
                    rotation_counter = 0;
                    match_found = 0;
                end else begin
                    next_state = APPLY_TRANSFORM;
                    transform_counter = transform_counter + 1;
                end
            end
            CHECK_EQUIVALENCE: begin
                if (rotation_counter == N - 1) begin
                    if (match_found) begin
                        next_state = INCREMENT_RESULT;
                    end else begin
                        next_state = NEXT_CANDIDATE;
                    end
                end else begin
                    next_state = CHECK_EQUIVALENCE;
                    rotation_counter = rotation_counter + 1;
                end
            end
            INCREMENT_RESULT: begin
                next_state = NEXT_CANDIDATE;
            end
            NEXT_CANDIDATE: begin
                if (candidate_counter == (1 << N) - 1) begin
                    next_state = DONE;
                    done = 1;
                end else begin
                    next_state = INIT_CANDIDATE;
                    candidate_counter = candidate_counter + 1;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Transformation logic
    always @(posedge clk) begin
        if (current_state == APPLY_TRANSFORM) begin
            for (int i = 0; i < N; i = i + 1) begin
                temp_circle[i] = (candidate_circle[i] == candidate_circle[(i + 1) % N]) ? 1'b1 : 1'b0;
            end
            candidate_circle = temp_circle;
        end
    end

    // Rotation equivalence check
    always @(posedge clk) begin
        if (current_state == CHECK_EQUIVALENCE) begin
            // Create shifted version of target
            for (int i = 0; i < N; i = i + 1) begin
                shifted_target[i] = target_circle[(i + rotation_counter) % N];
            end
            // Compare with transformed circle
            if (transformed_circle == shifted_target) begin
                match_found = 1'b1;
            end
        end
    end

    // Increment result
    always @(posedge clk) begin
        if (current_state == INCREMENT_RESULT) begin
            result = result + 1;
        end
    end

    // Store transformed circle after all transformations
    always @(posedge clk) begin
        if (current_state == APPLY_TRANSFORM && transform_counter == K - 1) begin
            transformed_circle = candidate_circle;
        end
    end

endmodule