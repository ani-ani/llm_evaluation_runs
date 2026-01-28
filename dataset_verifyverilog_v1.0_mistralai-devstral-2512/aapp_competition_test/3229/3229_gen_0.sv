module WorstRankCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] my_scores [0:7],
    input wire [7:0] other_scores [0:15][0:7],
    input wire [3:0] num_participants,
    input wire [2:0] num_contests,
    output reg [4:0] worst_rank,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_SELF = 3'd1;
    localparam [2:0] CALC_OTHERS = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [9:0] self_aggregate;
    reg [9:0] other_aggregate;
    reg [3:0] participant_idx;
    reg [3:0] beat_count;
    reg [2:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Temporary arrays for sorting
    reg [7:0] temp_scores [0:7];
    reg [7:0] temp_self [0:7];
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            self_aggregate <= 10'd0;
            other_aggregate <= 10'd0;
            participant_idx <= 4'd0;
            beat_count <= 4'd0;
            cycle_count <= 3'd0;
            worst_rank <= 5'd0;
            done <= 1'b0;
            
            // Initialize temp arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                temp_scores[i] <= 8'd0;
                temp_self[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 3'd0;
                if (start) begin
                    next_state = CALC_SELF;
                end
            end
            
            CALC_SELF: begin
                // Copy my_scores to temp_self
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    temp_self[i] = my_scores[i];
                end
                
                // Sort temp_self to find top 4
                // Bubble sort for small array
                integer j, k;
                reg [7:0] temp;
                for (j = 0; j < 7; j = j + 1) begin
                    for (k = 0; k < 7 - j; k = k + 1) begin
                        if (temp_self[k] < temp_self[k + 1]) begin
                            temp = temp_self[k];
                            temp_self[k] = temp_self[k + 1];
                            temp_self[k + 1] = temp;
                        end
                    end
                end
                
                // Sum top 4
                self_aggregate = temp_self[0] + temp_self[1] + temp_self[2] + temp_self[3];
                next_state = CALC_OTHERS;
            end
            
            CALC_OTHERS: begin
                // Check if done with all participants
                if (participant_idx >= num_participants - 2) begin
                    next_state = FINISH;
                end else begin
                    // Load current participant's scores
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_scores[i] = other_scores[participant_idx][i];
                    end
                    
                    // Sort temp_scores to find top 4
                    integer j, k;
                    reg [7:0] temp;
                    for (j = 0; j < 7; j = j + 1) begin
                        for (k = 0; k < 7 - j; k = k + 1) begin
                            if (temp_scores[k] < temp_scores[k + 1]) begin
                                temp = temp_scores[k];
                                temp_scores[k] = temp_scores[k + 1];
                                temp_scores[k + 1] = temp;
                            end
                        end
                    end
                    
                    // Sum top 4
                    other_aggregate = temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    
                    // Compare and update beat_count
                    if (other_aggregate > self_aggregate) begin
                        beat_count = beat_count + 1;
                    end
                    
                    // Move to next participant
                    participant_idx = participant_idx + 1;
                end
            end
            
            FINISH: begin
                worst_rank = beat_count + 1;
                done <= 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 3'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = IDLE;
            end
        end
    end

endmodule