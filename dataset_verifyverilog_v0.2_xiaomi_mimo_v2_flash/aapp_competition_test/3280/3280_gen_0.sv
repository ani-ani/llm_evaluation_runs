module tv_recorder (
    input clk,
    input rst_n,
    input start,
    input [5:0] show_index,
    input [31:0] start_time,
    input [31:0] end_time,
    output reg [3:0] result,
    output reg done
);

    // Memory for 8 shows (start and end times)
    reg [31:0] mem_start [0:7];
    reg [31:0] mem_end [0:7];

    // State definitions
    localparam IDLE         = 5'd0;
    localparam LOAD_0       = 5'd1;
    localparam LOAD_1       = 5'd2;
    localparam LOAD_2       = 5'd3;
    localparam LOAD_3       = 5'd4;
    localparam LOAD_4       = 5'd5;
    localparam LOAD_5       = 5'd6;
    localparam LOAD_6       = 5'd7;
    localparam LOAD_7       = 5'd8;
    localparam SORT_PASS_1  = 5'd9;
    localparam SORT_PASS_2  = 5'd10;
    localparam SORT_PASS_3  = 5'd11;
    localparam SORT_PASS_4  = 5'd12;
    localparam SORT_PASS_5  = 5'd13;
    localparam SORT_PASS_6  = 5'd14;
    localparam SORT_PASS_7  = 5'd15;
    localparam SCHEDULE_0   = 5'd16;
    localparam SCHEDULE_1   = 5'd17;
    localparam SCHEDULE_2   = 5'd18;
    localparam SCHEDULE_3   = 5'd19;
    localparam SCHEDULE_4   = 5'd20;
    localparam SCHEDULE_5   = 5'd21;
    localparam SCHEDULE_6   = 5'd22;
    localparam SCHEDULE_7   = 5'd23;
    localparam DONE         = 5'd24;

    reg [4:0] state;
    reg [2:0] sort_j;
    reg [31:0] slot0_end;
    reg [31:0] slot1_end;
    reg [3:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            slot0_end <= 32'd0;
            slot1_end <= 32'd0;
            count <= 4'd0;
            sort_j <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Start loading shows. Assume data is valid on consecutive cycles.
                        state <= LOAD_0;
                    end
                end

                // --- Loading Phase (8 cycles) ---
                LOAD_0: begin
                    mem_start[0] <= start_time;
                    mem_end[0] <= end_time;
                    state <= LOAD_1;
                end
                LOAD_1: begin
                    mem_start[1] <= start_time;
                    mem_end[1] <= end_time;
                    state <= LOAD_2;
                end
                LOAD_2: begin
                    mem_start[2] <= start_time;
                    mem_end[2] <= end_time;
                    state <= LOAD_3;
                end
                LOAD_3: begin
                    mem_start[3] <= start_time;
                    mem_end[3] <= end_time;
                    state <= LOAD_4;
                end
                LOAD_4: begin
                    mem_start[4] <= start_time;
                    mem_end[4] <= end_time;
                    state <= LOAD_5;
                end
                LOAD_5: begin
                    mem_start[5] <= start_time;
                    mem_end[5] <= end_time;
                    state <= LOAD_6;
                end
                LOAD_6: begin
                    mem_start[6] <= start_time;
                    mem_end[6] <= end_time;
                    state <= LOAD_7;
                end
                LOAD_7: begin
                    mem_start[7] <= start_time;
                    mem_end[7] <= end_time;
                    // Initialize Bubble Sort
                    sort_j <= 3'd0;
                    state <= SORT_PASS_1;
                end

                // --- Sorting Phase (Bubble Sort) ---
                // Total comparisons: 28 (7 passes * 4 comparisons on average? No, 7 passes with decreasing comparisons)
                // Pass 1: 7 comps, Pass 2: 6 comps, ..., Pass 7: 1 comp. Total 28 cycles.
                // Since we have 7 states, we iterate `sort_j` inside each state.
                
                SORT_PASS_1, SORT_PASS_2, SORT_PASS_3, SORT_PASS_4, SORT_PASS_5, SORT_PASS_6, SORT_PASS_7: begin
                    // Calculate limit for inner loop based on state
                    // Pass 1 (state 9): need j=0..6 (7 comparisons). Limit index 6.
                    // Pass 7 (state 15): need j=0..0 (1 comparison). Limit index 0.
                    // Formula: Limit = 15 - state. 
                    // Pass 1 (9): 15-9=6. Pass 7 (15): 15-15=0. Correct.
                    
                    if (sort_j < (15 - state)) begin
                        if (mem_end[sort_j] > mem_end[sort_j + 1]) begin
                            // Swap elements j and j+1
                            mem_start[sort_j] <= mem_start[sort_j + 1];
                            mem_end[sort_j] <= mem_end[sort_j + 1];
                            mem_start[sort_j + 1] <= mem_start[sort_j];
                            mem_end[sort_j + 1] <= mem_end[sort_j];
                        end
                        sort_j <= sort_j + 1;
                        // Stay in current state
                    end else begin
                        // This pass is done. Move to next pass.
                        sort_j <= 3'd0;
                        if (state == SORT_PASS_7) begin
                            // Initialize Scheduling
                            slot0_end <= 32'd0;
                            slot1_end <= 32'd0;
                            count <= 4'd0;
                            state <= SCHEDULE_0;
                        end else begin
                            state <= state + 1;
                        end
                    end
                end

                // --- Scheduling Phase ---
                // 8 cycles (1 per show)
                SCHEDULE_0: begin
                    if (mem_end[0] >= slot0_end && mem_start[0] >= slot0_end) begin
                        slot0_end <= mem_end[0]; count <= count + 1;
                    end else if (mem_end[0] >= slot1_end && mem_start[0] >= slot1_end) begin
                        slot1_end <= mem_end[0]; count <= count + 1;
                    end
                    state <= SCHEDULE_1;
                end
                SCHEDULE_1: begin
                    if (mem_end[1] >= slot0_end && mem_start[1] >= slot0_end) begin
                        slot0_end <= mem_end[1]; count <= count + 1;
                    end else if (mem_end[1] >= slot1_end && mem_start[1] >= slot1_end) begin
                        slot1_end <= mem_end[1]; count <= count + 1;
                    end
                    state <= SCHEDULE_2;
                end
                SCHEDULE_2: begin
                    if (mem_end[2] >= slot0_end && mem_start[2] >= slot0_end) begin
                        slot0_end <= mem_end[2]; count <= count + 1;
                    end else if (mem_end[2] >= slot1_end && mem_start[2] >= slot1_end) begin
                        slot1_end <= mem_end[2]; count <= count + 1;
                    end
                    state <= SCHEDULE_3;
                end
                SCHEDULE_3: begin
                    if (mem_end[3] >= slot0_end && mem_start[3] >= slot0_end) begin
                        slot0_end <= mem_end[3]; count <= count + 1;
                    end else if (mem_end[3] >= slot1_end && mem_start[3] >= slot1_end) begin
                        slot1_end <= mem_end[3]; count <= count + 1;
                    end
                    state <= SCHEDULE_4;
                end
                SCHEDULE_4: begin
                    if (mem_end[4] >= slot0_end && mem_start[4] >= slot0_end) begin
                        slot0_end <= mem_end[4]; count <= count + 1;
                    end else if (mem_end[4] >= slot1_end && mem_start[4] >= slot1_end) begin
                        slot1_end <= mem_end[4]; count <= count + 1;
                    end
                    state <= SCHEDULE_5;
                end
                SCHEDULE_5: begin
                    if (mem_end[5] >= slot0_end && mem_start[5] >= slot0_end) begin
                        slot0_end <= mem_end[5]; count <= count + 1;
                    end else if (mem_end[5] >= slot1_end && mem_start[5] >= slot1_end) begin
                        slot1_end <= mem_end[5]; count <= count + 1;
                    end
                    state <= SCHEDULE_6;
                end
                SCHEDULE_6: begin
                    if (mem_end[6] >= slot0_end && mem_start[6] >= slot0_end) begin
                        slot0_end <= mem_end[6]; count <= count + 1;
                    end else if (mem_end[6] >= slot1_end && mem_start[6] >= slot1_end) begin
                        slot1_end <= mem_end[6]; count <= count + 1;
                    end
                    state <= SCHEDULE_7;
                end
                SCHEDULE_7: begin
                    if (mem_end[7] >= slot0_end && mem_start[7] >= slot0_end) begin
                        slot0_end <= mem_end[7]; count <= count + 1;
                    end else if (mem_end[7] >= slot1_end && mem_start[7] >= slot1_end) begin
                        slot1_end <= mem_end[7]; count <= count + 1;
                    end
                    state <= DONE;
                end

                DONE: begin
                    result <= count;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule