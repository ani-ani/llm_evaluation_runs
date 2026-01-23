module council_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_residents,
    input [3:0] num_clubs,
    input [7:0] resident_id,
    input [7:0] party_id,
    input [3:0] club_mask,
    input load_valid,
    output reg solved,
    output reg impossible,
    output reg [7:0] result_club_id,
    output reg [7:0] result_resident_id,
    output reg result_valid
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SOLVE,
        OUTPUT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Resident data storage
    typedef struct {
        logic [7:0] id;
        logic [7:0] party;
        logic [3:0] clubs;
    } resident_t;

    resident_t residents [0:7];
    logic [3:0] resident_count;
    logic [3:0] club_count;

    // Solver variables
    logic [7:0] assignment [0:7]; // assignment[i] = club index for resident i
    logic [3:0] current_resident;
    logic [3:0] current_club;
    logic [3:0] party_counts [0:3]; // Max 4 parties
    logic solution_found;

    // Output variables
    logic [3:0] output_index;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            solved <= 0;
            impossible <= 0;
            result_valid <= 0;
            resident_count <= 0;
            club_count <= 0;
            current_resident <= 0;
            current_club <= 0;
            output_index <= 0;
            solution_found <= 0;
            for (int i = 0; i < 8; i++) begin
                residents[i].id <= 0;
                residents[i].party <= 0;
                residents[i].clubs <= 0;
                assignment[i] <= 0;
            end
            for (int i = 0; i < 4; i++) begin
                party_counts[i] <= 0;
            end
        end else begin
            current_state <= next_state;

            // State actions
            case (current_state)
                IDLE: begin
                    solved <= 0;
                    impossible <= 0;
                    result_valid <= 0;
                end

                LOAD: begin
                    if (load_valid && resident_count < num_residents) begin
                        residents[resident_count].id <= resident_id;
                        residents[resident_count].party <= party_id;
                        residents[resident_count].clubs <= club_mask;
                        resident_count <= resident_count + 1;
                    end
                end

                SOLVE: begin
                    // Backtracking solver implementation
                    if (!solution_found) begin
                        if (current_resident == resident_count) begin
                            // Check if current assignment is valid
                            logic valid = 1;
                            logic [3:0] temp_party_counts [0:4];
                            for (int i = 0; i < 4; i++) temp_party_counts[i] = 0;

                            // Check party balance constraint
                            for (int i = 0; i < resident_count; i++) begin
                                logic [7:0] party = residents[i].party;
                                for (int p = 0; p < 4; p++) begin
                                    if (party == p) begin
                                        temp_party_counts[p] = temp_party_counts[p] + 1;
                                    end
                                end
                            end

                            for (int p = 0; p < 4; p++) begin
                                if (temp_party_counts[p] >= (club_count + 1)/2) begin
                                    valid = 0;
                                end
                            end

                            if (valid) begin
                                solution_found = 1;
                                next_state = OUTPUT;
                            end else begin
                                // Backtrack
                                current_resident = current_resident - 1;
                                current_club = current_club + 1;
                            end
                        end else begin
                            // Try next club for current resident
                            if (current_club < club_count && 
                                (residents[current_resident].clubs & (1 << current_club))) begin
                                // Check if this club is already assigned to another resident
                                logic club_used = 0;
                                for (int i = 0; i < current_resident; i++) begin
                                    if (assignment[i] == current_club) begin
                                        club_used = 1;
                                    end
                                end

                                if (!club_used) begin
                                    assignment[current_resident] = current_club;
                                    current_resident = current_resident + 1;
                                    current_club = 0;
                                end else begin
                                    current_club = current_club + 1;
                                end
                            end else begin
                                // Backtrack
                                current_resident = current_resident - 1;
                                current_club = current_club + 1;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    if (output_index < resident_count) begin
                        result_club_id <= assignment[output_index];
                        result_resident_id <= residents[output_index].id;
                        result_valid <= 1;
                        output_index <= output_index + 1;
                    end else begin
                        result_valid <= 0;
                        next_state = DONE;
                    end
                end

                DONE: begin
                    if (solution_found) begin
                        solved <= 1;
                    end else begin
                        impossible <= 1;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    resident_count = 0;
                    club_count = num_clubs;
                    solution_found = 0;
                    current_resident = 0;
                    current_club = 0;
                    output_index = 0;
                end
            end

            LOAD: begin
                if (resident_count == num_residents) begin
                    next_state = SOLVE;
                end
            end

            SOLVE: begin
                if (solution_found) begin
                    next_state = OUTPUT;
                end else if (current_resident == 0 && current_club == club_count) begin
                    next_state = DONE;
                end
            end

            OUTPUT: begin
                if (output_index == resident_count) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule