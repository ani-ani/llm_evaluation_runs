module rgb_to_hsv(
    input  clk,
    input  rst_n,
    input  start,
    input  [7:0] r,
    input  [7:0] g,
    input  [7:0] b,
    output reg [15:0] h,
    output reg [15:0] s,
    output reg [15:0] v,
    output reg        done
);

    // FSM states (16-cycle pipeline from start to done)
    localparam [4:0]
        ST_IDLE   = 5'd0,
        ST_1      = 5'd1,
        ST_2      = 5'd2,
        ST_3      = 5'd3,
        ST_4      = 5'd4,
        ST_5      = 5'd5,
        ST_6      = 5'd6,
        ST_7      = 5'd7,
        ST_8      = 5'd8,
        ST_9      = 5'd9,
        ST_10     = 5'd10,
        ST_11     = 5'd11,
        ST_12     = 5'd12,
        ST_13     = 5'd13,
        ST_14     = 5'd14,
        ST_15     = 5'd15,
        ST_DONE   = 5'd16;

    reg [4:0] state, next_state;

    // Latched inputs
    reg [7:0] r_reg, g_reg, b_reg;

    // Scaled RGB: r_scaled = r * 1000 / 255
    reg [17:0] r_scaled; // fits up to 1000
    reg [17:0] g_scaled;
    reg [17:0] b_scaled;

    // Max/min and delta
    reg [17:0] max_val;
    reg [17:0] min_val;
    reg [17:0] delta;

    // Hue internals
    reg [1:0]  max_sel;   // 0:r,1:g,2:b,3:equal
    reg signed [18:0] diff_rg;
    reg signed [18:0] diff_gb;
    reg signed [18:0] diff_br;
    reg signed [31:0] hue_tmp; // intermediate before clamp

    // Saturation internals
    reg [35:0] sat_num;   // delta * 100000
    reg [35:0] sat_tmp;   // for division and rounding

    // Value internals
    reg [35:0] val_tmp;   // max_val * 100000

    // Start latch (to avoid re-trigger if start held)
    reg start_d;

    // Combinational next state
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:   next_state = (start && !start_d) ? ST_1 : ST_IDLE;
            ST_1:      next_state = ST_2;
            ST_2:      next_state = ST_3;
            ST_3:      next_state = ST_4;
            ST_4:      next_state = ST_5;
            ST_5:      next_state = ST_6;
            ST_6:      next_state = ST_7;
            ST_7:      next_state = ST_8;
            ST_8:      next_state = ST_9;
            ST_9:      next_state = ST_10;
            ST_10:     next_state = ST_11;
            ST_11:     next_state = ST_12;
            ST_12:     next_state = ST_13;
            ST_13:     next_state = ST_14;
            ST_14:     next_state = ST_15;
            ST_15:     next_state = ST_DONE;
            ST_DONE:   next_state = ST_IDLE;
            default:   next_state = ST_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            start_d  <= 1'b0;
            r_reg    <= 8'd0;
            g_reg    <= 8'd0;
            b_reg    <= 8'd0;
            r_scaled <= 18'd0;
            g_scaled <= 18'd0;
            b_scaled <= 18'd0;
            max_val  <= 18'd0;
            min_val  <= 18'd0;
            delta    <= 18'd0;
            max_sel  <= 2'd0;
            diff_rg  <= 19'sd0;
            diff_gb  <= 19'sd0;
            diff_br  <= 19'sd0;
            hue_tmp  <= 32'sd0;
            sat_num  <= 36'd0;
            sat_tmp  <= 36'd0;
            val_tmp  <= 36'd0;
            h        <= 16'd0;
            s        <= 16'd0;
            v        <= 16'd0;
            done     <= 1'b0;
        end else begin
            state   <= next_state;
            start_d <= start;
            done    <= 1'b0;

            case (state)
                ST_IDLE: begin
                    // Wait for start; latch inputs on transition to ST_1
                    if (start && !start_d) begin
                        r_reg <= r;
                        g_reg <= g;
                        b_reg <= b;
                    end
                end

                // ST_1: compute scaled values r_scaled,g_scaled,b_scaled
                // r_scaled = (r * 1000 + 127) / 255  (integer with rounding)
                ST_1: begin
                    r_scaled <= ( (r_reg * 16'd1000) + 16'd127 ) / 8'd255;
                    g_scaled <= ( (g_reg * 16'd1000) + 16'd127 ) / 8'd255;
                    b_scaled <= ( (b_reg * 16'd1000) + 16'd127 ) / 8'd255;
                end

                // ST_2: determine max_val, min_val (parallel comparators) and max_sel
                ST_2: begin
                    // max
                    if (r_scaled >= g_scaled && r_scaled >= b_scaled) begin
                        max_val <= r_scaled;
                        max_sel <= 2'd0; // r
                    end else if (g_scaled >= r_scaled && g_scaled >= b_scaled) begin
                        max_val <= g_scaled;
                        max_sel <= 2'd1; // g
                    end else begin
                        max_val <= b_scaled;
                        max_sel <= 2'd2; // b
                    end

                    // min
                    if (r_scaled <= g_scaled && r_scaled <= b_scaled) begin
                        min_val <= r_scaled;
                    end else if (g_scaled <= r_scaled && g_scaled <= b_scaled) begin
                        min_val <= g_scaled;
                    end else begin
                        min_val <= b_scaled;
                    end
                end

                // ST_3: compute delta and equal case
                ST_3: begin
                    delta <= max_val - min_val;
                    if (max_val == min_val)
                        max_sel <= 2'd3; // special: max == min
                end

                // ST_4: precompute differences for hue
                ST_4: begin
                    diff_gb <= $signed({1'b0,g_scaled}) - $signed({1'b0,b_scaled});
                    diff_br <= $signed({1'b0,b_scaled}) - $signed({1'b0,r_scaled});
                    diff_rg <= $signed({1'b0,r_scaled}) - $signed({1'b0,g_scaled});
                end

                // ST_5: compute initial hue_tmp based on max_sel (before wrapping & clamp)
                ST_5: begin
                    if (delta == 18'd0 || max_val == 18'd0 || max_sel == 2'd3) begin
                        hue_tmp <= 32'sd0;
                    end else begin
                        case (max_sel)
                            2'd0: begin
                                // max = r: hue_base = (g_scaled - b_scaled) * 60
                                hue_tmp <= diff_gb * 32'sd60;
                            end
                            2'd1: begin
                                // max = g: hue_base = (b_scaled - r_scaled) * 60 + 12000
                                hue_tmp <= (diff_br * 32'sd60) + 32'sd12000;
                            end
                            2'd2: begin
                                // max = b: hue_base = (r_scaled - g_scaled) * 60 + 24000
                                hue_tmp <= (diff_rg * 32'sd60) + 32'sd24000;
                            end
                            default: begin
                                hue_tmp <= 32'sd0;
                            end
                        endcase
                    end
                end

                // ST_6: normalize hue into [0,36000)
                ST_6: begin
                    if (hue_tmp < 0)
                        hue_tmp <= hue_tmp + 32'sd36000;
                    else if (hue_tmp >= 32'sd36000)
                        hue_tmp <= hue_tmp - 32'sd36000;
                    else
                        hue_tmp <= hue_tmp;
                end

                // ST_7: compute saturation numerator: sat_num = delta * 100000
                ST_7: begin
                    if (max_val == 18'd0 || delta == 18'd0) begin
                        sat_num <= 36'd0;
                    end else begin
                        sat_num <= delta * 36'd100000;
                    end
                end

                // ST_8: finalize saturation with division and rounding
                // S = (delta * 100000) / max_val, range 0-100000 then scaled to 0-10000
                ST_8: begin
                    if (max_val == 18'd0 || delta == 18'd0) begin
                        s <= 16'd0;
                    end else begin
                        // Rounded division: (sat_num + max_val/2)/max_val
                        sat_tmp = sat_num + (max_val >> 1);
                        // sat_tmp/max_val in [0..100000]; we then scale down by /10 to 0..10000
                        // For rounding to nearest when scaling /10: add 5 before /10
                        begin : sat_calc_block
                            reg [35:0] sat_full;
                            reg [35:0] sat_rounded10;
                            sat_full      = sat_tmp / max_val;   // 0..100000
                            sat_rounded10 = (sat_full + 36'd5) / 10; // 0..10000
                            if (sat_rounded10 > 36'd10000)
                                s <= 16'd10000;
                            else
                                s <= sat_rounded10[15:0];
                        end
                    end
                end

                // ST_9: compute value: V = max_val * 100000 / 300000 -> scale to 0-10000
                ST_9: begin
                    if (max_val == 18'd0) begin
                        v <= 16'd0;
                    end else begin
                        // max_val in 0..1000; we want V in 0..10000 approximating max_val/1000
                        // Implement V = round( (max_val * 10000) / 1000 )
                        // Use (max_val * 10000 + 500)/1000
                        begin : val_calc_block
                            reg [27:0] val_full;
                            val_full = (max_val * 28'd10000 + 28'd500) / 10'd1000;
                            if (val_full > 28'd10000)
                                v <= 16'd10000;
                            else
                                v <= val_full[15:0];
                        end
                    end
                end

                // ST_10: clamp hue to [0,36000]
                ST_10: begin
                    if (hue_tmp < 0)
                        h <= 16'd0;
                    else if (hue_tmp > 32'sd36000)
                        h <= 16'd36000;
                    else
                        h <= hue_tmp[15:0];
                end

                // ST_11-ST_14: reserved / pipeline alignment (no operation)
                ST_11: begin end
                ST_12: begin end
                ST_13: begin end
                ST_14: begin end

                // ST_15: final stabilize stage (no-op, values already assigned)
                ST_15: begin end

                // ST_DONE: assert done, outputs stable
                ST_DONE: begin
                    done <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

endmodule