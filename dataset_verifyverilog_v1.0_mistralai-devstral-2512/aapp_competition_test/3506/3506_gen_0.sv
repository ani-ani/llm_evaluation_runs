module football_cheer_top(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [6:0] t,
    input wire [31:0] opponent_low,
    input wire [31:0] opponent_mid,
    input wire [25:0] opponent_high,
    output reg [4:0] sportify_score,
    output reg [4:0] spoilify_score,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;

    // Internal registers
    reg [2:0] state, next_state;
    reg [6:0] minute_counter;
    reg [10:0] budget_used;
    reg [3:0] consecutive_streak;
    reg [1:0] streak_owner; // 0: none, 1: us, 2: them
    reg [4:0] current_sportify;
    reg [4:0] current_spoilify;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd100;

    // Opponent schedule concatenation
    wire [89:0] opponent_schedule = {opponent_high, opponent_mid, opponent_low};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            minute_counter <= 7'd0;
            budget_used <= 11'd0;
            consecutive_streak <= 4'd0;
            streak_owner <= 2'd0;
            current_sportify <= 5'd0;
            current_spoilify <= 5'd0;
            sportify_score <= 5'd0;
            spoilify_score <= 5'd0;
            done <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= PROCESS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Process current minute
                    reg should_cheer;
                    reg [3:0] cheer_amount;
                    
                    // Greedy decision: cheer if opponent is active and we have budget
                    if (opponent_schedule[minute_counter] && (budget_used < (n * t))) begin
                        should_cheer = 1'b1;
                        cheer_amount = 4'd1; // Cheer with 1 cheerleader
                    end else begin
                        should_cheer = 1'b0;
                        cheer_amount = 4'd0;
                    end
                    
                    // Update budget
                    if (should_cheer) begin
                        budget_used <= budget_used + 11'd1;
                    end
                    
                    // Calculate net advantage for this minute
                    reg signed [1:0] net_adv;
                    if (should_cheer) begin
                        net_adv = 2'd1; // We cheer, opponent active: +1
                    end else if (opponent_schedule[minute_counter]) begin
                        net_adv = 2'd0; // Opponent active, we don't cheer: 0
                    end else begin
                        net_adv = 2'd0; // Neither active: 0
                    end
                    
                    // Update streak
                    if (net_adv == 2'd1) begin
                        if (streak_owner == 2'd1) begin
                            consecutive_streak <= consecutive_streak + 4'd1;
                        end else begin
                            consecutive_streak <= 4'd1;
                            streak_owner <= 2'd1;
                        end
                    end else if (net_adv == 2'd0 && opponent_schedule[minute_counter]) begin
                        if (streak_owner == 2'd2) begin
                            consecutive_streak <= consecutive_streak + 4'd1;
                        end else begin
                            consecutive_streak <= 4'd1;
                            streak_owner <= 2'd2;
                        end
                    end else begin
                        consecutive_streak <= 4'd0;
                        streak_owner <= 2'd0;
                    end
                    
                    // Check for score
                    if (consecutive_streak >= 4'd5) begin
                        if (streak_owner == 2'd1) begin
                            current_sportify <= current_sportify + 5'd1;
                        end else if (streak_owner == 2'd2) begin
                            current_spoilify <= current_spoilify + 5'd1;
                        end
                        consecutive_streak <= 4'd0;
                        streak_owner <= 2'd0;
                    end
                    
                    // Move to next minute
                    if (minute_counter == 7'd89) begin
                        next_state <= FINISH;
                    end else begin
                        minute_counter <= minute_counter + 7'd1;
                        next_state <= PROCESS;
                    end
                end

                FINISH: begin
                    sportify_score <= current_sportify;
                    spoilify_score <= current_spoilify;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Reset minute counter when starting new process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            minute_counter <= 7'd0;
        end else if (state == IDLE && start) begin
            minute_counter <= 7'd0;
        end
    end

    // Reset budget when starting new process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            budget_used <= 11'd0;
        end else if (state == IDLE && start) begin
            budget_used <= 11'd0;
        end
    end

    // Reset streak when starting new process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            consecutive_streak <= 4'd0;
            streak_owner <= 2'd0;
        end else if (state == IDLE && start) begin
            consecutive_streak <= 4'd0;
            streak_owner <= 2'd0;
        end
    end

    // Reset scores when starting new process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_sportify <= 5'd0;
            current_spoilify <= 5'd0;
        end else if (state == IDLE && start) begin
            current_sportify <= 5'd0;
            current_spoilify <= 5'd0;
        end
    end

endmodule