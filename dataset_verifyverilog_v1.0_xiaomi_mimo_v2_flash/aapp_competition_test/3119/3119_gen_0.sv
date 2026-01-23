module guitar_hero_max_score (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] num_notes,
    input wire [3:0] note0,
    input wire [3:0] note1,
    input wire [3:0] note2,
    input wire [3:0] note3,
    input wire [1:0] num_phrases,
    input wire [3:0] phrase0_start,
    input wire [3:0] phrase0_end,
    input wire [3:0] phrase1_start,
    input wire [3:0] phrase1_end,
    output reg [3:0] max_score,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT_SUBSET = 3'd1;
    localparam [2:0] COMPUTE_C   = 3'd2;
    localparam [2:0] ITERATE_T   = 3'd3;
    localparam [2:0] CHECK       = 3'd4;
    localparam [2:0] UPDATE_MAX  = 3'd5;
    localparam [2:0] DONE        = 3'd6;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [1:0] subset_idx;        // 0 to 3
    reg [3:0] t_val;             // 0 to 15
    reg [4:0] C;                 // duration sum (max 30)
    reg [2:0] covered;           // count of covered notes (max 4)
    reg [3:0] max_extra;         // maximum extra points found
    reg [2:0] cycle_count;       // for IDLE timeout
    
    // Fixed note storage
    reg [3:0] notes [0:3];
    reg [3:0] p_start [0:1];
    reg [3:0] p_end [0:1];
    
    // Wires for computation
    wire [3:0] dur0 = (p_end[0] >= p_start[0]) ? (p_end[0] - p_start[0]) : 4'd0;
    wire [3:0] dur1 = (p_end[1] >= p_start[1]) ? (p_end[1] - p_start[1]) : 4'd0;
    wire [4:0] C_subset = (subset_idx == 2'd0) ? 5'd0 :
                          (subset_idx == 2'd1) ? {1'd0, dur0} :
                          (subset_idx == 2'd2) ? {1'd0, dur1} : (dur0 + dur1);
    
    // Check overlap for current subset (1 if overlaps)
    wire overlap0 = (num_phrases >= 2'd1) && 
                    (subset_idx == 2'd1 || subset_idx == 2'd3) &&
                    (t_val < p_end[0] + 4'd1) && (t_val + C > p_start[0]);
    wire overlap1 = (num_phrases >= 2'd2) && 
                    (subset_idx == 2'd2 || subset_idx == 2'd3) &&
                    (t_val < p_end[1] + 4'd1) && (t_val + C > p_start[1]);
    
    // Check if note is covered
    wire note0_covered = (num_notes > 2'd0) && (t_val <= notes[0]) && (notes[0] < t_val + C);
    wire note1_covered = (num_notes > 2'd1) && (t_val <= notes[1]) && (notes[1] < t_val + C);
    wire note2_covered = (num_notes > 2'd2) && (t_val <= notes[2]) && (notes[2] < t_val + C);
    wire note3_covered = (num_notes > 2'd3) && (t_val <= notes[3]) && (notes[3] < t_val + C);
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_score <= 4'd0;
            done <= 1'b0;
            subset_idx <= 2'd0;
            t_val <= 4'd0;
            C <= 5'd0;
            covered <= 3'd0;
            max_extra <= 4'd0;
            cycle_count <= 3'd0;
            notes[0] <= 4'd0;
            notes[1] <= 4'd0;
            notes[2] <= 4'd0;
            notes[3] <= 4'd0;
            p_start[0] <= 4'd0;
            p_end[0] <= 4'd0;
            p_start[1] <= 4'd0;
            p_end[1] <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        // Capture inputs
                        notes[0] <= note0;
                        notes[1] <= note1;
                        notes[2] <= note2;
                        notes[3] <= note3;
                        p_start[0] <= phrase0_start;
                        p_end[0] <= phrase0_end;
                        p_start[1] <= phrase1_start;
                        p_end[1] <= phrase1_end;
                        subset_idx <= 2'd0;
                        t_val <= 4'd0;
                        max_extra <= 4'd0;
                    end
                end
                INIT_SUBSET: begin
                    t_val <= 4'd0;
                    C <= C_subset;
                end
                ITERATE_T: begin
                    t_val <= t_val + 4'd1;
                    covered <= 3'd0;
                end
                CHECK: begin
                    covered <= covered + (note0_covered ? 3'd1 : 3'd0) +
                                      (note1_covered ? 3'd1 : 3'd0) +
                                      (note2_covered ? 3'd1 : 3'd0) +
                                      (note3_covered ? 3'd1 : 3'd0);
                end
                UPDATE_MAX: begin
                    if (!overlap0 && !overlap1 && covered > max_extra) begin
                        max_extra <= covered;
                    end
                end
                DONE: begin
                    max_score <= num_notes + max_extra;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_SUBSET;
                else next_state = IDLE;
            end
            INIT_SUBSET: next_state = ITERATE_T;
            ITERATE_T: next_state = CHECK;
            CHECK: next_state = UPDATE_MAX;
            UPDATE_MAX: begin
                if (t_val < 4'd15) next_state = ITERATE_T;
                else begin
                    if (subset_idx < 2'd3) next_state = INIT_SUBSET;
                    else next_state = DONE;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule