module duel_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] initial_state,
    input wire [3:0] k,
    output reg [1:0] result,
    output reg done
);

    // Parameters
    localparam [7:0] MAX_CYCLES = 8'd256;
    localparam [7:0] STATE_WIDTH = 8'd8;
    localparam [3:0] MAX_K = 4'd8;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_START = 3'd1;
    localparam [2:0] CHECK_WIN = 3'd2;
    localparam [2:0] CHECK_HISTORY = 3'd3;
    localparam [2:0] MAKE_MOVE = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    // Result definitions
    localparam [1:0] TOKI_WIN = 2'd0;
    localparam [1:0] QUAILTY_WIN = 2'd1;
    localparam [1:0] ONCE_AGAIN = 2'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    reg [1:0] turn_counter;  // 0=Toki, 1=Quailty
    reg [7:0] current_state;
    reg [15:0] state_history [0:7];  // Store last 8 states
    reg [3:0] history_idx;
    
    // Temporary registers for computation
    reg [7:0] temp_state;
    reg [3:0] flip_start;
    reg [3:0] check_idx;
    reg found_win;
    reg found_history;
    reg [7:0] compare_state;
    
    // Helper wires
    wire all_same;
    assign all_same = (current_state == 8'b00000000) || (current_state == 8'b11111111);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_state <= 8'd0;
            cycle_count <= 8'd0;
            turn_counter <= 2'd0;
            history_idx <= 4'd0;
            done <= 1'b0;
            result <= 2'd0;
            temp_state <= 8'd0;
            flip_start <= 4'd0;
            check_idx <= 4'd0;
            found_win <= 1'b0;
            found_history <= 1'b0;
            compare_state <= 8'd0;
            // Initialize history array
            state_history[0] <= 16'd0;
            state_history[1] <= 16'd0;
            state_history[2] <= 16'd0;
            state_history[3] <= 16'd0;
            state_history[4] <= 16'd0;
            state_history[5] <= 16'd0;
            state_history[6] <= 16'd0;
            state_history[7] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    turn_counter <= 2'd0;
                    history_idx <= 4'd0;
                    if (start) begin
                        current_state <= initial_state;
                        state <= CHECK_START;
                    end
                end
                
                CHECK_START: begin
                    if (all_same) begin
                        // Initial state already uniform
                        if (turn_counter == 2'd0) begin
                            result <= TOKI_WIN;
                        end else begin
                            result <= QUAILTY_WIN;
                        end
                        state <= FINISH;
                    end else begin
                        state <= CHECK_WIN;
                        check_idx <= 4'd0;
                        temp_state <= current_state;
                        found_win <= 1'b0;
                    end
                end
                
                CHECK_WIN: begin
                    // Check if current player can win in this turn
                    if (check_idx <= STATE_WIDTH - k) begin
                        // Try flipping to all 0s
                        temp_state <= current_state;
                        for (integer j = 0; j < 8; j = j + 1) begin
                            if (j >= check_idx && j < (check_idx + k)) begin
                                temp_state[j] <= 1'b0;
                            end
                        end
                        if (temp_state == 8'b00000000 || temp_state == 8'b11111111) begin
                            found_win <= 1'b1;
                            state <= FINISH;
                            if (turn_counter == 2'd0) begin
                                result <= TOKI_WIN;
                            end else begin
                                result <= QUAILTY_WIN;
                            end
                        end else begin
                            // Try flipping to all 1s
                            temp_state <= current_state;
                            for (integer j = 0; j < 8; j = j + 1) begin
                                if (j >= check_idx && j < (check_idx + k)) begin
                                    temp_state[j] <= 1'b1;
                                end
                            end
                            if (temp_state == 8'b00000000 || temp_state == 8'b11111111) begin
                                found_win <= 1'b1;
                                state <= FINISH;
                                if (turn_counter == 2'd0) begin
                                    result <= TOKI_WIN;
                                end else begin
                                    result <= QUAILTY_WIN;
                                end
                            end else begin
                                check_idx <= check_idx + 4'd1;
                            end
                        end
                    end else begin
                        // No immediate win found
                        state <= CHECK_HISTORY;
                        found_history <= 1'b0;
                        check_idx <= 4'd0;
                    end
                end
                
                CHECK_HISTORY: begin
                    // Check if current state has been seen before
                    if (check_idx < history_idx && check_idx < 4'd8) begin
                        if (state_history[check_idx][7:0] == current_state) begin
                            found_history <= 1'b1;
                            state <= FINISH;
                            result <= ONCE_AGAIN;
                        end else begin
                            check_idx <= check_idx + 4'd1;
                        end
                    end else begin
                        // No cycle found, make a move
                        state <= MAKE_MOVE;
                        temp_state <= current_state;
                        flip_start <= 4'd0;
                    end
                end
                
                MAKE_MOVE: begin
                    // Make a move (flip first k cards to create alternating pattern)
                    if (flip_start < k && flip_start < STATE_WIDTH) begin
                        temp_state[flip_start] <= turn_counter[0] ? 1'b1 : 1'b0;
                        flip_start <= flip_start + 4'd1;
                    end else begin
                        // Store current state in history
                        if (history_idx < 4'd8) begin
                            state_history[history_idx][7:0] <= current_state;
                            history_idx <= history_idx + 4'd1;
                        end else begin
                            // Shift history if full
                            for (integer i = 0; i < 7; i = i + 1) begin
                                state_history[i] <= state_history[i + 1];
                            end
                            state_history[7][7:0] <= current_state;
                        end
                        
                        current_state <= temp_state;
                        cycle_count <= cycle_count + 8'd1;
                        turn_counter <= turn_counter + 2'd1;
                        
                        // Check for draw by cycle count
                        if (cycle_count >= MAX_CYCLES - 8'd1) begin
                            state <= FINISH;
                            result <= ONCE_AGAIN;
                        end else begin
                            state <= CHECK_START;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule