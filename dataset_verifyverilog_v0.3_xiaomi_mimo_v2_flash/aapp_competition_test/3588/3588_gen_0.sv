module ShareTracker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire in_valid,
    input wire [8:0] in_day,      // Day: 1-365
    input wire [9:0] in_shares,   // Shares: 1-1000
    output reg out_valid,
    output reg [8:0] out_day,
    output reg [19:0] out_shares,
    output reg done
);

// State machine parameters
localparam [1:0] IDLE      = 2'd0;
localparam [1:0] COLLECT   = 2'd1;
localparam [1:0] OUTPUT    = 2'd2;
localparam [1:0] FINISH    = 2'd3;

// State registers
reg [1:0] state;
reg [1:0] next_state;

// Day memory: 365 entries of 20-bit sums (max 1,000,000)
// Packed array for Icarus Verilog compatibility
reg [19:0] day_sums [0:364];  // Index 0 = day 1, index 364 = day 365

// Output counter and flags
reg [8:0] scan_day;  // Current day being scanned (0-364)
reg output_started;
reg [9:0] scan_count;  // Safety counter for scan loop
localparam [9:0] MAX_SCAN = 10'd500;  // Prevent infinite loops

// Internal control signals
reg collect_done;

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = COLLECT;
            else
                next_state = IDLE;
        end
        
        COLLECT: begin
            if (collect_done)
                next_state = OUTPUT;
            else
                next_state = COLLECT;
        end
        
        OUTPUT: begin
            if (scan_day >= 9'd364 && output_started && scan_count >= MAX_SCAN)
                next_state = FINISH;
            else
                next_state = OUTPUT;
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Combined sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        for (integer i = 0; i < 365; i = i + 1) begin
            day_sums[i] <= 20'd0;
        end
        out_valid <= 1'b0;
        out_day <= 9'd0;
        out_shares <= 20'd0;
        done <= 1'b0;
        scan_day <= 9'd0;
        output_started <= 1'b0;
        collect_done <= 1'b0;
        scan_count <= 10'd0;
    end else begin
        case (state)
            IDLE: begin
                // Clear outputs and flags when entering IDLE
                out_valid <= 1'b0;
                out_day <= 9'd0;
                out_shares <= 20'd0;
                done <= 1'b0;
                scan_day <= 9'd0;
                output_started <= 1'b0;
                collect_done <= 1'b0;
                scan_count <= 10'd0;
                // Reset memory when start is asserted
                if (start) begin
                    for (integer i = 0; i < 365; i = i + 1) begin
                        day_sums[i] <= 20'd0;
                    end
                end
            end
            
            COLLECT: begin
                if (in_valid) begin
                    // Add shares to day sum (day_in is 1-365, convert to 0-364)
                    if (in_day >= 9'd1 && in_day <= 9'd365) begin
                        day_sums[in_day - 9'd1] <= day_sums[in_day - 9'd1] + in_shares;
                    end
                    collect_done <= 1'b0;  // Clear done if new data arrives
                end else begin
                    // No more input data
                    collect_done <= 1'b1;
                end
                out_valid <= 1'b0;
                done <= 1'b0;
            end
            
            OUTPUT: begin
                if (!output_started) begin
                    // Initialize output scan
                    scan_day <= 9'd0;
                    output_started <= 1'b1;
                    out_valid <= 1'b0;
                    scan_count <= 10'd0;
                end else begin
                    // Check if current day has non-zero shares
                    if (day_sums[scan_day] != 20'd0) begin
                        out_valid <= 1'b1;
                        out_day <= scan_day + 9'd1;  // Convert back to 1-365
                        out_shares <= day_sums[scan_day];
                    end else begin
                        out_valid <= 1'b0;
                    end
                    
                    // Advance to next day
                    if (scan_day < 9'd364) begin
                        scan_day <= scan_day + 9'd1;
                    end
                    
                    // Increment scan count (prevent infinite loop)
                    if (scan_count < MAX_SCAN) begin
                        scan_count <= scan_count + 10'd1;
                    end
                end
                done <= 1'b0;
                collect_done <= 1'b0;
            end
            
            FINISH: begin
                out_valid <= 1'b0;
                out_day <= 9'd0;
                out_shares <= 20'd0;
                done <= 1'b1;
                collect_done <= 1'b0;
            end
            
            default: begin
                out_valid <= 1'b0;
                out_day <= 9'd0;
                out_shares <= 20'd0;
                done <= 1'b0;
                collect_done <= 1'b0;
            end
        endcase
    end
end

endmodule