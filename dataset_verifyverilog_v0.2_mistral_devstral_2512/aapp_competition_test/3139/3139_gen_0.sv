module student_mentor_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] query_idx,
    input [2:0] num_students,
    input [7:0][15:0] student_A,
    input [7:0][15:0] student_B,
    output reg [2:0] mentor_idx,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SEARCH,
        COMPARE,
        DONE
    } state_t;

    // Internal signals
    reg [2:0] current_idx;
    reg [2:0] best_idx;
    reg [15:0] query_A;
    reg [15:0] query_B;
    reg [15:0] best_B_diff;
    reg [15:0] best_A_diff;
    reg [15:0] current_B_diff;
    reg [15:0] current_A_diff;
    reg valid_candidate;
    reg candidate_valid;
    reg [15:0] temp_A;
    reg [15:0] temp_B;

    // State machine
    state_t state, next_state;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            mentor_idx <= 3'b0;
            current_idx <= 3'b0;
            best_idx <= 3'b0;
            query_A <= 16'b0;
            query_B <= 16'b0;
            best_B_diff <= 16'b0;
            best_A_diff <= 16'b0;
            current_B_diff <= 16'b0;
            current_A_diff <= 16'b0;
            valid_candidate <= 1'b0;
            candidate_valid <= 1'b0;
            temp_A <= 16'b0;
            temp_B <= 16'b0;
        end else begin
            state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                end
            end
            SEARCH: begin
                if (current_idx == num_students - 1) begin
                    if (valid_candidate) begin
                        next_state = DONE;
                    end else begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                next_state = SEARCH;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values already handled
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        query_A <= student_A[query_idx];
                        query_B <= student_B[query_idx];
                        current_idx <= 3'b0;
                        best_idx <= 3'b0;
                        valid_candidate <= 1'b0;
                        best_B_diff <= 16'hFFFF;
                        best_A_diff <= 16'hFFFF;
                    end
                end
                SEARCH: begin
                    if (current_idx == num_students - 1) begin
                        // Last iteration, move to DONE
                    end else begin
                        current_idx <= current_idx + 1'b1;
                    end
                end
                COMPARE: begin
                    temp_A <= student_A[current_idx];
                    temp_B <= student_B[current_idx];
                    candidate_valid <= (temp_A >= query_A) && (temp_B >= query_B) && (current_idx != query_idx);
                    if (candidate_valid) begin
                        current_B_diff <= temp_B - query_B;
                        current_A_diff <= temp_A - query_A;
                        if (!valid_candidate || (current_B_diff < best_B_diff) || 
                            (current_B_diff == best_B_diff && current_A_diff < best_A_diff)) begin
                            best_idx <= current_idx;
                            best_B_diff <= current_B_diff;
                            best_A_diff <= current_A_diff;
                            valid_candidate <= 1'b1;
                        end
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    valid <= valid_candidate;
                    if (valid_candidate) begin
                        mentor_idx <= best_idx;
                    end else begin
                        mentor_idx <= 3'b0;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule