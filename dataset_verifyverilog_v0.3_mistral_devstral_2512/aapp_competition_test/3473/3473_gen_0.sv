module ContestScheduler(
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

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Function to compute Friday before Thanksgiving
    function [4:0] compute_tsg_friday;
        input [2:0] dow;
        integer offset, first_monday, second_monday;
        begin
            offset = (1 - dow + 7) % 7;
            first_monday = 1 + offset;
            second_monday = first_monday + 7;
            compute_tsg_friday = second_monday - 2;
        end
    endfunction

    // Internal signals for allowed days
    reg [4:0] allowed_days_0 [0:4];
    reg [2:0] allowed_count_0;
    reg [4:0] allowed_days_1 [0:4];
    reg [2:0] allowed_count_1;
    reg [4:0] tsg_friday_0, tsg_friday_1;

    // Combinational logic to compute allowed days for year 0
    integer d;
    reg is_friday, is_forbidden, is_tsg;
    always @(*) begin
        tsg_friday_0 = compute_tsg_friday(dow_oct1_0);
        allowed_count_0 = 0;
        for (d = 1; d <= 31; d = d + 1) begin
            is_friday = ((dow_oct1_0 + d - 1) % 7 == 5);
            is_forbidden = forbidden_mask_0[d-1];
            is_tsg = (d == tsg_friday_0);
            if (is_friday && !is_forbidden && !is_tsg) begin
                if (allowed_count_0 < 5) begin
                    allowed_days_0[allowed_count_0] = d;
                    allowed_count_0 = allowed_count_0 + 1;
                end
            end
        end
    end

    // Combinational logic to compute allowed days for year 1
    always @(*) begin
        tsg_friday_1 = compute_tsg_friday(dow_oct1_1);
        allowed_count_1 = 0;
        for (d = 1; d <= 31; d = d + 1) begin
            is_friday = ((dow_oct1_1 + d - 1) % 7 == 5);
            is_forbidden = forbidden_mask_1[d-1];
            is_tsg = (d == tsg_friday_1);
            if (is_friday && !is_forbidden && !is_tsg) begin
                if (allowed_count_1 < 5) begin
                    allowed_days_1[allowed_count_1] = d;
                    allowed_count_1 = allowed_count_1 + 1;
                end
            end
        end
    end

    // DP combinational logic
    integer i0, i1;
    reg [16:0] best_penalty;
    reg [4:0] best_day0, best_day1;
    reg [16:0] penalty, penalty0, penalty1, total_pen;
    reg [4:0] day0_val, day1_val;

    always @(*) begin
        best_penalty = 17'h1FFFF;
        best_day0 = 0;
        best_day1 = 0;
        if (Z >= 1) begin
            if (Z == 1) begin
                for (i0 = 0; i0 < allowed_count_0; i0 = i0 + 1) begin
                    day0_val = allowed_days_0[i0];
                    penalty = (day0_val - 12) * (day0_val - 12);
                    if (penalty < best_penalty) begin
                        best_penalty = penalty;
                        best_day0 = day0_val;
                        best_day1 = 0;
                    end
                end
            end else begin
                for (i0 = 0; i0 < allowed_count_0; i0 = i0 + 1) begin
                    day0_val = allowed_days_0[i0];
                    penalty0 = (day0_val - 12) * (day0_val - 12);
                    for (i1 = 0; i1 < allowed_count_1; i1 = i1 + 1) begin
                        day1_val = allowed_days_1[i1];
                        penalty1 = (day1_val - day0_val) * (day1_val - day0_val);
                        total_pen = penalty0 + penalty1;
                        if (total_pen < best_penalty) begin
                            best_penalty = total_pen;
                            best_day0 = day0_val;
                            best_day1 = day1_val;
                        end
                    end
                end
            end
        end
    end

    // Sequential output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            day0 <= 5'd0;
            day1 <= 5'd0;
            total_penalty <= 17'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    day0 <= best_day0;
                    day1 <= best_day1;
                    total_penalty <= best_penalty;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule