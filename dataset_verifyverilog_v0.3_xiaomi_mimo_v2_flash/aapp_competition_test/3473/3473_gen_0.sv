module ContestScheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] Z,
    input wire [2:0] dow_oct1_0,
    input wire [2:0] dow_oct1_1,
    input wire [30:0] forbidden_mask_0,
    input wire [30:0] forbidden_mask_1,
    output reg [4:0] day0,
    output reg [4:0] day1,
    output reg [16:0] total_penalty,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_Z = 3'd1;
    localparam [2:0] PREPARE_Y0 = 3'd2;
    localparam [2:0] PREPARE_Y1 = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [5:0] day_counter;
    reg [2:0] tsg_friday_0, tsg_friday_1;
    reg [4:0] best_day0, best_day1;
    reg [16:0] best_penalty;

    // Allowed days storage (max 5 per year)
    reg [4:0] allowed_days_0 [0:4];
    reg [4:0] allowed_days_1 [0:4];
    reg [2:0] allowed_count_0;
    reg [2:0] allowed_count_1;

    // Computation indices
    reg [2:0] idx0, idx1;
    reg [4:0] day0_val, day1_val;
    reg [16:0] penalty0, penalty1, total_pen;

    // Combinational helpers for Friday calculation
    reg [2:0] first_monday_0, first_monday_1;
    reg [2:0] second_monday_0, second_monday_1;
    always @(*) begin
        // Year 0
        if (dow_oct1_0 <= 1) begin
            first_monday_0 = 1 + (1 - dow_oct1_0);
        end else begin
            first_monday_0 = 1 + (8 - dow_oct1_0);
        end
        second_monday_0 = first_monday_0 + 7;
        tsg_friday_0 = second_monday_0 - 2;

        // Year 1
        if (dow_oct1_1 <= 1) begin
            first_monday_1 = 1 + (1 - dow_oct1_1);
        end else begin
            first_monday_1 = 1 + (8 - dow_oct1_1);
        end
        second_monday_1 = first_monday_1 + 7;
        tsg_friday_1 = second_monday_1 - 2;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            day0 <= 5'd0;
            day1 <= 5'd0;
            total_penalty <= 17'd0;
            day_counter <= 6'd0;
            allowed_count_0 <= 3'd0;
            allowed_count_1 <= 3'd0;
            idx0 <= 3'd0;
            idx1 <= 3'd0;
            best_day0 <= 5'd0;
            best_day1 <= 5'd0;
            best_penalty <= 17'h1FFFF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    day_counter <= 6'd0;
                    allowed_count_0 <= 3'd0;
                    allowed_count_1 <= 3'd0;
                    idx0 <= 3'd0;
                    idx1 <= 3'd0;
                    best_day0 <= 5'd0;
                    best_day1 <= 5'd0;
                    best_penalty <= 17'h1FFFF;
                    if (start) begin
                        state <= CHECK_Z;
                    end
                end

                CHECK_Z: begin
                    if (Z == 2'd0) begin
                        // Z=0 means invalid, go to finish immediately
                        state <= FINISH;
                    end else begin
                        state <= PREPARE_Y0;
                        day_counter <= 6'd1;
                        allowed_count_0 <= 3'd0;
                    end
                end

                PREPARE_Y0: begin
                    // Check if day is Friday and not forbidden and not TSG
                    // (dow_oct1_0 + day_counter - 1) % 7 == 5 means Friday
                    if (day_counter <= 6'd31) begin
                        if (((dow_oct1_0 + day_counter[2:0] - 3'd1) % 3'd7 == 3'd5) && 
                            !forbidden_mask_0[day_counter[4:0]-5'd1] && 
                            (day_counter[4:0] != tsg_friday_0)) begin
                            if (allowed_count_0 < 3'd5) begin
                                allowed_days_0[allowed_count_0] <= day_counter[4:0];
                                allowed_count_0 <= allowed_count_0 + 3'd1;
                            end
                        end
                        day_counter <= day_counter + 6'd1;
                    end else if (Z == 2'd2) begin
                        state <= PREPARE_Y1;
                        day_counter <= 6'd1;
                        allowed_count_1 <= 3'd0;
                    end else begin // Z == 1
                        state <= COMPUTE;
                        idx0 <= 3'd0;
                    end
                end

                PREPARE_Y1: begin
                    if (day_counter <= 6'd31) begin
                        if (((dow_oct1_1 + day_counter[2:0] - 3'd1) % 3'd7 == 3'd5) && 
                            !forbidden_mask_1[day_counter[4:0]-5'd1] && 
                            (day_counter[4:0] != tsg_friday_1)) begin
                            if (allowed_count_1 < 3'd5) begin
                                allowed_days_1[allowed_count_1] <= day_counter[4:0];
                                allowed_count_1 <= allowed_count_1 + 3'd1;
                            end
                        end
                        day_counter <= day_counter + 6'd1;
                    end else begin
                        state <= COMPUTE;
                        idx0 <= 3'd0;
                        idx1 <= 3'd0;
                    end
                end

                COMPUTE: begin
                    if (Z == 2'd1) begin
                        // Single year optimization
                        if (idx0 < allowed_count_0) begin
                            day0_val <= allowed_days_0[idx0];
                            penalty0 <= (day0_val - 5'd12) * (day0_val - 5'd12);
                            if (penalty0 < best_penalty) begin
                                best_penalty <= penalty0;
                                best_day0 <= day0_val;
                            end
                            idx0 <= idx0 + 3'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin // Z == 2
                        // Two year optimization
                        if (idx0 < allowed_count_0) begin
                            day0_val <= allowed_days_0[idx0];
                            penalty0 <= (day0_val - 5'd12) * (day0_val - 5'd12);
                            idx1 <= 3'd0;
                        end else begin
                            state <= FINISH;
                        end
                        if (idx0 < allowed_count_0 && idx1 < allowed_count_1) begin
                            day1_val <= allowed_days_1[idx1];
                            penalty1 <= (day1_val - day0_val) * (day1_val - day0_val);
                            total_pen <= penalty0 + penalty1;
                            if (total_pen < best_penalty) begin
                                best_penalty <= total_pen;
                                best_day0 <= day0_val;
                                best_day1 <= day1_val;
                            end
                            if (idx1 < allowed_count_1 - 3'd1) begin
                                idx1 <= idx1 + 3'd1;
                            end else begin
                                idx0 <= idx0 + 3'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    day0 <= best_day0;
                    day1 <= (Z == 2'd2) ? best_day1 : 5'd0;
                    total_penalty <= best_penalty;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule