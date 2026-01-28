module TopModule (
    input clk,
    input rst_n,
    input start,
    input [7:0] L_new,
    input [7:0] R_new,
    input [3:0] len,
    input [7:0] L_arr_0, L_arr_1, L_arr_2, L_arr_3, L_arr_4, L_arr_5, L_arr_6, L_arr_7,
    input [7:0] L_arr_8, L_arr_9, L_arr_10, L_arr_11, L_arr_12, L_arr_13, L_arr_14, L_arr_15,
    input [7:0] R_arr_0, R_arr_1, R_arr_2, R_arr_3, R_arr_4, R_arr_5, R_arr_6, R_arr_7,
    input [7:0] R_arr_8, R_arr_9, R_arr_10, R_arr_11, R_arr_12, R_arr_13, R_arr_14, R_arr_15,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE = 3'd1;
    localparam [2:0] CHECK_STEM_L = 3'd2;
    localparam [2:0] CHECK_STEM_R = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] plant_idx;
    reg [7:0] stored_L_new, stored_R_new;
    reg [7:0] current_L_old, current_R_old;
    reg stem_sel; // 0 for L stem, 1 for R stem
    reg check_result;
    
    // Mux to select current plant data
    always @(*) begin
        case (plant_idx)
            4'd0:  begin current_L_old = L_arr_0;  current_R_old = R_arr_0;  end
            4'd1:  begin current_L_old = L_arr_1;  current_R_old = R_arr_1;  end
            4'd2:  begin current_L_old = L_arr_2;  current_R_old = R_arr_2;  end
            4'd3:  begin current_L_old = L_arr_3;  current_R_old = R_arr_3;  end
            4'd4:  begin current_L_old = L_arr_4;  current_R_old = R_arr_4;  end
            4'd5:  begin current_L_old = L_arr_5;  current_R_old = R_arr_5;  end
            4'd6:  begin current_L_old = L_arr_6;  current_R_old = R_arr_6;  end
            4'd7:  begin current_L_old = L_arr_7;  current_R_old = R_arr_7;  end
            4'd8:  begin current_L_old = L_arr_8;  current_R_old = R_arr_8;  end
            4'd9:  begin current_L_old = L_arr_9;  current_R_old = R_arr_9;  end
            4'd10: begin current_L_old = L_arr_10; current_R_old = R_arr_10; end
            4'd11: begin current_L_old = L_arr_11; current_R_old = R_arr_11; end
            4'd12: begin current_L_old = L_arr_12; current_R_old = R_arr_12; end
            4'd13: begin current_L_old = L_arr_13; current_R_old = R_arr_13; end
            4'd14: begin current_L_old = L_arr_14; current_R_old = R_arr_14; end
            4'd15: begin current_L_old = L_arr_15; current_R_old = R_arr_15; end
            default: begin current_L_old = 8'd0; current_R_old = 8'd0; end
        endcase
    end

    // Check logic for strict interior intersection
    always @(*) begin
        if (stem_sel == 1'b0) begin
            // Checking L_new stem
            // Condition: L_old < L_new < R_old
            if ((current_L_old < stored_L_new) && (stored_L_new < current_R_old))
                check_result = 1'b1;
            else
                check_result = 1'b0;
        end else begin
            // Checking R_new stem
            // Condition: L_old < R_new < R_old
            if ((current_L_old < stored_R_new) && (stored_R_new < current_R_old))
                check_result = 1'b1;
            else
                check_result = 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = STORE;
                else
                    next_state = IDLE;
            end
            STORE: begin
                next_state = CHECK_STEM_L;
            end
            CHECK_STEM_L: begin
                if (check_result)
                    next_state = INCREMENT;
                else if (plant_idx >= len)
                    next_state = CHECK_STEM_R; // Finished L stem loop
                else
                    next_state = CHECK_STEM_L;
            end
            INCREMENT: begin
                if (stem_sel == 1'b0) begin
                    if (plant_idx >= len)
                        next_state = CHECK_STEM_R;
                    else
                        next_state = CHECK_STEM_L;
                end else begin
                    if (plant_idx >= len)
                        next_state = FINISH;
                    else
                        next_state = CHECK_STEM_R;
                end
            end
            CHECK_STEM_R: begin
                if (check_result)
                    next_state = INCREMENT;
                else if (plant_idx >= len)
                    next_state = FINISH;
                else
                    next_state = CHECK_STEM_R;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            plant_idx <= 4'd0;
            stem_sel <= 1'b0;
            stored_L_new <= 8'd0;
            stored_R_new <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0; // Default done low
            
            case (next_state)
                IDLE: begin
                    plant_idx <= 4'd0;
                    stem_sel <= 1'b0;
                    result <= 8'd0;
                end
                STORE: begin
                    stored_L_new <= L_new;
                    stored_R_new <= R_new;
                    plant_idx <= 4'd0;
                    result <= 8'd0;
                end
                CHECK_STEM_L: begin
                    if (state == CHECK_STEM_L)
                        plant_idx <= plant_idx + 4'd1;
                end
                CHECK_STEM_R: begin
                    if (state == CHECK_STEM_R)
                        plant_idx <= plant_idx + 4'd1;
                end
                INCREMENT: begin
                    if (result < 8'd32)
                        result <= result + 8'd1;
                    if (state != INCREMENT) begin
                        // First time entering increment path from check
                        plant_idx <= plant_idx + 4'd1;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    stem_sel <= 1'b0;
                end
            endcase
            
            // Special handling for state transitions
            if (state == STORE) begin
                plant_idx <= 4'd0;
                stem_sel <= 1'b0;
            end
            if (state == CHECK_STEM_L && next_state == CHECK_STEM_R) begin
                // Finished L stem loop, switch to R stem
                plant_idx <= 4'd0;
                stem_sel <= 1'b1;
            end
            if (state == INCREMENT && stem_sel == 1'b0 && next_state == CHECK_STEM_R) begin
                // Incremented on last L check, switch to R stem
                plant_idx <= 4'd0;
                stem_sel <= 1'b1;
            end
            if (state == INCREMENT && stem_sel == 1'b1 && next_state == FINISH) begin
                // Incremented on last R check, finish
                plant_idx <= 4'd0;
                stem_sel <= 1'b0;
            end
        end
    end
endmodule