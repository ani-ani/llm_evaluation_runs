module movie_theme (
    input clk,
    input rst_n,
    input in_start,
    input in_valid,
    input [31:0] in_data,
    output reg out_done,
    output reg out_possible
);

    // State definitions
    localparam [4:0] IDLE         = 5'd0;
    localparam [4:0] READ_F       = 5'd1;
    localparam [4:0] READ_T       = 5'd2;
    localparam [4:0] READ_N       = 5'd3;
    localparam [4:0] READ_START   = 5'd4;
    localparam [4:0] READ_END     = 5'd5;
    localparam [4:0] COMPUTE      = 5'd6;
    localparam [4:0] DP_LOOP      = 5'd7;
    localparam [4:0] CHECK_RESULT = 5'd8;
    localparam [4:0] NEXT_FREQ    = 5'd9;
    localparam [4:0] DONE         = 5'd10;

    // Maximum constants
    localparam [31:0] MAX_FREQ    = 32'd10;
    localparam [31:0] MAX_INTERVAL = 32'd100;

    // Registers for state and data
    reg [4:0] state;
    reg [31:0] f;
    reg [31:0] freq_count;
    reg [31:0] current_t;
    reg [31:0] current_n;
    reg [31:0] interval_count;
    reg [31:0] prev_end;
    reg [31:0] temp_start;
    reg overall_possible;
    reg skip_dp;
    reg dp_plus;
    reg dp_minus;
    reg [31:0] i;
    reg [31:0] L_array [0:99];
    reg [31:0] H_array [0:99];
    reg [31:0] gap_array [0:99];

    // State transition and data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_done <= 1'b0;
            out_possible <= 1'b0;
            f <= 32'd0;
            freq_count <= 32'd0;
            current_t <= 32'd0;
            current_n <= 32'd0;
            interval_count <= 32'd0;
            prev_end <= 32'd0;
            temp_start <= 32'd0;
            overall_possible <= 1'b1;
            skip_dp <= 1'b0;
            dp_plus <= 1'b0;
            dp_minus <= 1'b0;
            i <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    out_done <= 1'b0;
                    if (in_start) begin
                        state <= READ_F;
                        overall_possible <= 1'b1;
                        freq_count <= 32'd0;
                    end
                end

                READ_F: begin
                    if (in_valid) begin
                        f <= in_data;
                        state <= READ_T;
                    end
                end

                READ_T: begin
                    if (in_valid) begin
                        current_t <= in_data;
                        state <= READ_N;
                    end
                end

                READ_N: begin
                    if (in_valid) begin
                        current_n <= in_data;
                        interval_count <= 32'd0;
                        skip_dp <= 1'b0;
                        state <= READ_START;
                    end
                end

                READ_START: begin
                    if (in_valid) begin
                        temp_start <= in_data;
                        state <= READ_END;
                    end
                end

                READ_END: begin
                    if (in_valid) begin
                        // Compute L and H
                        L_array[interval_count] <= in_data - temp_start;
                        H_array[interval_count] <= current_t - (in_data - temp_start);
                        // Check if L exceeds current_t
                        if (in_data - temp_start > current_t) begin
                            skip_dp <= 1'b1;
                            overall_possible <= 1'b0;
                        end
                        // Compute gap if not first interval
                        if (interval_count > 0) begin
                            gap_array[interval_count-1] <= temp_start - prev_end;
                        end
                        prev_end <= in_data;
                        interval_count <= interval_count + 1;
                        if (interval_count + 1 < current_n) begin
                            state <= READ_START;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    if (skip_dp) begin
                        state <= NEXT_FREQ;
                    end else if (current_n == 32'd1) begin
                        // Single interval, always possible if L <= current_t
                        state <= NEXT_FREQ;
                    end else begin
                        // Initialize DP
                        dp_plus <= 1'b1;
                        dp_minus <= 1'b1;
                        i <= 32'd0;
                        state <= DP_LOOP;
                    end
                end

                DP_LOOP: begin
                    if (i < current_n - 1) begin
                        // Compute compatibility conditions
                        reg comp_pp, comp_mm;
                        comp_pp = (L_array[i] <= H_array[i+1]);
                        comp_mm = (L_array[i+1] <= H_array[i]);
                        // Update DP states
                        dp_plus <= (dp_plus && comp_pp) || (dp_minus && (gap_array[i] >= 1));
                        dp_minus <= (dp_plus && (gap_array[i] >= 1)) || (dp_minus && comp_mm);
                        i <= i + 1;
                    end else begin
                        state <= CHECK_RESULT;
                    end
                end

                CHECK_RESULT: begin
                    if (!(dp_plus || dp_minus)) begin
                        overall_possible <= 1'b0;
                    end
                    state <= NEXT_FREQ;
                end

                NEXT_FREQ: begin
                    freq_count <= freq_count + 1;
                    if (freq_count + 1 < f) begin
                        state <= READ_T;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    out_done <= 1'b1;
                    out_possible <= overall_possible;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule