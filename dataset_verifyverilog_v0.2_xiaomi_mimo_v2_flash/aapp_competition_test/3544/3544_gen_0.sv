module cinema_seating (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] num_groups_1,
    input [7:0] num_groups_2,
    input [7:0] num_groups_3,
    input [7:0] num_groups_4,
    input [7:0] num_groups_5,
    input [7:0] num_groups_6,
    input [7:0] num_groups_7,
    input [7:0] num_groups_8,
    output reg [4:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CALCULATE_X = 3'b001;
    localparam CHECK_SEATING = 3'b010;
    localparam DONE_STATE = 3'b011;
    localparam UPDATE_BEST = 3'b100;

    // Registers
    reg [2:0] state;
    reg [3:0] x; // Current row width being checked (1-12, plus bounds)
    reg [3:0] best_x;
    reg [3:0] best_rows;
    reg [3:0] current_rows;
    
    // Group counters (remaining in current simulation)
    reg [7:0] rem_g1, rem_g2, rem_g3, rem_g4, rem_g5, rem_g6, rem_g7, rem_g8;
    reg [7:0] temp_g1, temp_g2, temp_g3, temp_g4, temp_g5, temp_g6, temp_g7, temp_g8;
    
    // Row simulation state
    reg [3:0] row_size;
    reg [3:0] row_used;
    reg [3:0] g_idx; // Group size index (1-8)
    reg [2:0] place_cnt; // How many of current group placed in this row
    reg [7:0] count_to_place; // How many of this group we want to place
    reg [3:0] space_needed;
    reg cannot_fit_any;
    reg all_groups_done;
    reg sim_fail;
    reg sim_success;
    
    // Helper signals
    reg [7:0] grp_cnt;
    reg [3:0] grp_size;
    reg [3:0] space_req;
    reg [3:0] seats_avail;
    
    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            x <= 4'd1;
            best_x <= 4'd13;
            best_rows <= 4'd15; // Max possible rows is 12, init to high
            current_rows <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATE_X;
                        x <= 4'd1;
                        best_x <= 4'd13;
                        best_rows <= 4'd15;
                    end
                end

                CALCULATE_X: begin
                    if (x <= 4'd12) begin
                        // Initialize simulation for this X
                        rem_g1 <= num_groups_1;
                        rem_g2 <= num_groups_2;
                        rem_g3 <= num_groups_3;
                        rem_g4 <= num_groups_4;
                        rem_g5 <= num_groups_5;
                        rem_g6 <= num_groups_6;
                        rem_g7 <= num_groups_7;
                        rem_g8 <= num_groups_8;
                        current_rows <= 4'd0;
                        sim_fail <= 1'b0;
                        sim_success <= 1'b0;
                        state <= CHECK_SEATING;
                    end else begin
                        // Done checking all X
                        state <= DONE_STATE;
                    end
                end

                CHECK_SEATING: begin
                    // Check if all groups seated
                    if (rem_g1 == 0 && rem_g2 == 0 && rem_g3 == 0 && rem_g4 == 0 && 
                        rem_g5 == 0 && rem_g6 == 0 && rem_g7 == 0 && rem_g8 == 0) begin
                        sim_success <= 1'b1;
                        state <= UPDATE_BEST;
                    end else begin
                        // Check if row size is valid
                        if (x > current_rows) begin
                            row_size <= x - current_rows;
                            row_used <= 4'd0;
                            cannot_fit_any <= 1'b1;
                            temp_g1 <= rem_g1;
                            temp_g2 <= rem_g2;
                            temp_g3 <= rem_g3;
                            temp_g4 <= rem_g4;
                            temp_g5 <= rem_g5;
                            temp_g6 <= rem_g6;
                            temp_g7 <= rem_g7;
                            temp_g8 <= rem_g8;
                            g_idx <= 4'd8;
                            state <= 3'b101; // SUB_STATE_START_PLACING
                        end else begin
                            sim_fail <= 1'b1;
                            state <= UPDATE_BEST;
                        end
                    end
                end

                3'b101: begin // SUB_STATE_START_PLACING (outer loop: try groups 8 to 1)
                    if (g_idx >= 4'd1) begin
                        // Determine group count and size
                        case (g_idx)
                            4'd1: begin grp_cnt <= temp_g1; grp_size <= 4'd1; end
                            4'd2: begin grp_cnt <= temp_g2; grp_size <= 4'd2; end
                            4'd3: begin grp_cnt <= temp_g3; grp_size <= 4'd3; end
                            4'd4: begin grp_cnt <= temp_g4; grp_size <= 4'd4; end
                            4'd5: begin grp_cnt <= temp_g5; grp_size <= 4'd5; end
                            4'd6: begin grp_cnt <= temp_g6; grp_size <= 4'd6; end
                            4'd7: begin grp_cnt <= temp_g7; grp_size <= 4'd7; end
                            4'd8: begin grp_cnt <= temp_g8; grp_size <= 4'd8; end
                        endcase
                        place_cnt <= 3'd0;
                        state <= 3'b110; // SUB_STATE_INNER_PLACE
                    end else begin
                        // Inner loop done, update remaining for next row
                        if (cannot_fit_any) begin
                            // Could not fit any group, try next row if possible
                            current_rows <= current_rows + 1;
                            state <= CHECK_SEATING;
                        end else begin
                            // Successfully filled row, update rem and next row
                            rem_g1 <= temp_g1;
                            rem_g2 <= temp_g2;
                            rem_g3 <= temp_g3;
                            rem_g4 <= temp_g4;
                            rem_g5 <= temp_g5;
                            rem_g6 <= temp_g6;
                            rem_g7 <= temp_g7;
                            rem_g8 <= temp_g8;
                            current_rows <= current_rows + 1;
                            state <= CHECK_SEATING;
                        end
                    end
                end

                3'b110: begin // SUB_STATE_INNER_PLACE
                    // Check if we can place this group in current row
                    // First calculate space required
                    if (place_cnt == 0) space_req <= grp_size;
                    else space_req <= 1 + grp_size; // gap + group
                    
                    seats_avail <= row_size - row_used;
                    
                    if (grp_cnt > 0) begin
                        state <= 3'b111; // SUB_STATE_CHECK_PLACEMENT
                    end else begin
                        // Move to next smaller group
                        g_idx <= g_idx - 1;
                        state <= 3'b101; // SUB_STATE_START_PLACING
                    end
                end

                3'b111: begin // SUB_STATE_CHECK_PLACEMENT
                    if (seats_avail >= space_req) begin
                        // Can place at least one
                        cannot_fit_any <= 1'b0;
                        // Calculate max count we can place
                        // We need: (size + 1) * count - 1 <= seats_avail (if first)
                        // If first: size + 1*count - 1 <= rem ?
                        // Formula for count C given Used U:
                        // If U==0: Size + (C-1)*(Size+1) <= RowSize
                        // If U>0: U + 1 + Size + (C-1)*(Size+1) <= RowSize
                        // Let's compute remaining capacity R = RowSize - U
                        // If U==0: Space(C) = Size + (C-1)*(Size+1)
                        // We want Space(C) <= R
                        // Let's just step it. 
                        // Optimization: If we can fit one, we might fit more.
                        // Let's place 1 immediately and loop back or calculate all.
                        // To keep state count low, let's try to place all that fit.
                        // But we need to update temp registers.
                        // Let's just place 1 at a time in a loop.
                        
                        // Place 1
                        if (place_cnt == 0) row_used <= row_used + grp_size;
                        else row_used <= row_used + 1 + grp_size;
                        
                        place_cnt <= place_cnt + 1;
                        
                        // Update temp count
                        case (g_idx)
                            4'd1: temp_g1 <= temp_g1 - 1;
                            4'd2: temp_g2 <= temp_g2 - 1;
                            4'd3: temp_g3 <= temp_g3 - 1;
                            4'd4: temp_g4 <= temp_g4 - 1;
                            4'd5: temp_g5 <= temp_g5 - 1;
                            4'd6: temp_g6 <= temp_g6 - 1;
                            4'd7: temp_g7 <= temp_g7 - 1;
                            4'd8: temp_g8 <= temp_g8 - 1;
                        endcase
                        
                        // Check if we should try to place another of this group
                        // Calculate next space needed
                        // Next space is always 1 + grp_size
                        // Update seats_avail logic
                        // If row_used + 1 + grp_size <= row_size, loop back to 3'b111
                        // But we need to re-evaluate space_req
                        // Let's jump to 3'b110 to re-evaluate space_req calculation
                        // But we need to ensure we don't go back to 3'b101 (change group)
                        // We can use a separate flag or modify 3'b110 logic.
                        // Let's stick to: 3'b110 sets space_req based on place_cnt.
                        // In 3'b110, if place_cnt > 0 we know we are continuing.
                        // But we just incremented place_cnt. 
                        
                        state <= 3'b110; // Loop back to check if we can place more
                    end else begin
                        // Cannot place this group (or more of it)
                        // Move to next group
                        g_idx <= g_idx - 1;
                        state <= 3'b101;
                    end
                end

                UPDATE_BEST: begin
                    if (sim_success) begin
                        if (current_rows < best_rows) begin
                            best_rows <= current_rows;
                            best_x <= x;
                        end else if (current_rows == best_rows) begin
                            if (x < best_x) begin
                                best_x <= x;
                            end
                        end
                    end
                    x <= x + 1;
                    state <= CALCULATE_X;
                end

                DONE_STATE: begin
                    result <= (best_x == 4'd13) ? 5'd13 : {1'b0, best_x};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
