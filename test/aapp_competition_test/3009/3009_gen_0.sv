module energy_balance_line (
    input              clk,
    input              rst_n,
    input       [2:0]  n,
    input       [6:0]  x_i [0:7],
    input       [6:0]  y_i [0:7],
    input signed [12:0] e_i [0:7],
    input              start,
    output reg [31:0]  min_length,
    output reg         impossible,
    output reg         done
);

    // Internal parameters
    localparam IDLE        = 4'd0;
    localparam INIT        = 4'd1;
    localparam NEXT_MASK   = 4'd2;
    localparam ENERGY_SUM  = 4'd3;
    localparam CHECK_EN    = 4'd4;
    localparam BUILD_SET   = 4'd5;
    localparam HULL_INIT   = 4'd6;
    localparam HULL_SORT   = 4'd7;
    localparam HULL_SCAN   = 4'd8;
    localparam PERIM_INIT  = 4'd9;
    localparam PERIM_EDGE  = 4'd10;
    localparam PERIM_DONE  = 4'd11;
    localparam DONE_STATE  = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;

    reg [7:0] mask;                  // current subset mask
    reg [7:0] max_mask;              // up to (1<<n)-1

    // total energy and target
    reg signed [16:0] total_energy;  // sum of up to 8 * 2000 = 16000 (fits in 15 bits), keep margin
    reg signed [16:0] half_energy;
    reg signed [16:0] subset_energy;
    reg [3:0]         idx;

    // tolerance check
    reg        en_valid;

    // subset point storage (max 8)
    reg [3:0]  subset_cnt;
    reg [6:0]  sx   [0:7];
    reg [6:0]  sy   [0:7];

    // Convex hull data
    reg [2:0]  i_a, i_b; // generic indices

    // anchor: lowest y then lowest x
    reg [2:0]  anchor_idx;

    // For sorting by polar angle (simple insertion sort over <=8 points)
    reg [2:0]  sort_i, sort_j;

    // hull stack indices
    reg [3:0]  h_top;          // number of points in hull stack
    reg [2:0]  h_idx;          // generic hull index

    // Buffers for sorted points (excluding anchor as first element)
    reg [6:0]  px [0:7];
    reg [6:0]  py [0:7];

    // stack indices
    reg [2:0]  st [0:7]; // store indices into px/py (0..subset_cnt-1) in hull

    // Perimeter accumulation
    reg [3:0]  perim_idx;
    reg [31:0] perim_accum;    // Q16.16

    // Result tracking
    reg found_any;

    // Scratch for sqrt input
    reg [31:0] dist_dx2_dy2;

    // Combinational wires/functions

    // cross product sign for turn direction
    function automatic signed [31:0] cross_z;
        input signed [15:0] x1;
        input signed [15:0] y1;
        input signed [15:0] x2;
        input signed [15:0] y2;
        begin
            cross_z = x1 * y2 - y1 * x2;
        end
    endfunction

    // squared distance between two points (7-bit coords), result up to (99^2+99^2) < 2^15
    function automatic [31:0] dist2_int;
        input [6:0] x1;
        input [6:0] y1;
        input [6:0] x2;
        input [6:0] y2;
        reg signed [15:0] dx;
        reg signed [15:0] dy;
        begin
            dx = $signed({1'b0,x2}) - $signed({1'b0,x1});
            dy = $signed({1'b0,y2}) - $signed({1'b0,y1});
            dist2_int = dx*dx + dy*dy;
        end
    endfunction

    // Fixed-point sqrt (Q16.16 input, Q16.16 output) using non-restoring / binary search
    function automatic [31:0] fxp_sqrt_q16;
        input [31:0] x; // Q16.16
        reg [31:0] res;
        reg [31:0] bit;
        reg [31:0] tmp;
        begin
            // Standard integer sqrt on 32-bit, treat as 16.16 fixed, but we want sqrt in same Q16.16.
            // Here we perform integer sqrt on (x << 16) to maintain Q16.16.
            // Scale to 48-bit via implicit, but limit to 32-bit internal approximation for simplicity.
            // For this problem size, approximate: do integer sqrt directly and treat as Q16.16.
            // Use binary restoring sqrt on 32-bit.
            res = 0;
            bit = 1 << 30; // highest even bit
            // Align bit
            while (bit > x)
                bit = bit >> 2;
            while (bit != 0) begin
                if (x >= res + bit) begin
                    x   = x - (res + bit);
                    res = (res >> 1) + bit;
                end else begin
                    res = res >> 1;
                end
                bit = bit >> 2;
            end
            fxp_sqrt_q16 = res << 8; // heuristic scaling to approximate Q16.16
        end
    endfunction

    // Compare polar angle of (sx[a],sy[a]) and (sx[b],sy[b]) relative to anchor using cross product
    function automatic signed [31:0] polar_cmp;
        input [6:0] ax;
        input [6:0] ay;
        input [6:0] bx;
        input [6:0] by;
        input [6:0] ox;
        input [6:0] oy;
        reg signed [15:0] v1x, v1y, v2x, v2y;
        begin
            v1x = $signed({1'b0,ax}) - $signed({1'b0,ox});
            v1y = $signed({1'b0,ay}) - $signed({1'b0,oy});
            v2x = $signed({1'b0,bx}) - $signed({1'b0,ox});
            v2y = $signed({1'b0,by}) - $signed({1'b0,oy});
            polar_cmp = cross_z(v1x, v1y, v2x, v2y);
        end
    endfunction

    // Next-state logic (simple sequential pipeline style)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end

            INIT: begin
                next_state = NEXT_MASK;
            end

            NEXT_MASK: begin
                if (mask > max_mask)
                    next_state = DONE_STATE;
                else
                    next_state = ENERGY_SUM;
            end

            ENERGY_SUM: begin
                if (idx == n)
                    next_state = CHECK_EN;
            end

            CHECK_EN: begin
                if (en_valid)
                    next_state = BUILD_SET;
                else
                    next_state = NEXT_MASK;
            end

            BUILD_SET: begin
                if (idx == n)
                    next_state = (subset_cnt < 2) ? NEXT_MASK : HULL_INIT;
            end

            HULL_INIT: begin
                next_state = (subset_cnt == 2) ? PERIM_INIT : HULL_SORT;
            end

            HULL_SORT: begin
                if (sort_i == subset_cnt)
                    next_state = HULL_SCAN;
            end

            HULL_SCAN: begin
                if (idx == subset_cnt)
                    next_state = (h_top < 2) ? NEXT_MASK : PERIM_INIT;
            end

            PERIM_INIT: begin
                next_state = PERIM_EDGE;
            end

            PERIM_EDGE: begin
                if (perim_idx == h_top)
                    next_state = PERIM_DONE;
            end

            PERIM_DONE: begin
                next_state = NEXT_MASK;
            end

            DONE_STATE: begin
                // stay until new start
                if (!start)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            mask        <= 8'd0;
            max_mask    <= 8'd0;
            total_energy<= 17'sd0;
            half_energy <= 17'sd0;
            subset_energy <= 17'sd0;
            idx         <= 4'd0;
            subset_cnt  <= 4'd0;
            anchor_idx  <= 3'd0;
            sort_i      <= 3'd0;
            sort_j      <= 3'd0;
            h_top       <= 4'd0;
            h_idx       <= 3'd0;
            perim_idx   <= 4'd0;
            perim_accum <= 32'd0;
            min_length  <= 32'hFFFF_FFFF;
            impossible  <= 1'b0;
            done        <= 1'b0;
            found_any   <= 1'b0;
            en_valid    <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done        <= 1'b0;
                    impossible  <= 1'b0;
                    found_any   <= 1'b0;
                    if (start) begin
                        // nothing more, move to INIT
                    end
                end

                INIT: begin
                    // compute total_energy and mask limits
                    total_energy <= 17'sd0;
                    for (k = 0; k < 8; k = k + 1) begin
                        if (k < n)
                            total_energy <= total_energy + {{4{e_i[k][12]}}, e_i[k]};
                    end
                    // max_mask = (1<<n)-1
                    max_mask <= (8'd1 << n) - 1;
                    mask     <= 8'd1; // start from 1 to avoid empty subset
                    min_length <= 32'hFFFF_FFFF;
                    found_any  <= 1'b0;
                    done       <= 1'b0;
                end

                NEXT_MASK: begin
                    en_valid       <= 1'b0;
                    subset_energy  <= 17'sd0;
                    subset_cnt     <= 4'd0;
                    idx            <= 4'd0;
                    perim_accum    <= 32'd0;
                end

                ENERGY_SUM: begin
                    if (idx < n) begin
                        if (mask[idx]) begin
                            subset_energy <= subset_energy + {{4{e_i[idx][12]}}, e_i[idx]};
                        end
                        idx <= idx + 1'b1;
                    end
                end

                CHECK_EN: begin
                    // compute half_energy and check tolerance:
                    // |subset - total/2| <= 0.15 * total
                    // Use absolute values; assume total_energy positive for interpretation.
                    half_energy <= total_energy >>> 1;
                    begin
                        reg signed [16:0] diff;
                        reg signed [31:0] abs_diff;
                        reg signed [31:0] abs_tot;
                        reg signed [31:0] thr;
                        diff = subset_energy - (total_energy >>> 1);
                        abs_diff = (diff < 0) ? -diff : diff;
                        abs_tot  = (total_energy < 0) ? -total_energy : total_energy;
                        thr      = (abs_tot * 15) / 100; // 15% tolerance
                        if (abs_diff <= thr && mask != 0 && mask != max_mask)
                            en_valid <= 1'b1;
                        else
                            en_valid <= 1'b0;
                    end
                end

                BUILD_SET: begin
                    if (idx == 0) begin
                        subset_cnt <= 4'd0;
                    end
                    if (idx < n) begin
                        if (mask[idx]) begin
                            sx[subset_cnt] <= x_i[idx];
                            sy[subset_cnt] <= y_i[idx];
                            subset_cnt     <= subset_cnt + 1'b1;
                        end
                        idx <= idx + 1'b1;
                    end
                end

                HULL_INIT: begin
                    // find anchor: min y, then min x among subset
                    anchor_idx <= 3'd0;
                    if (subset_cnt > 0) begin
                        reg [6:0] min_x;
                        reg [6:0] min_y;
                        min_x = sx[0];
                        min_y = sy[0];
                        anchor_idx = 3'd0;
                        for (k = 1; k < 8; k = k + 1) begin
                            if (k < subset_cnt) begin
                                if (sy[k] < min_y || (sy[k] == min_y && sx[k] < min_x)) begin
                                    min_y = sy[k];
                                    min_x = sx[k];
                                    anchor_idx = k[2:0];
                                end
                            end
                        end
                    end

                    // build px,py list with anchor at index 0, rest following
                    for (k = 0; k < 8; k = k + 1) begin
                        px[k] <= 7'd0;
                        py[k] <= 7'd0;
                    end
                    if (subset_cnt == 2) begin
                        // simple line: perimeter is 2 * distance
                        px[0] <= sx[0];
                        py[0] <= sy[0];
                        px[1] <= sx[1];
                        py[1] <= sy[1];
                        h_top <= 4'd2;
                    end else if (subset_cnt > 2) begin
                        // place anchor at 0
                        px[0] <= sx[anchor_idx];
                        py[0] <= sy[anchor_idx];
                        // others in any order initially
                        reg [2:0] t;
                        t = 1;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (k < subset_cnt && k != anchor_idx) begin
                                px[t] <= sx[k];
                                py[t] <= sy[k];
                                t = t + 1;
                            end
                        end
                    end
                    sort_i <= 3'd2; // for insertion sort
                    sort_j <= 3'd0;
                    idx    <= 4'd0;
                end

                HULL_SORT: begin
                    // Insertion sort on points [1..subset_cnt-1] by polar angle around anchor
                    if (sort_i < subset_cnt) begin
                        reg [6:0] key_x;
                        reg [6:0] key_y;
                        reg [2:0] j;
                        key_x = px[sort_i];
                        key_y = py[sort_i];
                        j     = sort_i - 1;
                        while (j >= 1 && polar_cmp(px[j], py[j], key_x, key_y, px[0], py[0]) < 0) begin
                            px[j+1] <= px[j];
                            py[j+1] <= py[j];
                            if (j == 1) begin
                                j = 0; // to exit
                            end else begin
                                j = j - 1;
                            end
                        end
                        px[j+1] <= key_x;
                        py[j+1] <= key_y;
                        sort_i  <= sort_i + 1'b1;
                    end
                end

                HULL_SCAN: begin
                    // Graham scan over px/py; px[0] is anchor, others sorted
                    if (idx == 0) begin
                        // init stack with first two points
                        st[0]  <= 3'd0;
                        st[1]  <= 3'd1;
                        h_top  <= 4'd2;
                        idx    <= 4'd2;
                    end else if (idx < subset_cnt) begin
                        // process point idx
                        reg keep_loop;
                        keep_loop = 1'b1;
                        while (h_top >= 2 && keep_loop) begin
                            reg [2:0] top1;
                            reg [2:0] top2;
                            reg signed [15:0] v1x, v1y, v2x, v2y;
                            reg signed [31:0] cz;
                            top1 = st[h_top-1];
                            top2 = st[h_top-2];
                            v1x = $signed({1'b0,px[top1]}) - $signed({1'b0,px[top2]});
                            v1y = $signed({1'b0,py[top1]}) - $signed({1'b0,py[top2]});
                            v2x = $signed({1'b0,px[idx]})   - $signed({1'b0,px[top1]});
                            v2y = $signed({1'b0,py[idx]})   - $signed({1'b0,py[top1]});
                            cz  = cross_z(v1x, v1y, v2x, v2y);
                            if (cz <= 0) begin
                                // pop
                                h_top <= h_top - 1'b1;
                            end else begin
                                keep_loop = 1'b0;
                            end
                        end
                        st[h_top] <= idx[2:0];
                        h_top     <= h_top + 1'b1;
                        idx       <= idx + 1'b1;
                    end
                end

                PERIM_INIT: begin
                    perim_accum <= 32'd0;
                    perim_idx   <= 4'd0;
                end

                PERIM_EDGE: begin
                    if (perim_idx < h_top) begin
                        reg [2:0] i1;
                        reg [2:0] i2;
                        reg [6:0] x1, y1, x2, y2;
                        reg [31:0] d2;
                        reg [31:0] d_q16;
                        if (h_top == 2) begin
                            // for 2 points: perimeter is 2 * distance
                            i1 = 3'd0;
                            i2 = 3'd1;
                            x1 = px[i1];
                            y1 = py[i1];
                            x2 = px[i2];
                            y2 = py[i2];
                            d2 = dist2_int(x1,y1,x2,y2);
                            d_q16 = fxp_sqrt_q16(d2 << 16);
                            perim_accum <= d_q16 << 1; // *2
                            perim_idx   <= h_top; // done
                        end else begin
                            i1 = st[perim_idx];
                            if (perim_idx == h_top-1)
                                i2 = st[0];
                            else
                                i2 = st[perim_idx+1];
                            x1 = px[i1];
                            y1 = py[i1];
                            x2 = px[i2];
                            y2 = py[i2];
                            d2 = dist2_int(x1,y1,x2,y2);
                            d_q16 = fxp_sqrt_q16(d2 << 16);
                            perim_accum <= perim_accum + d_q16;
                            perim_idx   <= perim_idx + 1'b1;
                        end
                    end
                end

                PERIM_DONE: begin
                    // update minimum perimeter
                    if (perim_accum < min_length) begin
                        min_length <= perim_accum;
                    end
                    found_any <= 1'b1;
                    // advance mask
                    mask <= mask + 1'b1;
                end

                DONE_STATE: begin
                    done       <= 1'b1;
                    impossible <= (found_any == 1'b0);
                    // stay until new start; mask etc unchanged
                end

                default: ;
            endcase
        end
    end

endmodule