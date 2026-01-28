module PrimeGameScoring (
    input clk,
    input rst_n,
    input start,
    input [15:0] dp_data_in,
    output reg [13:0] dp_addr_out,
    input [1:0] round_player_in,
    input [13:0] round_num_in,
    output reg [15:0] score_odd,
    output reg [15:0] score_even,
    output reg [15:0] score_ing,
    output reg done,
    output reg busy
);
    // --- State Declarations ---
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_LOAD = 3'd1;
    localparam [2:0] S_LOOKUP = 3'd2;
    localparam [2:0] S_PROCESS = 3'd3;
    localparam [2:0] S_UPDATE = 3'd4;
    localparam [2:0] S_FINISH_ROUND = 3'd5;
    localparam [2:0] S_DONE = 3'd6;

    // --- Game Constants ---
    localparam [13:0] FINAL_NUM = 14'd1; // Terminal condition
    localparam [15:0] TOTAL_ROUNDS = 16'd1000;
    localparam [13:0] MAX_NUM = 14'd10000;

    // --- Registers for State Management ---
    reg [2:0] state, next_state;
    reg [15:0] round_counter;
    reg [1:0] current_player;
    reg [13:0] current_num;
    reg [15:0] min_claimed [0:2]; // 0: Odd, 1: Even, 2: Ing
    reg [15:0] next_min_claimed [0:2];
    reg [1:0] start_player_reg;
    reg [13:0] start_num_reg;

    // --- Helper Registers for Address Calculation ---
    reg [13:0] addr_temp;
    reg [13:0] next_num_temp;

    integer i;

    // --- State Transition Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            round_counter <= 16'd0;
            score_odd <= 16'd0;
            score_even <= 16'd0;
            score_ing <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            current_player <= 2'd0;
            current_num <= 14'd0;
            start_player_reg <= 2'd0;
            start_num_reg <= 14'd0;
            for (i = 0; i < 3; i = i + 1) begin
                min_claimed[i] <= 16'd0;
                next_min_claimed[i] <= 16'd0;
            end
            dp_addr_out <= 14'd0;
        end else begin
            state <= next_state;
            
            // --- Output Flops ---
            if (state == S_IDLE) begin
                busy <= 1'b0;
                done <= 1'b0;
            end else if (state == S_LOAD) begin
                busy <= 1'b1;
                done <= 1'b0;
                current_player <= start_player_reg;
                current_num <= start_num_reg;
                // Initialize min claims
                for (i = 0; i < 3; i = i + 1) begin
                    if (i == start_player_reg)
                        min_claimed[i] <= {2'd0, start_num_reg}; // High value (10000 fits in 14 bits)
                    else
                        min_claimed[i] <= 16'hFFFF; // Max value
                end
            end else if (state == S_PROCESS) begin
                // Pipeline: Calculate address and next num
                addr_temp <= current_num;
                // Result calc happens next cycle
            end else if (state == S_UPDATE) begin
                // Update min claimed for current player
                if (next_num_temp < min_claimed[current_player]) begin
                    min_claimed[current_player] <= {2'd0, next_num_temp};
                end
                // Switch player
                current_player <= current_player + 2'd1;
                if (current_player == 2'd2) current_player <= 2'd0;
                // Update number
                current_num <= next_num_temp;
            end else if (state == S_FINISH_ROUND) begin
                // Add accumulated scores to totals
                if (start_player_reg == 2'd0) // Odd
                    score_odd <= score_odd + min_claimed[0];
                else if (start_player_reg == 2'd1) // Even
                    score_even <= score_even + min_claimed[1];
                else // Ing
                    score_ing <= score_ing + min_claimed[2];
                // Update round counter
                round_counter <= round_counter + 16'd1;
            end else if (state == S_DONE) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end

    // --- Next State Logic & Output Logic ---
    always @(*) begin
        next_state = state;
        dp_addr_out = addr_temp;
        next_num_temp = 14'd0;
        
        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_LOAD;
                end
            end

            S_LOAD: begin
                // Immediately check if we need to lookup or if number is already 1
                if (current_num == FINAL_NUM) begin
                    next_state = S_FINISH_ROUND;
                end else begin
                    next_state = S_LOOKUP;
                    dp_addr_out = current_num; // Trigger lookup
                end
            end

            S_LOOKUP: begin
                // Wait for memory (asynchronous read assumption)
                // Data is valid on dp_data_in now
                // Decode move: data_in[15] is flag, data_in[13:0] is result
                next_state = S_PROCESS;\            end

            S_PROCESS: begin
                // Logic to determine next number based on DP data
                // dp_data_in[15] = 1 means divide, 0 means add
                if (dp_data_in[15]) begin
                    // Divide by prime logic is handled externally, we just use result
                    next_num_temp = dp_data_in[13:0];
                end else begin
                    // Add logic
                    next_num_temp = dp_data_in[13:0];
                end
                
                next_state = S_UPDATE;
            end

            S_UPDATE: begin
                // Check if we reached the end of the round (next_num is 1)
                if (current_num == FINAL_NUM) begin
                    next_state = S_FINISH_ROUND;
                end else begin
                    next_state = S_LOAD;
                end
            end

            S_FINISH_ROUND: begin
                if (round_counter + 16'd1 >= TOTAL_ROUNDS) begin
                    next_state = S_DONE;
                end else begin
                    // Load next round data (Assumed available on inputs)
                    // In a real system, we might need a handshake, but spec implies continuous inputs
                    next_state = S_LOAD;
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // --- Input Sampling Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_player_reg <= 2'd0;
            start_num_reg <= 14'd0;
        end else begin
            if (state == S_IDLE && start) begin
                start_player_reg <= round_player_in;
                start_num_reg <= round_num_in;
            end else if (state == S_FINISH_ROUND && (round_counter + 16'd1 < TOTAL_ROUNDS)) begin
                // Grab next round inputs for next cycle
                start_player_reg <= round_player_in;
                start_num_reg <= round_num_in;
            end
        end
    end

endmodule