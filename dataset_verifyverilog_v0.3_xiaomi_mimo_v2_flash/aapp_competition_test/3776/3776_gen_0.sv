module BrokenClockFix(
    input clk,
    input rst_n,
    input start,
    input format,
    input [15:0] time_in,
    output reg [15:0] time_out,
    output reg done
);

// State declarations
localparam [3:0] IDLE      = 4'd0;
localparam [3:0] CHECK_H1  = 4'd1;
localparam [3:0] CHECK_H2  = 4'd2;
localparam [3:0] CHECK_M1  = 4'd3;
localparam [3:0] CHECK_M2  = 4'd4;
localparam [3:0] COMPUTE   = 4'd5;
localparam [3:0] FIND_BEST = 4'd6;
localparam [3:0] DONE      = 4'd7;

// Internal registers
reg [3:0] state;
reg [3:0] next_state;
reg [3:0] h1, h2, m1, m2;           // Input digits
reg [3:0] best_h1, best_h2, best_m1, best_m2;  // Best candidate
reg [7:0] best_score;               // Minimum changes found
reg [7:0] candidate_score;          // Score for current candidate
reg [7:0] cycles;                   // Cycle counter
reg [7:0] h1_count, h2_count, m1_count, m2_count;  // Loop counters
reg [1:0] valid_range;              // 0: invalid, 1: valid, 2: valid and checked
reg [15:0] candidate_time;          // Current candidate time
reg [15:0] candidate_out;           // Candidate in packed format
reg [7:0] h1_start, h1_end;         // Range for H1
reg [7:0] h2_start, h2_end;         // Range for H2
reg [7:0] m1_start, m1_end;         // Range for M1
reg [7:0] m2_start, m2_end;         // Range for M2

// Constants
localparam [7:0] MAX_HOURS_24 = 8'd23;
localparam [7:0] MAX_HOURS_12 = 8'd12;
localparam [7:0] MAX_MINUTES  = 8'd59;
localparam [7:0] MAX_CYCLES   = 8'd100;

// Helper: count digit changes between candidate and input
function [7:0] count_changes(
    input [3:0] h1_cand, h2_cand, m1_cand, m2_cand,
    input [3:0] h1_in, h2_in, m1_in, m2_in
);
    reg [7:0] score;
    begin
        score = 8'd0;
        if (h1_cand != h1_in) score = score + 8'd1;
        if (h2_cand != h2_in) score = score + 8'd1;
        if (m1_cand != m1_in) score = score + 8'd1;
        if (m2_cand != m2_in) score = score + 8'd1;
        count_changes = score;
    end
endfunction

// Helper: pack digits to 16-bit
function [15:0] pack_time(
    input [3:0] h1, h2, m1, m2
);
    begin
        pack_time = {h1, h2, m1, m2};
    end
endfunction

// Helper: check if time is valid
function valid_time(
    input [3:0] h1, h2, m1, m2,
    input fmt
);
    reg [7:0] hours, minutes;
    reg valid_hours, valid_minutes;
    begin
        hours = {4'd0, h1} * 8'd10 + {4'd0, h2};
        minutes = {4'd0, m1} * 8'd10 + {4'd0, m2};
        
        valid_minutes = (minutes <= MAX_MINUTES);
        
        if (fmt == 1'b0) begin  // 24-hour format
            valid_hours = (hours <= MAX_HOURS_24);
        end else begin  // 12-hour format
            valid_hours = (hours >= 8'd1) && (hours <= MAX_HOURS_12);
        end
        
        valid_time = valid_hours && valid_minutes;
    end
endfunction

// Helper: compute digit ranges for optimization
function [15:0] get_ranges(
    input [3:0] h1, h2, m1, m2,
    input fmt
);
    reg [7:0] hours, minutes;
    reg [7:0] h1_max, h2_max, m1_max, m2_max;
    begin
        hours = {4'd0, h1} * 8'd10 + {4'd0, h2};
        minutes = {4'd0, m1} * 8'd10 + {4'd0, m2};
        
        // H1 range
        if (hours < 8'd10) h1_max = 4'd0;
        else h1_max = (fmt == 1'b0) ? 8'd2 : 8'd1;
        
        // H2 range based on H1
        if (fmt == 1'b0) begin  // 24-hour
            if (h1 == 4'd2) h2_max = 4'd3;
            else h2_max = 4'd9;
        end else begin  // 12-hour
            h2_max = (h1 == 4'd0) ? 4'd9 : 4'd2;
        end
        
        // M1 range
        m1_max = 4'd5;
        
        // M2 range
        m2_max = 4'd9;
        
        get_ranges = {h1_max, h2_max, m1_max, m2_max};
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        time_out <= 16'd0;
        done <= 1'b0;
        cycles <= 8'd0;
        h1 <= 4'd0;
        h2 <= 4'd0;
        m1 <= 4'd0;
        m2 <= 4'd0;
        best_h1 <= 4'd0;
        best_h2 <= 4'd0;
        best_m1 <= 4'd0;
        best_m2 <= 4'd0;
        best_score <= 8'd255;
        candidate_score <= 8'd0;
        h1_count <= 4'd0;
        h2_count <= 4'd0;
        m1_count <= 4'd0;
        m2_count <= 4'd0;
        h1_start <= 8'd0;
        h1_end <= 8'd0;
        h2_start <= 8'd0;
        h2_end <= 8'd0;
        m1_start <= 8'd0;
        m1_end <= 8'd0;
        m2_start <= 8'd0;
        m2_end <= 8'd0;
        candidate_time <= 16'd0;
        candidate_out <= 16'd0;
        valid_range <= 2'd0;
    end else begin
        state <= next_state;
        cycles <= cycles + 8'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycles <= 8'd0;
                best_score <= 8'd255;
                valid_range <= 2'd0;
                if (start) begin
                    h1 <= time_in[15:12];
                    h2 <= time_in[11:8];
                    m1 <= time_in[7:4];
                    m2 <= time_in[3:0];
                end
            end
            
            CHECK_H1: begin
                valid_range <= valid_time(h1, h2, m1, m2, format) ? 2'd1 : 2'd0;
                // Set ranges
                if (format == 1'b0) begin  // 24-hour
                    h1_start <= 4'd0;
                    h1_end <= 4'd2;
                end else begin  // 12-hour
                    h1_start <= 4'd0;
                    h1_end <= 4'd1;
                end
                h1_count <= 4'd0;
            end
            
            CHECK_H2: begin
                // Set H2 range based on H1
                if (format == 1'b0) begin  // 24-hour
                    if (h1 == 4'd2) h2_end <= 4'd3;
                    else h2_end <= 4'd9;
                end else begin  // 12-hour
                    h2_end <= (h1 == 4'd0) ? 4'd9 : 4'd2;
                end
                h2_count <= 4'd0;
            end
            
            CHECK_M1: begin
                m1_start <= 4'd0;
                m1_end <= 4'd5;
                m1_count <= 4'd0;
            end
            
            CHECK_M2: begin
                m2_start <= 4'd0;
                m2_end <= 4'd9;
                m2_count <= 4'd0;
            end
            
            COMPUTE: begin
                // Generate candidate and compute score
                candidate_out <= {h1_count, h2_count, m1_count, m2_count};
                candidate_score <= count_changes(h1_count, h2_count, m1_count, m2_count, h1, h2, m1, m2);
                
                // Update counters
                if (m2_count < m2_end) begin
                    m2_count <= m2_count + 4'd1;
                end else begin
                    m2_count <= m2_start;
                    if (m1_count < m1_end) begin
                        m1_count <= m1_count + 4'd1;
                    end else begin
                        m1_count <= m1_start;
                        if (h2_count < h2_end) begin
                            h2_count <= h2_count + 4'd1;
                        end else begin
                            h2_count <= h2_start;
                            if (h1_count < h1_end) begin
                                h1_count <= h1_count + 4'd1;
                            end
                        end
                    end
                end
            end
            
            FIND_BEST: begin
                if (valid_time(h1_count, h2_count, m1_count, m2_count, format)) begin
                    if (candidate_score < best_score) begin
                        best_score <= candidate_score;
                        best_h1 <= h1_count;
                        best_h2 <= h2_count;
                        best_m1 <= m1_count;
                        best_m2 <= m2_count;
                    end
                end
            end
            
            DONE: begin
                done <= 1'b1;
                time_out <= pack_time(best_h1, best_h2, best_m1, best_m2);
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = CHECK_H1;
        end
        
        CHECK_H1: begin
            next_state = CHECK_H2;
        end
        
        CHECK_H2: begin
            next_state = CHECK_M1;
        end
        
        CHECK_M1: begin
            next_state = CHECK_M2;
        end
        
        CHECK_M2: begin
            next_state = COMPUTE;
        end
        
        COMPUTE: begin
            if (h1_count >= h1_end && h2_count >= h2_end && m1_count >= m1_end && m2_count >= m2_end) begin
                next_state = FIND_BEST;
            end else begin
                next_state = COMPUTE;
            end
        end
        
        FIND_BEST: begin
            next_state = DONE;
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
    
    // Safety timeout
    if (cycles >= MAX_CYCLES && state != IDLE) begin
        next_state = DONE;
    end
end

endmodule