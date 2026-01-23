module find_min_T(
    input clk,
    input rst_n,
    input start,
    input [1:0] teacher [0:5],
    input [2:0] pref [0:5][0:4],
    output reg [3:0] T,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_MASKS = 3'd1;
    localparam [2:0] ENUMERATE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FOUND = 3'd4;
    localparam [2:0] INCREMENT_T = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state, next_state;
    reg [2:0] stored_teacher [0:5];
    reg [2:0] stored_pref [0:5][0:4];
    reg [5:0] mask [0:5];
    reg [1:0] assigned_teacher [0:5];
    reg [9:0] assignment_counter;
    reg [2:0] i, j, pos;
    reg [2:0] current_T;
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            T <= 4'd0;
            done <= 1'b0;
            current_T <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            pos <= 3'd0;
            assignment_counter <= 10'd0;
            for (integer k = 0; k < 6; k = k + 1) begin
                stored_teacher[k] <= 2'd0;
                for (integer m = 0; m < 5; m = m + 1) begin
                    stored_pref[k][m] <= 3'd0;
                end
            end
            for (integer k = 0; k < 6; k = k + 1) begin
                mask[k] <= 6'd0;
                assigned_teacher[k] <= 2'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    for (integer k = 0; k < 6; k = k + 1) begin
                        stored_teacher[k] = teacher[k];
                        for (integer m = 0; m < 5; m = m + 1) begin
                            stored_pref[k][m] = pref[k][m];
                        end
                    end
                    current_T = 3'd0;
                    next_state = COMPUTE_MASKS;
                end
            end

            COMPUTE_MASKS: begin
                if (i == 3'd5 && pos == current_T) begin
                    next_state = ENUMERATE;
                end else if (pos == current_T) begin
                    i = i + 3'd1;
                    pos = 3'd0;
                end else begin
                    mask[i][stored_pref[i][pos]] = 1'b1;
                    pos = pos + 3'd1;
                end
            end

            ENUMERATE: begin
                if (assignment_counter == 10'd728) begin
                    next_state = INCREMENT_T;
                end else begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                valid = 1'b1;
                for (integer k = 0; k < 6; k = k + 1) begin
                    if (assigned_teacher[k] == stored_teacher[k]) begin
                        valid = 1'b0;
                    end
                end
                for (integer k = 0; k < 6; k = k + 1) begin
                    for (integer m = k + 1; m < 6; m = m + 1) begin
                        if (assigned_teacher[k] == assigned_teacher[m]) begin
                            if (!mask[k][m] || !mask[m][k]) begin
                                valid = 1'b0;
                            end
                        end
                    end
                end
                if (valid) begin
                    next_state = FOUND;
                end else begin
                    assignment_counter = assignment_counter + 10'd1;
                    next_state = ENUMERATE;
                end
            end

            FOUND: begin
                T = current_T;
                done = 1'b1;
                next_state = DONE;
            end

            INCREMENT_T: begin
                if (current_T == 3'd5) begin
                    T = 4'd5;
                    done = 1'b1;
                    next_state = DONE;
                end else begin
                    current_T = current_T + 3'd1;
                    i = 3'd0;
                    pos = 3'd0;
                    assignment_counter = 10'd0;
                    for (integer k = 0; k < 6; k = k + 1) begin
                        mask[k] = 6'd0;
                        assigned_teacher[k] = 2'd0;
                    end
                    next_state = COMPUTE_MASKS;
                end
            end

            DONE: begin
                done = 1'b0;
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer k = 0; k < 6; k = k + 1) begin
                assigned_teacher[k] <= 2'd0;
            end
        end else if (state == ENUMERATE) begin
            integer carry = 1;
            for (integer k = 0; k < 6; k = k + 1) begin
                if (carry) begin
                    if (assigned_teacher[k] == 2'd2) begin
                        assigned_teacher[k] <= 2'd0;
                        carry = 1;
                    end else begin
                        assigned_teacher[k] <= assigned_teacher[k] + 2'd1;
                        carry = 0;
                    end
                end
            end
        end
    end

endmodule