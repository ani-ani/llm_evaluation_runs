module prime_game_scoring(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] dp_data_in,
    input wire [13:0] dp_addr_out,
    input wire [1:0] round_player_in,
    input wire [13:0] round_num_in,
    output reg [15:0] score_odd,
    output reg [15:0] score_even,
    output reg [15:0] score_ing,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_ROUND = 3'd1;
    localparam [2:0] PROCESS_TURN = 3'd2;
    localparam [2:0] UPDATE_SCORES = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Player definitions
    localparam [1:0] PLAYER_ODD = 2'd0;
    localparam [1:0] PLAYER_EVEN = 2'd1;
    localparam [1:0] PLAYER_ING = 2'd2;

    // Registers
    reg [2:0] state, next_state;
    reg [9:0] round_counter;
    reg [1:0] current_player;
    reg [13:0] current_number;
    reg [15:0] min_claimed [0:2];
    reg [15:0] dp_data_reg;
    reg [13:0] dp_addr_reg;
    reg dp_valid;
    reg [13:0] next_number;
    reg [1:0] next_player;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            round_counter <= 10'd0;
            current_player <= 2'd0;
            current_number <= 14'd0;
            min_claimed[0] <= 16'd0;
            min_claimed[1] <= 16'd0;
            min_claimed[2] <= 16'd0;
            dp_data_reg <= 16'd0;
            dp_addr_reg <= 14'd0;
            dp_valid <= 1'b0;
            next_number <= 14'd0;
            next_player <= 2'd0;
            score_odd <= 16'd0;
            score_even <= 16'd0;
            score_ing <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_ROUND;
                        busy <= 1'b1;
                    end
                end
                
                LOAD_ROUND: begin
                    // Load starting state for current round
                    current_player <= round_player_in;
                    current_number <= round_num_in;
                    
                    // Initialize min claimed for this round
                    min_claimed[0] <= 16'd10000;
                    min_claimed[1] <= 16'd10000;
                    min_claimed[2] <= 16'd10000;
                    
                    // Request DP data for current number
                    dp_addr_reg <= current_number;
                    dp_valid <= 1'b0;
                    
                    if (current_number > 14'd1) begin
                        next_state <= PROCESS_TURN;
                    end else begin
                        next_state <= UPDATE_SCORES;
                    end
                end
                
                PROCESS_TURN: begin
                    // Process DP response
                    if (dp_valid) begin
                        // Parse DP data: [15:14] = move type (0=add, 1=divide), [13:0] = next number
                        next_number <= dp_data_reg[13:0];
                        
                        // Update current player's min claimed
                        if (current_number < min_claimed[current_player]) begin
                            min_claimed[current_player] <= current_number;
                        end
                        
                        // Determine next player
                        if (current_player == PLAYER_ODD) begin
                            next_player <= PLAYER_EVEN;
                        end else if (current_player == PLAYER_EVEN) begin
                            next_player <= PLAYER_ING;
                        end else begin
                            next_player <= PLAYER_ODD;
                        end
                        
                        // Update state
                        current_number <= next_number;
                        current_player <= next_player;
                        
                        // Request next DP data if needed
                        if (next_number > 14'd1) begin
                            dp_addr_reg <= next_number;
                            dp_valid <= 1'b0;
                        end else begin
                            next_state <= UPDATE_SCORES;
                        end
                    end
                end
                
                UPDATE_SCORES: begin
                    // Update scores based on min claimed
                    if (min_claimed[PLAYER_ODD] == 16'd10000) begin
                        score_odd <= score_odd + round_num_in;
                    end else begin
                        score_odd <= score_odd + min_claimed[PLAYER_ODD];
                    end
                    
                    if (min_claimed[PLAYER_EVEN] == 16'd10000) begin
                        score_even <= score_even + round_num_in;
                    end else begin
                        score_even <= score_even + min_claimed[PLAYER_EVEN];
                    end
                    
                    if (min_claimed[PLAYER_ING] == 16'd10000) begin
                        score_ing <= score_ing + round_num_in;
                    end else begin
                        score_ing <= score_ing + min_claimed[PLAYER_ING];
                    end
                    
                    // Increment round counter
                    round_counter <= round_counter + 10'd1;
                    
                    if (round_counter == 10'd999) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= LOAD_ROUND;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // DP interface - simulate memory response
    always @(posedge clk) begin
        if (dp_addr_reg != 14'd0) begin
            // Simulate memory read (in real hardware, this would be external)
            dp_data_reg <= dp_data_in;
            dp_valid <= 1'b1;
        end
    end

endmodule