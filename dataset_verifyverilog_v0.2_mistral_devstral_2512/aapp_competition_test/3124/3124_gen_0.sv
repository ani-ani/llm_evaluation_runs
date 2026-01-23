module ivana_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_bits,
    input [2:0] N,
    output reg [3:0] result,
    output reg done
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COMPUTE_STATES,
        EVALUATE_MOVES,
        DONE
    } state_t;

    state_t current_state, next_state;

    // State memory (256 states, 8-bit signed outcome)
    reg signed [7:0] state_memory [0:255];

    // Counters and registers
    reg [7:0] state_counter;
    reg [7:0] move_counter;
    reg [7:0] current_mask;
    reg [7:0] temp_mask;
    reg [7:0] best_outcome;
    reg [7:0] current_outcome;
    reg [7:0] winning_moves;

    // Flags
    reg state_computed;
    reg move_evaluated;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            state_counter <= 0;
            move_counter <= 0;
            current_mask <= 0;
            temp_mask <= 0;
            best_outcome <= 0;
            current_outcome <= 0;
            winning_moves <= 0;
            state_computed <= 0;
            move_evaluated <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = COMPUTE_STATES;
            end
            COMPUTE_STATES: begin
                if (state_computed) next_state = EVALUATE_MOVES;
            end
            EVALUATE_MOVES: begin
                if (move_evaluated) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Compute states logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_computed <= 0;
        end else if (current_state == COMPUTE_STATES) begin
            // Initialize state counter
            if (state_counter == 0) begin
                state_counter <= 1;
            end else begin
                // Compute outcome for current state
                current_outcome = compute_outcome(state_counter, N, num_bits, state_memory);
                state_memory[state_counter] = current_outcome;

                // Increment state counter
                state_counter <= state_counter + 1;

                // Check if all states are computed
                if (state_counter == 255) begin
                    state_computed <= 1;
                end
            end
        end
    end

    // Evaluate moves logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            move_evaluated <= 0;
        end else if (current_state == EVALUATE_MOVES) begin
            // Initialize move counter
            if (move_counter == 0) begin
                move_counter <= 1;
            end else begin
                // Evaluate current move
                temp_mask = 1 << (move_counter - 1);
                current_outcome = evaluate_move(temp_mask, N, num_bits, state_memory);

                // Count winning moves
                if (current_outcome > 0) begin
                    winning_moves <= winning_moves + 1;
                end

                // Increment move counter
                move_counter <= move_counter + 1;

                // Check if all moves are evaluated
                if (move_counter == N) begin
                    move_evaluated <= 1;
                    result <= winning_moves;
                    done <= 1;
                end
            end
        end
    end

    // Function to compute outcome for a given state
    function signed [7:0] compute_outcome(
        input [7:0] mask,
        input [2:0] N,
        input [7:0] num_bits,
        input signed [7:0] state_memory [0:255]
    );
        reg [7:0] i;
        reg [7:0] temp_mask;
        reg [7:0] best_outcome;
        reg [7:0] current_outcome;
        reg [7:0] adjacent_mask;
        reg [7:0] available_moves;

        // Check if terminal state
        if (mask == (1 << N) - 1) begin
            // Count odd bits for Ivana and Zvonko
            // Since it's terminal, outcome is difference in odd counts
            // This is simplified for the problem
            compute_outcome = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (num_bits[i]) begin
                    compute_outcome = compute_outcome + 1;
                end
            end
        end else begin
            // Determine available moves
            available_moves = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (!(mask[i])) begin
                    // Check adjacency
                    adjacent_mask = (mask << 1) | (mask >> 1);
                    if ((adjacent_mask[i] || (mask == 0)) && (i == 0 || mask[i-1] || (i == N-1 && mask[N-1]))) begin
                        available_moves[i] = 1;
                    end
                end
            end

            // Evaluate all available moves
            best_outcome = -128;
            for (i = 0; i < N; i = i + 1) begin
                if (available_moves[i]) begin
                    temp_mask = mask | (1 << i);
                    current_outcome = state_memory[temp_mask];
                    if (current_outcome > best_outcome) begin
                        best_outcome = current_outcome;
                    end
                end
            end

            // If no moves available, it's a terminal state
            if (available_moves == 0) begin
                compute_outcome = 0;
                for (i = 0; i < N; i = i + 1) begin
                    if (num_bits[i]) begin
                        compute_outcome = compute_outcome + 1;
                    end
                end
            end else begin
                compute_outcome = best_outcome;
            end
        end
    endfunction

    // Function to evaluate a move
    function signed [7:0] evaluate_move(
        input [7:0] move_mask,
        input [2:0] N,
        input [7:0] num_bits,
        input signed [7:0] state_memory [0:255]
    );
        reg [7:0] i;
        reg [7:0] temp_mask;
        reg [7:0] best_outcome;
        reg [7:0] current_outcome;
        reg [7:0] adjacent_mask;
        reg [7:0] available_moves;

        // Determine available moves after initial move
        available_moves = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (!(move_mask[i])) begin
                // Check adjacency
                adjacent_mask = (move_mask << 1) | (move_mask >> 1);
                if ((adjacent_mask[i] || (move_mask == 0)) && (i == 0 || move_mask[i-1] || (i == N-1 && move_mask[N-1]))) begin
                    available_moves[i] = 1;
                end
            end
        end

        // Evaluate all available moves
        best_outcome = -128;
        for (i = 0; i < N; i = i + 1) begin
            if (available_moves[i]) begin
                temp_mask = move_mask | (1 << i);
                current_outcome = state_memory[temp_mask];
                if (current_outcome > best_outcome) begin
                    best_outcome = current_outcome;
                end
            end
        end

        // If no moves available, it's a terminal state
        if (available_moves == 0) begin
            evaluate_move = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (num_bits[i]) begin
                    evaluate_move = evaluate_move + 1;
                end
            end
        end else begin
            evaluate_move = best_outcome;
        end
    endfunction

endmodule