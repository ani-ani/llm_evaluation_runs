module canyon_mapper(
    input  clk,
    input  rst_n,
    input  start,
    input  [15:0] x0,
    input  [15:0] y0,
    input  [15:0] x1,
    input  [15:0] y1,
    input  [15:0] x2,
    input  [15:0] y2,
    input  [15:0] x3,
    input  [15:0] y3,
    output reg [31:0] side_length,
    output reg        done
);

    // Internal registers
    reg [3:0]  cycle_cnt;
    reg        busy;

    // Signed versions of coordinates
    wire signed [15:0] sx0 = x0;
    wire signed [15:0] sy0 = y0;
    wire signed [15:0] sx1 = x1;
    wire signed [15:0] sy1 = y1;
    wire signed [15:0] sx2 = x2;
    wire signed [15:0] sy2 = y2;
    wire signed [15:0] sx3 = x3;
    wire signed [15:0] sy3 = y3;

    // Bounding box registers (signed Q8.8)
    reg signed [15:0] min_x, max_x;
    reg signed [15:0] min_y, max_y;

    // Width/height (signed Q8.8, non-negative expected)
    reg signed [15:0] width_q8_8;
    reg signed [15:0] height_q8_8;

    // Start edge detection
    reg start_d;
    wire start_pulse = start & ~start_d & ~busy; // accept new start only when not busy

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d     <= 1'b0;
        end else begin
            start_d     <= start;
        end
    end

    // Main control and datapath sequencing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy         <= 1'b0;
            cycle_cnt    <= 4'd0;
            done         <= 1'b0;
            side_length  <= 32'd0;
            min_x        <= 16'sd0;
            max_x        <= 16'sd0;
            min_y        <= 16'sd0;
            max_y        <= 16'sd0;
            width_q8_8   <= 16'sd0;
            height_q8_8  <= 16'sd0;
        end else begin
            done <= 1'b0; // default, asserted only when result ready

            if (start_pulse) begin
                // Initialize bounding box with first vertex
                min_x       <= sx0;
                max_x       <= sx0;
                min_y       <= sy0;
                max_y       <= sy0;

                // Initialize control
                busy        <= 1'b1;
                cycle_cnt   <= 4'd1; // first cycle after capturing
            end else if (busy) begin
                cycle_cnt <= cycle_cnt + 4'd1;

                // Perform all computations combinationally during busy window;
                // results latched at specific cycles to meet 10-cycle latency.

                // Cycle 2: include second vertex
                if (cycle_cnt == 4'd1) begin
                    // Update min_x, max_x with x1
                    if (sx1 < min_x) min_x <= sx1;
                    if (sx1 > max_x) max_x <= sx1;
                    // Update min_y, max_y with y1
                    if (sy1 < min_y) min_y <= sy1;
                    if (sy1 > max_y) max_y <= sy1;
                end

                // Cycle 3: include third vertex
                if (cycle_cnt == 4'd2) begin
                    if (sx2 < min_x) min_x <= sx2;
                    if (sx2 > max_x) max_x <= sx2;
                    if (sy2 < min_y) min_y <= sy2;
                    if (sy2 > max_y) max_y <= sy2;
                end

                // Cycle 4: include fourth vertex
                if (cycle_cnt == 4'd3) begin
                    if (sx3 < min_x) min_x <= sx3;
                    if (sx3 > max_x) max_x <= sx3;
                    if (sy3 < min_y) min_y <= sy3;
                    if (sy3 > max_y) max_y <= sy3;
                end

                // Cycle 5: compute width and height (Q8.8)
                if (cycle_cnt == 4'd4) begin
                    width_q8_8  <= max_x - min_x;
                    height_q8_8 <= max_y - min_y;
                end

                // Cycle 6-9: no-op (reserved to satisfy 10-cycle latency)

                // Cycle 10: latch final side_length and signal done
                if (cycle_cnt == 4'd9) begin
                    // Choose max(width, height) using signed compare (values are >=0)
                    if (width_q8_8 >= height_q8_8) begin
                        // Extend Q8.8 to Q16.16: shift left by 8 (preserve sign)
                        side_length <= {{8{width_q8_8[15]}}, width_q8_8, 8'b0};
                    end else begin
                        side_length <= {{8{height_q8_8[15]}}, height_q8_8, 8'b0};
                    end
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    cycle_cnt <= 4'd0;
                end
            end
        end
    end

endmodule