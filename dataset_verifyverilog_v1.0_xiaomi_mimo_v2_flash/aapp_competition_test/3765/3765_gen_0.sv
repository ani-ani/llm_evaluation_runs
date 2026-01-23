module find_min_extensions (
    input clk,
    input rst_n,
    input start,
    input [15:0] a, b, h, w,
    input [17:0] mult0, mult1, mult2, mult3, mult4, mult5, mult6, mult7,
    output reg [4:0] k,
    output reg done
);

    // State definitions
    localparam [2:0] STATE_IDLE = 3'b000;
    localparam [2:0] STATE_CHECK0 = 3'b001;
    localparam [2:0] STATE_INIT = 3'b010;
    localparam [2:0] STATE_UPDATE = 3'b011;
    localparam [2:0] STATE_CHECK = 3'b100;
    localparam [2:0] STATE_NEXT = 3'b101;
    localparam [2:0] STATE_FAIL = 3'b110;
    localparam [2:0] STATE_DONE = 3'b111;

    // Maximum set size for non-dominated pairs
    localparam [7:0] SET_SIZE = 8'd256;

    // Registers for state machine
    reg [2:0] state, next_state;
    reg [3:0] i, next_i;  // Current multiplier index (0-8)
    reg [4:0] next_k;
    reg next_done;

    // Current set and next set for DP
    reg [SET_SIZE-1:0] curr_valid, next_valid;
    reg [16:0] curr_h_mult [0:255];
    reg [16:0] curr_w_mult [0:255];
    reg [16:0] next_h_mult [0:255];
    reg [16:0] next_w_mult [0:255];

    // Multiplier array
    wire [17:0] mult [0:7];
    assign mult[0] = mult0;
    assign mult[1] = mult1;
    assign mult[2] = mult2;
    assign mult[3] = mult3;
    assign mult[4] = mult4;
    assign mult[5] = mult5;
    assign mult[6] = mult6;
    assign mult[7] = mult7;

    // Temporary registers for update
    reg [16:0] cap_h, cap_w;
    reg [33:0] temp_product;
    reg [16:0] new_h, new_w;
    reg condition_met;

    // Pointer for iterating through current set
    reg [7:0] ptr;
    reg [7:0] next_ptr;
    reg [7:0] set_count;
    reg [7:0] next_set_count;

    // Variables for dominance checking
    reg is_dominated;
    reg [7:0] dom_ptr;

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_k = k;
        next_done = done;
        next_ptr = ptr;
        next_set_count = set_count;
        next_valid = curr_valid;
        for (integer j = 0; j < 256; j = j + 1) begin
            next_h_mult[j] = curr_h_mult[j];
            next_w_mult[j] = curr_w_mult[j];
        end

        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_CHECK0;
                    next_done = 1'b0;
                    next_k = 5'b11111;  // Initialize to -1
                end
            end

            STATE_CHECK0: begin
                // Check if no extensions needed
                if ((h >= a && w >= b) || (h >= b && w >= a)) begin
                    next_k = 5'd0;
                    next_state = STATE_DONE;
                end else begin
                    next_state = STATE_INIT;
                end
            end

            STATE_INIT: begin
                // Initialize set with (1,1)
                next_valid[0] = 1'b1;
                next_h_mult[0] = 17'd1;
                next_w_mult[0] = 17'd1;
                for (integer j = 1; j < 256; j = j + 1) begin
                    next_valid[j] = 1'b0;
                end
                next_i = 4'd0;
                next_ptr = 8'd0;
                next_set_count = 8'd1;
                next_state = STATE_UPDATE;
            end

            STATE_UPDATE: begin
                // Compute caps to prevent overflow
                cap_h = (a > b) ? ((a / h) + 17'd1) : ((b / h) + 17'd1);
                cap_w = (a > b) ? ((a / w) + 17'd1) : ((b / w) + 17'd1);

                // Process current pair
                if (ptr < SET_SIZE && curr_valid[ptr]) begin
                    // Option 1: multiply h by multiplier[i]
                    temp_product = curr_h_mult[ptr] * mult[i];
                    if (temp_product > cap_h) new_h = cap_h;
                    else new_h = temp_product[16:0];
                    new_w = curr_w_mult[ptr];

                    // Check dominance and add to next set
                    is_dominated = 1'b0;
                    for (dom_ptr = 8'd0; dom_ptr < next_set_count && !is_dominated; dom_ptr = dom_ptr + 8'd1) begin
                        if (next_valid[dom_ptr] && 
                            next_h_mult[dom_ptr] >= new_h && 
                            next_w_mult[dom_ptr] >= new_w) begin
                            is_dominated = 1'b1;
                        end
                    end
                    if (!is_dominated && next_set_count < SET_SIZE) begin
                        next_h_mult[next_set_count] = new_h;
                        next_w_mult[next_set_count] = new_w;
                        next_valid[next_set_count] = 1'b1;
                        next_set_count = next_set_count + 8'd1;
                    end

                    // Option 2: multiply w by multiplier[i]
                    temp_product = curr_w_mult[ptr] * mult[i];
                    if (temp_product > cap_w) new_w = cap_w;
                    else new_w = temp_product[16:0];
                    new_h = curr_h_mult[ptr];

                    // Check dominance and add to next set
                    is_dominated = 1'b0;
                    for (dom_ptr = 8'd0; dom_ptr < next_set_count && !is_dominated; dom_ptr = dom_ptr + 8'd1) begin
                        if (next_valid[dom_ptr] && 
                            next_h_mult[dom_ptr] >= new_h && 
                            next_w_mult[dom_ptr] >= new_w) begin
                            is_dominated = 1'b1;
                        end
                    end
                    if (!is_dominated && next_set_count < SET_SIZE) begin
                        next_h_mult[next_set_count] = new_h;
                        next_w_mult[next_set_count] = new_w;
                        next_valid[next_set_count] = 1'b1;
                        next_set_count = next_set_count + 8'd1;
                    end

                    next_ptr = ptr + 8'd1;
                    next_state = STATE_UPDATE;
                end else begin
                    next_ptr = 8'd0;
                    next_state = STATE_CHECK;
                end
            end

            STATE_CHECK: begin
                // Check if any pair satisfies the condition
                condition_met = 1'b0;
                for (integer j = 0; j < 256 && !condition_met; j = j + 1) begin
                    if (j < next_set_count && next_valid[j]) begin
                        if (((h * next_h_mult[j] >= a && w * next_w_mult[j] >= b) ||
                             (h * next_h_mult[j] >= b && w * next_w_mult[j] >= a))) begin
                            condition_met = 1'b1;
                            next_k = i + 5'd1;
                        end
                    end
                end
                if (condition_met) begin
                    next_state = STATE_DONE;
                end else begin
                    next_state = STATE_NEXT;
                end
            end

            STATE_NEXT: begin
                if (i >= 4'd7) begin
                    next_state = STATE_FAIL;
                end else begin
                    // Copy next set to current set
                    next_i = i + 4'd1;
                    next_ptr = 8'd0;
                    next_set_count = 8'd0;
                    next_valid = 256'd0;
                    // Move next set to current set
                    for (integer j = 0; j < 256; j = j + 1) begin
                        if (curr_valid[j]) begin
                            next_h_mult[j] = curr_h_mult[j];
                            next_w_mult[j] = curr_w_mult[j];
                            next_valid[j] = 1'b1;
                            next_set_count = next_set_count + 8'd1;
                        end else begin
                            next_h_mult[j] = 17'd0;
                            next_w_mult[j] = 17'd0;
                            next_valid[j] = 1'b0;
                        end
                    end
                    next_state = STATE_UPDATE;
                end
            end

            STATE_FAIL: begin
                next_k = 5'b11111;  // -1
                next_state = STATE_DONE;
            end

            STATE_DONE: begin
                next_done = 1'b1;
                if (!start) next_state = STATE_IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            i <= 4'd0;
            k <= 5'b11111;
            done <= 1'b0;
            ptr <= 8'd0;
            set_count <= 8'd0;
            curr_valid <= 256'd0;
            for (integer j = 0; j < 256; j = j + 1) begin
                curr_h_mult[j] <= 17'd0;
                curr_w_mult[j] <= 17'd0;
            end
        end else begin
            state <= next_state;
            i <= next_i;
            k <= next_k;
            done <= next_done;
            ptr <= next_ptr;
            set_count <= next_set_count;
            curr_valid <= next_valid;
            for (integer j = 0; j < 256; j = j + 1) begin
                curr_h_mult[j] <= next_h_mult[j];
                curr_w_mult[j] <= next_w_mult[j];
            end
        end
    end

endmodule