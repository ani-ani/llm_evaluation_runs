module widget_packing (
    input clk,
    input rst_n,
    input start,
    input [15:0] N,
    output reg [15:0] min_empty,
    output reg done)

// Internal registers
reg [7:0] h;
reg [7:0] w;
reg [15:0] min_empty;
reg [15:0] sampled_N;
reg [2:0] state;

// State definitions
localparam IDLE = 3'd0;
localparam SEARCH = 3'd1;
localparam COMPARE = 3'd2;
localparam DONE = 3'd3;

always @ (posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        h <= 8'b0;
        w <= 8'b0;
        min_empty <= 16'd65535;
        sampled_N <= 16'd0;
        state <= IDLE;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    sampled_N <= N;
                    state <= SEARCH;
                    h <= 8'd1;
                end
            end
            SEARCH: begin
                // Calculate W_min and W_max for current h
                integer W_min, W_max;
                W_min = (h + 1) / 2; // ceil(h/2)
                W_max = (2*h > 256) ? 256 : 2*h;
                w <= W_min;
                state <= COMPARE;
            end
            COMPARE: begin
                // Recalculate W_min and W_max each time? Or just use h?
                // Actually, since h is fixed during this H's loop, but in case h changed? No, h only changes when w exceeds W_max, but that happens in this same cycle's assignment? No, the h increment happens in this cycle's assignment, but the area calculation uses the current h before increment.
                // So compute W_max based on current h
                integer area, empty;
                W_min = (h + 1) / 2; // Not used here, but for clarity?
                W_max = (2*h > 256) ? 256 : 2*h;
                if (w > W_max) begin
                    h <= h + 1;
                    if (h > 256) begin
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        state <= SEARCH;
                    end
                end else begin
                    // Compute area
                    area = (integer)h * w; // Explicit cast may not be needed, but safe
                    if (area >= sampled_N) begin
                        empty = area - sampled_N;
                        if (empty < min_empty) begin
                            min_empty <= empty;
                        end
                    end
                    w <= w + 1;
                    state <= COMPARE;
                end
            end
            DONE: begin
                state <= DONE;
                done <= 1'b1;
            end
        endcase
    end
endmodule