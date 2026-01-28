module CandidateCharacterSolver(
    input clk,
    input rst_n,
    input start,
    input [6:0] stmt_count,
    input [2:0] speaker_id,
    input [3:0] stmt_type,
    input [2:0] arg1,
    input [2:0] arg2,
    input [1:0] arg1_type,
    output reg result_valid,
    output reg [2:0] result,
    output reg [1:0] result_type,
    output reg busy,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] SEARCH   = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    reg [2:0] state, next_state;

    // Statement storage
    reg [2:0] stmt_speaker [0:99];
    reg [5:0] stmt_args [0:99];
    reg [3:0] stmt_op [0:99];

    // Search variables
    reg [2:0] candidate;
    reg [1:0] candidate_type;
    reg [1:0] type_assignment [0:6];
    reg [6:0] stmt_idx;
    reg [6:0] search_idx;
    reg [6:0] output_idx;

    // Flags
    reg valid_assignment;
    reg [2:0] valid_candidate;
    reg [1:0] valid_type;

    // Cycle counter for safety
    reg [17:0] cycle_count;
    localparam [17:0] MAX_CYCLES = 18'd250000;

    // Evaluate statement function
    function automatic evaluate_statement;
        input [1:0] types [0:6];
        input [2:0] speaker;
        input [3:0] op;
        input [2:0] a1;
        input [2:0] a2;
        input [1:0] a1_type;
        reg [1:0] speaker_type;
        reg val1, val2, result_val;

        begin
            speaker_type = types[speaker - 3'd1];

            case (op)
                4'd0: begin // truthers
                    result_val = (speaker_type == 2'd0);
                end
                4'd1: begin // fabulists
                    result_val = (speaker_type == 2'd1);
                end
                4'd2: begin // charlatans
                    result_val = (speaker_type == 2'd2);
                end
                4'd3: begin // not
                    val1 = evaluate_statement(types, a1, stmt_op[a1], stmt_args[a1][5:3], stmt_args[a1][2:0], stmt_args[a1][5:3]);
                    result_val = !val1;
                end
                4'd4: begin // and
                    val1 = evaluate_statement(types, a1, stmt_op[a1], stmt_args[a1][5:3], stmt_args[a1][2:0], stmt_args[a1][5:3]);
                    val2 = evaluate_statement(types, a2, stmt_op[a2], stmt_args[a2][5:3], stmt_args[a2][2:0], stmt_args[a2][5:3]);
                    result_val = val1 && val2;
                end
                4'd5: begin // xor
                    val1 = evaluate_statement(types, a1, stmt_op[a1], stmt_args[a1][5:3], stmt_args[a1][2:0], stmt_args[a1][5:3]);
                    val2 = evaluate_statement(types, a2, stmt_op[a2], stmt_args[a2][5:3], stmt_args[a2][2:0], stmt_args[a2][5:3]);
                    result_val = val1 ^ val2;
                end
                default: result_val = 1'b0;
            endcase

            evaluate_statement = result_val;
        end
    endfunction

    // Check if assignment is valid
    function automatic check_assignment;
        input [1:0] types [0:6];
        reg [6:0] i, p;
        reg all_true, all_false, has_switch;

        begin
            check_assignment = 1'b0;

            // Check for truthers (all statements true)
            all_true = 1'b1;
            for (i = 0; i < stmt_count; i = i + 1) begin
                if (!evaluate_statement(types, stmt_speaker[i], stmt_op[i], stmt_args[i][5:3], stmt_args[i][2:0], stmt_args[i][5:3])) begin
                    all_true = 1'b0;
                end
            end

            if (all_true) begin
                check_assignment = 1'b1;
                return;
            end

            // Check for fabulists (all statements false)
            all_false = 1'b1;
            for (i = 0; i < stmt_count; i = i + 1) begin
                if (evaluate_statement(types, stmt_speaker[i], stmt_op[i], stmt_args[i][5:3], stmt_args[i][2:0], stmt_args[i][5:3])) begin
                    all_false = 1'b0;
                end
            end

            if (all_false) begin
                check_assignment = 1'b1;
                return;
            end

            // Check for charlatans (switch point exists)
            has_switch = 1'b0;
            for (p = 1; p <= stmt_count; p = p + 1) begin
                all_true = 1'b1;
                for (i = 0; i < p; i = i + 1) begin
                    if (!evaluate_statement(types, stmt_speaker[i], stmt_op[i], stmt_args[i][5:3], stmt_args[i][2:0], stmt_args[i][5:3])) begin
                        all_true = 1'b0;
                    end
                end

                all_false = 1'b1;
                for (i = p; i < stmt_count; i = i + 1) begin
                    if (evaluate_statement(types, stmt_speaker[i], stmt_op[i], stmt_args[i][5:3], stmt_args[i][2:0], stmt_args[i][5:3])) begin
                        all_false = 1'b0;
                    end
                end

                if (all_true && all_false) begin
                    has_switch = 1'b1;
                end
            end

            check_assignment = has_switch;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_valid <= 1'b0;
            result <= 3'd0;
            result_type <= 2'd0;
            busy <= 1'b0;
            done <= 1'b0;
            cycle_count <= 18'd0;

            // Initialize statement storage
            integer i;
            for (i = 0; i < 100; i = i + 1) begin
                stmt_speaker[i] <= 3'd0;
                stmt_args[i] <= 6'd0;
                stmt_op[i] <= 4'd0;
            end

            // Initialize search variables
            candidate <= 3'd0;
            candidate_type <= 2'd0;
            stmt_idx <= 7'd0;
            search_idx <= 7'd0;
            output_idx <= 7'd0;
            valid_assignment <= 1'b0;
            valid_candidate <= 3'd0;
            valid_type <= 2'd0;

            // Initialize type assignment
            for (i = 0; i < 7; i = i + 1) begin
                type_assignment[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 18'd1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    result_valid <= 1'b0;

                    if (start) begin
                        next_state <= LOAD;
                        stmt_idx <= 7'd0;
                        busy <= 1'b1;
                    end
                end

                LOAD: begin
                    // Store current statement
                    stmt_speaker[stmt_idx] <= speaker_id;
                    stmt_args[stmt_idx] <= {arg1, arg2};
                    stmt_op[stmt_idx] <= stmt_type;

                    // Increment index
                    stmt_idx <= stmt_idx + 7'd1;

                    // Check if all statements loaded
                    if (stmt_idx == stmt_count) begin
                        next_state <= SEARCH;
                        stmt_idx <= 7'd0;
                        search_idx <= 7'd0;
                        candidate <= 3'd0;
                        candidate_type <= 2'd0;
                        valid_assignment <= 1'b0;

                        // Initialize type assignment
                        integer i;
                        for (i = 0; i < 7; i = i + 1) begin
                            type_assignment[i] <= 2'd0;
                        end
                    end
                end

                SEARCH: begin
                    // Generate next type assignment
                    type_assignment[search_idx] <= type_assignment[search_idx] + 2'd1;

                    if (type_assignment[search_idx] == 2'd3) begin
                        type_assignment[search_idx] <= 2'd0;
                        search_idx <= search_idx + 7'd1;

                        if (search_idx == 7'd7) begin
                            search_idx <= 7'd0;
                            next_state <= OUTPUT;
                            output_idx <= 7'd0;
                            valid_assignment <= 1'b0;
                        end
                    else begin
                        search_idx <= 7'd0;
                    end
                    end

                    // Check if current assignment is valid
                    if (check_assignment(type_assignment)) begin
                        valid_assignment <= 1'b1;
                        valid_candidate <= candidate;
                        valid_type <= candidate_type;
                        next_state <= OUTPUT;
                        output_idx <= 7'd0;
                    end

                    // Increment candidate and type
                    candidate <= candidate + 3'd1;
                    if (candidate == 3'd7) begin
                        candidate <= 3'd0;
                        candidate_type <= candidate_type + 2'd1;
                        if (candidate_type == 2'd3) begin
                            candidate_type <= 2'd0;
                        end
                    end

                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                OUTPUT: begin
                    if (output_idx == 7'd0) begin
                        if (valid_assignment) begin
                            result_valid <= 1'b1;
                            result <= valid_candidate;
                            result_type <= valid_type;
                        end else begin
                            result_valid <= 1'b0;
                        end
                        done <= 1'b1;
                    end else begin
                        done <= 1'b0;
                    end

                    output_idx <= output_idx + 7'd1;

                    if (output_idx == 7'd1) begin
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule