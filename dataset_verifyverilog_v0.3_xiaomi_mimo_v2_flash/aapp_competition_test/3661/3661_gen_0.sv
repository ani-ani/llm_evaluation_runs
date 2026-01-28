module lawsuit_assignment (
    input clk,
    input rst_n,
    input start,
    input [2:0] R, S, L,
    input [2:0] A_0, A_1, A_2, A_3, A_4, A_5, A_6, A_7,
    input [2:0] B_0, B_1, B_2, B_3, B_4, B_5, B_6, B_7,
    output reg [7:0] win,
    output reg done
);

    // State definitions
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_RESET = 3'd1;
    localparam [2:0] STATE_PROCESS = 3'd2;
    localparam [2:0] STATE_FIND_MAX = 3'd3;
    localparam [2:0] STATE_OUTPUT = 3'd4;
    localparam [2:0] STATE_DONE = 3'd5;
    
    // Registers for state machine
    reg [2:0] state;
    reg [7:0] mask;
    reg [2:0] lawsuit_idx;
    reg [2:0] current_min_max;
    reg [7:0] best_mask;
    reg [2:0] max_win;
    reg [3:0] max_idx;
    reg [7:0] total_masks;
    reg [7:0] counter_idx;
    
    // Counter arrays for individuals and corporations (indices 0-7)
    reg [2:0] indv_cnt [0:7];
    reg [2:0] corp_cnt [0:7];
    
    // Arrays to store A_i and B_i for easy access
    reg [2:0] A_arr [0:7];
    reg [2:0] B_arr [0:7];
    
    integer i;
    
    always @(*) begin
        // Initialize arrays from input ports
        A_arr[0] = A_0; A_arr[1] = A_1; A_arr[2] = A_2; A_arr[3] = A_3;
        A_arr[4] = A_4; A_arr[5] = A_5; A_arr[6] = A_6; A_arr[7] = A_7;
        B_arr[0] = B_0; B_arr[1] = B_1; B_arr[2] = B_2; B_arr[3] = B_3;
        B_arr[4] = B_4; B_arr[5] = B_5; B_arr[6] = B_6; B_arr[7] = B_7;
        total_masks = 8'd1 << L;  // 2^L masks
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            win <= 8'h00;
            mask <= 8'h00;
            lawsuit_idx <= 3'd0;
            current_min_max <= 3'd7;
            best_mask <= 8'h00;
            max_win <= 3'd0;
            max_idx <= 4'd0;
            counter_idx <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                indv_cnt[i] <= 3'd0;
                corp_cnt[i] <= 3'd0;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STATE_RESET;
                        mask <= 8'h00;
                        current_min_max <= 3'd7;
                        best_mask <= 8'h00;
                    end
                end
                
                STATE_RESET: begin
                    // Reset counters for current mask
                    for (i = 0; i < 8; i = i + 1) begin
                        indv_cnt[i] <= 3'd0;
                        corp_cnt[i] <= 3'd0;
                    end
                    lawsuit_idx <= 3'd0;
                    state <= STATE_PROCESS;
                end
                
                STATE_PROCESS: begin
                    if (lawsuit_idx < L) begin
                        // Process current lawsuit
                        if (mask[lawsuit_idx]) begin
                            // Corporation wins
                            corp_cnt[B_arr[lawsuit_idx] - 1] <= corp_cnt[B_arr[lawsuit_idx] - 1] + 1;
                        end else begin
                            // Individual wins
                            indv_cnt[A_arr[lawsuit_idx] - 1] <= indv_cnt[A_arr[lawsuit_idx] - 1] + 1;
                        end
                        lawsuit_idx <= lawsuit_idx + 1;
                    end else begin
                        // Done processing all lawsuits for this mask
                        state <= STATE_FIND_MAX;
                        max_win <= 3'd0;
                        max_idx <= 4'd0;
                    end
                end
                
                STATE_FIND_MAX: begin
                    if (max_idx < 16) begin
                        // Compare all 16 counters (8 individuals + 8 corporations)
                        if (max_idx < 8) begin
                            // Individual counter
                            if (indv_cnt[max_idx] > max_win)
                                max_win <= indv_cnt[max_idx];
                        end else begin
                            // Corporation counter
                            if (corp_cnt[max_idx - 8] > max_win)
                                max_win <= corp_cnt[max_idx - 8];
                        end
                        max_idx <= max_idx + 1;
                    end else begin
                        // Found maximum for this mask
                        if (max_win < current_min_max) begin
                            current_min_max <= max_win;
                            best_mask <= mask;
                        end
                        // Move to next mask
                        if (mask == (total_masks - 1)) begin
                            state <= STATE_OUTPUT;
                        end else begin
                            mask <= mask + 1;
                            state <= STATE_RESET;
                        end
                    end
                end
                
                STATE_OUTPUT: begin
                    win <= best_mask;
                    done <= 1'b1;
                    state <= STATE_DONE;
                end
                
                STATE_DONE: begin
                    done <= 1'b0;
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule