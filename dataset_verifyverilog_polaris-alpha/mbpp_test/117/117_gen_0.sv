module string_to_fixed (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [63:0] str1,
    input  logic [63:0] str2,
    output logic [31:0] val1,
    output logic [31:0] val2,
    output logic        is_str1,
    output logic        is_str2,
    output logic        done
);

    typedef enum logic [2:0] {
        IDLE          = 3'd0,
        CHECK_CHARS   = 3'd1,
        CALC_INTEGER  = 3'd2,
        CALC_FRACTION = 3'd3,
        DONE_STATE    = 3'd4
    } state_t;

    state_t state, next_state;

    // Latency counter to ensure outputs valid 8 cycles after start
    logic [3:0] cycle_cnt;
    logic       start_d;

    // Internal storage of inputs
    logic [63:0] str1_reg, str2_reg;

    // Character arrays for convenience
    logic [7:0] s1 [7:0];
    logic [7:0] s2 [7:0];

    // Valid flags
    logic       s1_all_valid_chars;
    logic       s2_all_valid_chars;

    // Dot-related info
    logic       s1_has_dot, s2_has_dot;
    logic [2:0] s1_dot_pos, s2_dot_pos;

    // Parsed integer and fraction parts
    logic [19:0] s1_int_accum, s2_int_accum;     // enough for 8 digits (< 10^8)
    logic [19:0] s1_frac_accum, s2_frac_accum;
    logic [3:0]  s1_frac_digits, s2_frac_digits; // 0..8

    // Fraction scaling
    logic [31:0] s1_frac_scaled, s2_frac_scaled;
    logic [31:0] s1_fixed, s2_fixed;

    // Flags for non-convertible
    logic s1_is_str, s2_is_str;

    // Unpack chars from registered strings
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : UNPACK
            assign s1[i] = str1_reg[63 - 8*i -: 8];
            assign s2[i] = str2_reg[63 - 8*i -: 8];
        end
    endgenerate

    // Sequential: state, counters, input latching
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            cycle_cnt  <= 4'd0;
            start_d    <= 1'b0;
            str1_reg   <= 64'd0;
            str2_reg   <= 64'd0;
        end else begin
            start_d <= start;

            // Start pulse detection and pipeline counter
            if (start && !start_d && state == IDLE) begin
                cycle_cnt <= 4'd0;
                str1_reg  <= str1;
                str2_reg  <= str2;
            end else if (state != IDLE) begin
                cycle_cnt <= cycle_cnt + 4'd1;
            end

            state <= next_state;
        end
    end

    // Combinational character checks and dot position detection
    always_comb begin
        // defaults
        s1_all_valid_chars = 1'b1;
        s2_all_valid_chars = 1'b1;
        s1_has_dot         = 1'b0;
        s2_has_dot         = 1'b0;
        s1_dot_pos         = 3'd0;
        s2_dot_pos         = 3'd0;

        for (int j = 0; j < 8; j++) begin
            // str1 char classification
            if (!((s1[j] >= "0" && s1[j] <= "9") || (s1[j] == "."))) begin
                s1_all_valid_chars = 1'b0;
            end
            if (s1[j] == ".") begin
                if (!s1_has_dot) begin
                    s1_has_dot = 1'b1;
                    s1_dot_pos = j[2:0];
                end else begin
                    // more than one dot -> invalid
                    s1_all_valid_chars = 1'b0;
                end
            end

            // str2 char classification
            if (!((s2[j] >= "0" && s2[j] <= "9") || (s2[j] == "."))) begin
                s2_all_valid_chars = 1'b0;
            end
            if (s2[j] == ".") begin
                if (!s2_has_dot) begin
                    s2_has_dot = 1'b1;
                    s2_dot_pos = j[2:0];
                end else begin
                    s2_all_valid_chars = 1'b0;
                end
            end
        end
    end

    // Integer and fraction accumulation (combinational)
    always_comb begin
        // defaults
        s1_int_accum    = 20'd0;
        s1_frac_accum   = 20'd0;
        s1_frac_digits  = 4'd0;
        s2_int_accum    = 20'd0;
        s2_frac_accum   = 20'd0;
        s2_frac_digits  = 4'd0;

        // If invalid chars, parsed values will be ignored
        if (s1_all_valid_chars) begin
            // str1 integer part
            for (int j = 0; j < 8; j++) begin
                if (s1[j] == ".") begin
                    // stop at dot
                end else if (s1[j] >= "0" && s1[j] <= "9") begin
                    if (!s1_has_dot || j < s1_dot_pos) begin
                        s1_int_accum = (s1_int_accum * 10) + (s1[j] - "0");
                    end
                end
            end
            // str1 fractional part
            if (s1_has_dot) begin
                for (int j = s1_dot_pos+1; j < 8; j++) begin
                    if (s1[j] >= "0" && s1[j] <= "9") begin
                        s1_frac_accum  = (s1_frac_accum * 10) + (s1[j] - "0");
                        s1_frac_digits = s1_frac_digits + 4'd1;
                    end
                end
            end
        end

        if (s2_all_valid_chars) begin
            // str2 integer part
            for (int j = 0; j < 8; j++) begin
                if (s2[j] == ".") begin
                    // stop at dot
                end else if (s2[j] >= "0" && s2[j] <= "9") begin
                    if (!s2_has_dot || j < s2_dot_pos) begin
                        s2_int_accum = (s2_int_accum * 10) + (s2[j] - "0");
                    end
                end
            end
            // str2 fractional part
            if (s2_has_dot) begin
                for (int j = s2_dot_pos+1; j < 8; j++) begin
                    if (s2[j] >= "0" && s2[j] <= "9") begin
                        s2_frac_accum  = (s2_frac_accum * 10) + (s2[j] - "0");
                        s2_frac_digits = s2_frac_digits + 4'd1;
                    end
                end
            end
        end
    end

    // Fractional scaling (combinational, parallel, using power-of-10 constants)
    function automatic [31:0] scale_frac(
        input logic [19:0] frac,
        input logic [3:0]  digits
    );
        logic [31:0] num;
        logic [31:0] denom;
        begin
            num = {12'd0, frac} * 32'd65536; // frac * 65536
            unique case (digits)
                4'd0: denom = 32'd1;
                4'd1: denom = 32'd10;
                4'd2: denom = 32'd100;
                4'd3: denom = 32'd1000;
                4'd4: denom = 32'd10000;
                4'd5: denom = 32'd100000;
                4'd6: denom = 32'd1000000;
                4'd7: denom = 32'd10000000;
                4'd8: denom = 32'd100000000;
                default: denom = 32'd1;
            endcase
            if (denom != 32'd0)
                scale_frac = num / denom;
            else
                scale_frac = 32'd0;
        end
    endfunction

    always_comb begin
        s1_frac_scaled = (s1_all_valid_chars) ? scale_frac(s1_frac_accum, s1_frac_digits) : 32'd0;
        s2_frac_scaled = (s2_all_valid_chars) ? scale_frac(s2_frac_accum, s2_frac_digits) : 32'd0;

        s1_fixed = ({s1_int_accum,16'd0}) + s1_frac_scaled;
        s2_fixed = ({s2_int_accum,16'd0}) + s2_frac_scaled;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && !start_d) begin
                    next_state = CHECK_CHARS;
                end
            end
            CHECK_CHARS: begin
                next_state = CALC_INTEGER;
            end
            CALC_INTEGER: begin
                next_state = CALC_FRACTION;
            end
            CALC_FRACTION: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                // Hold DONE until 8-cycle latency satisfied, then go IDLE
                if (cycle_cnt >= 4'd7) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and flags (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val1    <= 32'd0;
            val2    <= 32'd0;
            is_str1 <= 1'b0;
            is_str2 <= 1'b0;
            done    <= 1'b0;
            s1_is_str <= 1'b0;
            s2_is_str <= 1'b0;
        end else begin
            // Defaults each cycle
            done <= 1'b0;

            case (next_state)
                CHECK_CHARS: begin
                    // Determine if each string is numeric-only
                    s1_is_str <= ~s1_all_valid_chars;
                    s2_is_str <= ~s2_all_valid_chars;
                end

                CALC_INTEGER: begin
                    // No registered outputs yet; computations are combinational
                end

                CALC_FRACTION: begin
                    // No registered outputs yet; computations are combinational
                end

                DONE_STATE: begin
                    // Outputs must be valid at 8 cycles from start; we assert done here
                    // Conversion or pass-through decision
                    if (!s1_is_str && s1_all_valid_chars)
                        val1 <= s1_fixed;
                    else
                        val1 <= str1_reg[31:0]; // pass-through header (lower 32 bits)

                    if (!s2_is_str && s2_all_valid_chars)
                        val2 <= s2_fixed;
                    else
                        val2 <= str2_reg[31:0];

                    is_str1 <= (s1_is_str || !s1_all_valid_chars);
                    is_str2 <= (s2_is_str || !s2_all_valid_chars);

                    if (cycle_cnt >= 4'd7)
                        done <= 1'b1;
                end

                default: begin
                    // IDLE or others
                    if (next_state == IDLE) begin
                        done    <= 1'b0;
                        is_str1 <= 1'b0;
                        is_str2 <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
