module trope_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] cmd_type,
    input [23:0] event_hash,
    input [2:0] dream_count,
    input [2:0] scenario_count,
    input [23:0] scenario_event_hash_0,
    input scenario_event_negate_0,
    input [23:0] scenario_event_hash_1,
    input scenario_event_negate_1,
    input [23:0] scenario_event_hash_2,
    input scenario_event_negate_2,
    input [23:0] scenario_event_hash_3,
    input scenario_event_negate_3,
    input [23:0] scenario_event_hash_4,
    input scenario_event_negate_4,
    output reg result_valid,
    output reg [1:0] result_code,
    output reg [2:0] dream_amount
);

    parameter MAX_HISTORY = 4;
    parameter MAX_SCENARIO = 5;
    parameter EVENT_HASH_WIDTH = 24;

    typedef enum logic [1:0] {
        IDLE,
        PROCESS_CMD,
        CHECK_SCENARIO,
        CALCULATE_ROLLBACK,
        OUTPUT_RESULT
    } state_t;

    state_t current_state, next_state;

    reg [23:0] event_stack [0:MAX_HISTORY-1];
    reg [1:0] stack_ptr;

    reg [23:0] scenario_hashes [0:MAX_SCENARIO-1];
    reg scenario_negates [0:MAX_SCENARIO-1];

    reg [2:0] scenario_length;
    reg [2:0] current_scenario_index;
    reg [2:0] current_rollback;
    reg [2:0] min_rollback;
    reg rollback_found;

    reg [2:0] temp_stack_ptr;
    reg [23:0] temp_stack [0:MAX_HISTORY-1];

    reg [2:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            stack_ptr <= 0;
            result_valid <= 0;
            result_code <= 0;
            dream_amount <= 0;
            counter <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= PROCESS_CMD;
                    end
                end

                PROCESS_CMD: begin
                    case (cmd_type)
                        3'b000: begin // Event
                            if (stack_ptr < MAX_HISTORY) begin
                                event_stack[stack_ptr] <= event_hash;
                                stack_ptr <= stack_ptr + 1;
                            end else begin
                                // Shift stack left, discard oldest
                                for (int i = 0; i < MAX_HISTORY-1; i++) begin
                                    event_stack[i] <= event_stack[i+1];
                                end
                                event_stack[MAX_HISTORY-1] <= event_hash;
                            end
                            next_state <= IDLE;
                        end

                        3'b001: begin // Dream
                            if (dream_count > 0 && stack_ptr >= dream_count) begin
                                stack_ptr <= stack_ptr - dream_count;
                            end else if (dream_count > 0) begin
                                stack_ptr <= 0;
                            end
                            next_state <= IDLE;
                        end

                        3'b010: begin // Scenario
                            // Load scenario data
                            scenario_length <= scenario_count;
                            scenario_hashes[0] <= scenario_event_hash_0;
                            scenario_negates[0] <= scenario_event_negate_0;
                            scenario_hashes[1] <= scenario_event_hash_1;
                            scenario_negates[1] <= scenario_event_negate_1;
                            scenario_hashes[2] <= scenario_event_hash_2;
                            scenario_negates[2] <= scenario_event_negate_2;
                            scenario_hashes[3] <= scenario_event_hash_3;
                            scenario_negates[3] <= scenario_event_negate_3;
                            scenario_hashes[4] <= scenario_event_hash_4;
                            scenario_negates[4] <= scenario_event_negate_4;

                            current_scenario_index <= 0;
                            next_state <= CHECK_SCENARIO;
                        end

                        default: begin
                            next_state <= IDLE;
                        end
                    endcase
                end

                CHECK_SCENARIO: begin
                    if (current_scenario_index < scenario_length) begin
                        // Check current scenario event
                        reg event_match = 1'b0;
                        for (int i = 0; i < stack_ptr; i++) begin
                            if (event_stack[i] == scenario_hashes[current_scenario_index]) begin
                                event_match = 1'b1;
                                break;
                            end
                        end

                        if ((scenario_negates[current_scenario_index] == 0 && !event_match) ||
                            (scenario_negates[current_scenario_index] == 1 && event_match)) begin
                            // Mismatch found
                            current_rollback <= 0;
                            min_rollback <= 0;
                            rollback_found <= 0;
                            next_state <= CALCULATE_ROLLBACK;
                        end else begin
                            current_scenario_index <= current_scenario_index + 1;
                        end
                    end else begin
                        // All events matched
                        result_code <= 2'b01; // Yes
                        result_valid <= 1'b1;
                        next_state <= OUTPUT_RESULT;
                    end
                end

                CALCULATE_ROLLBACK: begin
                    if (current_rollback < MAX_HISTORY && !rollback_found) begin
                        // Try rolling back current_rollback+1 events
                        temp_stack_ptr <= stack_ptr - (current_rollback + 1);
                        for (int i = 0; i < temp_stack_ptr; i++) begin
                            temp_stack[i] <= event_stack[i + current_rollback + 1];
                        end

                        // Check scenario against temp stack
                        reg temp_match = 1'b1;
                        for (int i = 0; i < scenario_length; i++) begin
                            reg event_found = 1'b0;
                            for (int j = 0; j < temp_stack_ptr; j++) begin
                                if (temp_stack[j] == scenario_hashes[i]) begin
                                    event_found = 1'b1;
                                    break;
                                end
                            end

                            if ((scenario_negates[i] == 0 && !event_found) ||
                                (scenario_negates[i] == 1 && event_found)) begin
                                temp_match = 1'b0;
                                break;
                            end
                        end

                        if (temp_match) begin
                            min_rollback <= current_rollback + 1;
                            rollback_found <= 1'b1;
                        end
                        current_rollback <= current_rollback + 1;
                    end else begin
                        if (rollback_found) begin
                            result_code <= 2'b10; // Just A Dream
                            dream_amount <= min_rollback;
                            result_valid <= 1'b1;
                        end else begin
                            result_code <= 2'b00; // Plot Error
                            result_valid <= 1'b1;
                        end
                        next_state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    if (counter < 9) begin
                        counter <= counter + 1;
                    end else begin
                        result_valid <= 0;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule