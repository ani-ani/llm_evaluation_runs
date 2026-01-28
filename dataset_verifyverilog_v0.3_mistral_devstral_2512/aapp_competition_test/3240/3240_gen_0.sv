module binary_town_election(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  k,
    input  wire [3:0]  v,
    input  wire [7:0]  p0, p1, p2, p3, p4, p5, p6, p7, p8,
    input  wire [7:0]  b0, b1, b2, b3, b4, b5, b6, b7, b8,
    output reg  [7:0]  best_b,
    output reg         done
);

    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] INIT            = 4'd1;
    localparam [3:0] SUBSET_LOOP     = 4'd2;
    localparam [3:0] COMPUTE_SUBSET  = 4'd3;
    localparam [3:0] ADD_PROB        = 4'd4;
    localparam [3:0] PREPARE_BV_LOOP = 4'd5;
    localparam [3:0] BV_LOOP         = 4'd6;
    localparam [3:0] COMPUTE_EXPECTED = 4'd7;
    localparam [3:0] UPDATE_MAX      = 4'd8;
    localparam [3:0] DONE_STATE      = 4'd9;

    reg [3:0] state, next_state;

    // Counters and registers
    reg [8:0] subset_counter;
    reg [7:0] bv_counter;
    reg [7:0] r_counter;
    reg [7:0] voter_counter;

    // Probability array (128-bit entries)
    reg [127:0] prob [0:255];

    // Intermediate values
    reg [127:0] prob_total;
    reg [127:0] expected;
    reg [127:0] max_expected;
    reg [7:0]  total_b;
    reg [7:0]  current_bv;
    reg [7:0]  best_bv;

    // Voter data arrays
    reg [7:0] p [0:8];
    reg [7:0] b [0:8];

    // Number of other voters
    reg [3:0] num_other;

    // Popcount lookup table
    function [3:0] popcount;
        input [7:0] value;
        begin
            popcount = value[0] + value[1] + value[2] + value[3] + 
                       value[4] + value[5] + value[6] + value[7];
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            subset_counter <= 9'd0;
            bv_counter <= 8'd0;
            r_counter <= 8'd0;
            voter_counter <= 8'd0;
            prob_total <= 128'd0;
            expected <= 128'd0;
            max_expected <= 128'd0;
            total_b <= 8'd0;
            current_bv <= 8'd0;
            best_bv <= 8'd0;
            best_b <= 8'd0;
            done <= 1'b0;

            // Initialize probability array
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                prob[i] <= 128'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Load voter data
                p[0] = p0; p[1] = p1; p[2] = p2; p[3] = p3; p[4] = p4;
                p[5] = p5; p[6] = p6; p[7] = p7; p[8] = p8;
                b[0] = b0; b[1] = b1; b[2] = b2; b[3] = b3; b[4] = b4;
                b[5] = b5; b[6] = b6; b[7] = b7; b[8] = b8;
                num_other = v - 4'd1;
                next_state = SUBSET_LOOP;
            end

            SUBSET_LOOP: begin
                if (subset_counter == (1 << num_other) - 1) begin
                    next_state = PREPARE_BV_LOOP;
                else begin
                    next_state = COMPUTE_SUBSET;
                end
            end

            COMPUTE_SUBSET: begin
                next_state = ADD_PROB;
            end

            ADD_PROB: begin
                next_state = SUBSET_LOOP;
            end

            PREPARE_BV_LOOP: begin
                if (bv_counter == (1 << k) - 1) begin
                    next_state = DONE_STATE;
                else begin
                    next_state = BV_LOOP;
                end
            end

            BV_LOOP: begin
                next_state = COMPUTE_EXPECTED;
            end

            COMPUTE_EXPECTED: begin
                next_state = UPDATE_MAX;
            end

            UPDATE_MAX: begin
                next_state = PREPARE_BV_LOOP;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State actions
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
            end

            INIT: begin
                // Already handled in next_state logic
            end

            SUBSET_LOOP: begin
                // Increment subset counter
                subset_counter <= subset_counter + 9'd1;
            end

            COMPUTE_SUBSET: begin
                // Compute total_b and prob_total for current subset
                total_b <= 8'd0;
                prob_total <= 128'd1 << 8; // Scale by 256
                voter_counter <= 8'd0;
            end

            ADD_PROB: begin
                // Add to probability array
                integer idx = total_b % (1 << k);
                prob[idx] <= prob[idx] + prob_total;
            end

            PREPARE_BV_LOOP: begin
                // Prepare for bv loop
                bv_counter <= bv_counter + 8'd1;
                current_bv <= bv_counter;
                r_counter <= 8'd0;
                expected <= 128'd0;
            end

            BV_LOOP: begin
                // Compute expected value for current bv
                r_counter <= r_counter + 8'd1;
            end

            COMPUTE_EXPECTED: begin
                // Compute expected value
                integer total = (r_counter + current_bv) % (1 << k);
                integer pop = popcount(total);
                expected <= expected + (prob[r_counter] * pop);
            end

            UPDATE_MAX: begin
                // Update best_bv
                if (expected > max_expected || (expected == max_expected && current_bv < best_bv)) begin
                    max_expected <= expected;
                    best_bv <= current_bv;
                end
            end

            DONE_STATE: begin
                best_b <= best_bv;
                done <= 1'b1;
            end

            default: begin
                // Default state handling
            end
        endcase
    end

    // Voter processing logic
    always @(posedge clk) begin
        if (state == COMPUTE_SUBSET && voter_counter < num_other) begin
            // Check if voter is in subset
            if (subset_counter[voter_counter]) begin
                total_b <= total_b + b[voter_counter];
                prob_total <= prob_total * p[voter_counter];
            end else begin
                prob_total <= prob_total * (256 - p[voter_counter]);
            end
            voter_counter <= voter_counter + 8'd1;
        end
    end

endmodule