module CandidateTellerSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] stmt_count,
    input wire [2:0] speaker_id,
    input wire [3:0] stmt_type,
    input wire [2:0] arg1,
    input wire [2:0] arg2,
    input wire [1:0] arg1_type,
    output reg result_valid,
    output reg [2:0] result,
    output reg [1:0] result_type,
    output reg busy,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] SEARCH     = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] DONE       = 3'd4;

    // Memory arrays (packed for efficiency)
    reg [2:0] stmt_speaker[0:99];
    reg [5:0] stmt_args[0:99];      // {arg2[2:0], arg1[2:0]}
    reg [3:0] stmt_op[0:99];
    reg [1:0] stmt_arg1_type[0:99]; // For base propositions

    // Computation registers
    reg [2:0] state, next_state;
    reg [6:0] stmt_idx;
    reg [11:0] assignment;          // 3^7 = 2187 < 4096 (12 bits) - packed types
    reg [2:0] current_candidate;
    reg [6:0] k_counter;
    reg [2:0] p_value;
    reg [2:0] current_speaker_type;
    reg stmt_eval_result;
    reg valid_assignment;
    reg charlatan_valid;
    reg [2:0] output_counter;
    reg [2:0] result_buffer;
    reg [1:0] result_type_buffer;
    reg result_valid_buffer;
    reg done_buffer;

    // Helper function to get type of candidate from packed assignment
    function automatic [1:0] get_type;
        input [11:0] assignments;
        input [2:0] cand_id;
        integer offset;
        begin
            // cand_id is 1-7, map to 0-6
            offset = (cand_id - 1) * 2;
            get_type = assignments[offset +: 2];
        end
    endfunction

    // Helper function to evaluate a single statement
    function automatic logic evaluate_stmt;
        input [11:0] assignments;
        input [2:0] speaker;
        input [3:0] op;
        input [5:0] args_packed;
        input [1:0] a1_type;
        integer a1, a2;
        logic t1, t2, val1, val2;
        begin
            a1 = args_packed[2:0];
            a2 = args_packed[5:3];
            
            // Get actual types for arguments
            t1 = (op == 4'd0 || op == 4'd1 || op == 4'd2) ? 
                 (a1 == speaker) : (a1 == speaker);
            
            if (op < 4'd3) begin
                // Base: truther(n), fabulist(n), charlatan(n)
                // Evaluates to true if candidate n is of claimed type
                val1 = (get_type(assignments, a1) == op);
                evaluate_stmt = val1;
            end else if (op == 4'd3) begin
                // Not
                val1 = evaluate_stmt_internal(assignments, speaker, a1, a1_type);
                evaluate_stmt = !val1;
            end else if (op == 4'd4) begin
                // And
                val1 = evaluate_stmt_internal(assignments, speaker, a1, a1_type);
                val2 = evaluate_stmt_internal(assignments, speaker, a2, a1_type);
                evaluate_stmt = val1 && val2;
            end else if (op == 4'd5) begin
                // Xor
                val1 = evaluate_stmt_internal(assignments, speaker, a1, a1_type);
                val2 = evaluate_stmt_internal(assignments, speaker, a2, a1_type);
                evaluate_stmt = val1 ^ val2;
            end else begin
                evaluate_stmt = 1'b0;
            end
        end
    endfunction

    // Recursive helper for nested statements
    function automatic logic evaluate_stmt_internal;
        input [11:0] assignments;
        input [2:0] speaker;
        input [2:0] arg_id;
        input [1:0] arg_type;
        logic val;
        begin
            if (arg_id == 3'd0) begin
                // arg0 means base proposition using arg1_type
                val = (get_type(assignments, speaker) == arg_type);
            end else begin
                // Would need to look up statement, simplified for now
                val = 1'b0;
            end
            evaluate_stmt_internal = val;
        end
    endfunction

    // Combinational evaluation logic
    always @(*) begin
        stmt_eval_result = 1'b0;
        charlatan_valid = 1'b0;
        
        // Evaluate current statement
        stmt_eval_result = evaluate_stmt(
            assignment,
            stmt_speaker[stmt_idx],
            stmt_op[stmt_idx],
            stmt_args[stmt_idx],
            stmt_arg1_type[stmt_idx]
        );
        
        // Check charlatan validity
        if (current_speaker_type == 2'd2) begin
            // All true up to P, false after
            charlatan_valid = 1'b1;
            for (k_counter = 0; k_counter < stmt_count; k_counter = k_counter + 1) begin
                logic ev = evaluate_stmt(
                    assignment,
                    stmt_speaker[k_counter],
                    stmt_op[k_counter],
                    stmt_args[k_counter],
                    stmt_arg1_type[k_counter]
                );
                if (k_counter < p_value) begin
                    if (!ev) charlatan_valid = 1'b0;
                end else begin
                    if (ev) charlatan_valid = 1'b0;
                end
            end
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            result_valid <= 1'b0;
            result <= 3'd0;
            result_type <= 2'd0;
            stmt_idx <= 7'd0;
            assignment <= 12'd0;
            current_candidate <= 3'd0;
            output_counter <= 3'd0;
            done_buffer <= 1'b0;
            result_buffer <= 3'd0;
            result_type_buffer <= 2'd0;
            result_valid_buffer <= 1'b0;
            valid_assignment <= 1'b0;
            p_value <= 3'd0;
            current_speaker_type <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        busy <= 1'b1;
                        stmt_idx <= 7'd0;
                        assignment <= 12'd0;
                        output_counter <= 3'd0;
                    end
                end

                LOAD: begin
                    // Store current statement
                    if (stmt_idx < stmt_count) begin
                        stmt_speaker[stmt_idx] <= speaker_id;
                        stmt_args[stmt_idx] <= {arg2, arg1};
                        stmt_op[stmt_idx] <= stmt_type;
                        stmt_arg1_type[stmt_idx] <= arg1_type;
                        stmt_idx <= stmt_idx + 7'd1;
                        // Stay in LOAD, expect next cycle's input
                    end else begin
                        // Loading complete
                        state <= SEARCH;
                        assignment <= 12'd0;
                        current_candidate <= 3'd0;
                        valid_assignment <= 1'b0;
                    end
                end

                SEARCH: begin
                    // Iterate through all 3^7 assignments
                    // Simplified: just check first valid assignment
                    if (assignment < 12'd2187) begin
                        // Check this assignment
                        current_speaker_type <= get_type(assignment, speaker_id);
                        
                        // Check all statements for this speaker
                        if (current_speaker_type == 2'd0) begin
                            // Truther: all true
                            if (stmt_idx < stmt_count) begin
                                if (evaluate_stmt(assignment, stmt_speaker[stmt_idx], stmt_op[stmt_idx], stmt_args[stmt_idx], stmt_arg1_type[stmt_idx])) begin
                                    if (stmt_idx == stmt_count - 1) begin
                                        valid_assignment <= 1'b1;
                                        state <= OUTPUT;
                                        output_counter <= 3'd1;
                                    end
                                    stmt_idx <= stmt_idx + 7'd1;
                                end else begin
                                    // Failed, next assignment
                                    stmt_idx <= 7'd0;
                                    assignment <= assignment + 12'd1;
                                end
                            end
                        end else if (current_speaker_type == 2'd1) begin
                            // Fabulist: all false
                            if (stmt_idx < stmt_count) begin
                                if (!evaluate_stmt(assignment, stmt_speaker[stmt_idx], stmt_op[stmt_idx], stmt_args[stmt_idx], stmt_arg1_type[stmt_idx])) begin
                                    if (stmt_idx == stmt_count - 1) begin
                                        valid_assignment <= 1'b1;
                                        state <= OUTPUT;
                                        output_counter <= 3'd1;
                                    end
                                    stmt_idx <= stmt_idx + 7'd1;
                                end else begin
                                    stmt_idx <= 7'd0;
                                    assignment <= assignment + 12'd1;
                                end
                            end
                        end else if (current_speaker_type == 2'd2) begin
                            // Charlatan: exists P
                            if (p_value <= stmt_count) begin
                                if (charlatan_valid) begin
                                    if (stmt_idx == stmt_count - 1) begin
                                        valid_assignment <= 1'b1;
                                        state <= OUTPUT;
                                        output_counter <= 3'd1;
                                    end
                                    stmt_idx <= stmt_idx + 7'd1;
                                end else begin
                                    // Try next P or next assignment
                                    if (p_value < stmt_count) begin
                                        p_value <= p_value + 3'd1;
                                    end else begin
                                        p_value <= 3'd0;
                                        assignment <= assignment + 12'd1;
                                    end
                                end
                            end
                        end
                    end else begin
                        // No valid assignment found
                        valid_assignment <= 1'b0;
                        state <= DONE;
                    end
                end

                OUTPUT: begin
                    // Emit results for candidates 1..N
                    if (output_counter <= 7'd7 && output_counter <= stmt_count) begin
                        result <= output_counter;
                        result_type <= get_type(assignment, output_counter);
                        result_valid <= 1'b1;
                        output_counter <= output_counter + 3'd1;
                        done <= 1'b1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    if (!valid_assignment) begin
                        result_valid <= 1'b0;
                    end
                    if (output_counter == 3'd0) begin
                        // Wait for start to go low
                        if (!start) begin
                            state <= IDLE;
                            done <= 1'b0;
                        end
                    end else begin
                        // Continue outputting
                        if (output_counter <= 7'd7 && output_counter <= stmt_count) begin
                            result <= output_counter;
                            result_type <= get_type(assignment, output_counter);
                            result_valid <= 1'b1;
                            output_counter <= output_counter + 3'd1;
                        end else begin
                            state <= IDLE;
                            done <= 1'b0;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule