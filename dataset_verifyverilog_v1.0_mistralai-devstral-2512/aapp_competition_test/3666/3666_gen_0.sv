module GearRatioSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] ratio_n [0:11],
    input wire [7:0] ratio_d [0:11],
    output reg [7:0] front0,
    output reg [7:0] front1,
    output reg [7:0] rear0,
    output reg [7:0] rear1,
    output reg [7:0] rear2,
    output reg [7:0] rear3,
    output reg [7:0] rear4,
    output reg [7:0] rear5,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH_FRONT = 3'd1;
    localparam [2:0] CHECK_RATIOS = 3'd2;
    localparam [2:0] VALIDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] current_front;
    reg [7:0] rear_candidates [0:11];
    reg [7:0] unique_rears [0:5];
    reg [7:0] front_candidates [0:1];
    reg [7:0] rear_count;
    reg [7:0] ratio_idx;
    reg [7:0] front_idx;
    reg [7:0] unique_idx;
    reg [7:0] temp_rear;
    reg [15:0] product;
    reg [7:0] remainder;
    reg [7:0] i, j, k;
    reg found_valid;
    reg [7:0] max_front;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_front <= 8'd0;
            ratio_idx <= 8'd0;
            front_idx <= 8'd0;
            unique_idx <= 8'd0;
            rear_count <= 8'd0;
            found_valid <= 1'b0;
            max_front <= 8'd100;
            front0 <= 8'd0;
            front1 <= 8'd0;
            rear0 <= 8'd0;
            rear1 <= 8'd0;
            rear2 <= 8'd0;
            rear3 <= 8'd0;
            rear4 <= 8'd0;
            rear5 <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 12; i = i + 1) begin
                rear_candidates[i] <= 8'd0;
            end
            for (i = 0; i < 6; i = i + 1) begin
                unique_rears[i] <= 8'd0;
            end
            for (i = 0; i < 2; i = i + 1) begin
                front_candidates[i] <= 8'd0;
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
                    next_state = SEARCH_FRONT;
                    current_front = 8'd1;
                    ratio_idx = 8'd0;
                    front_idx = 8'd0;
                    unique_idx = 8'd0;
                    rear_count = 8'd0;
                    found_valid = 1'b0;
                    for (i = 0; i < 12; i = i + 1) begin
                        rear_candidates[i] = 8'd0;
                    end
                    for (i = 0; i < 6; i = i + 1) begin
                        unique_rears[i] = 8'd0;
                    end
                    for (i = 0; i < 2; i = i + 1) begin
                        front_candidates[i] = 8'd0;
                    end
                end
            end

            SEARCH_FRONT: begin
                if (current_front > max_front) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_RATIOS;
                end
            end

            CHECK_RATIOS: begin
                if (ratio_idx < 8'd12) begin
                    next_state = CHECK_RATIOS;
                end else begin
                    next_state = VALIDATE;
                end
            end

            VALIDATE: begin
                next_state = SEARCH_FRONT;
                current_front = current_front + 8'd1;
                ratio_idx = 8'd0;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (state == CHECK_RATIOS) begin
            // Compute rear sprocket for current ratio
            product = current_front * ratio_d[ratio_idx];
            remainder = product % ratio_n[ratio_idx];
            if (remainder == 8'd0 && ratio_n[ratio_idx] != 8'd0) begin
                temp_rear = product / ratio_n[ratio_idx];
                if (temp_rear <= 8'd100) begin
                    rear_candidates[ratio_idx] = temp_rear;
                end else begin
                    rear_candidates[ratio_idx] = 8'd0;
                end
            end else begin
                rear_candidates[ratio_idx] = 8'd0;
            end
            ratio_idx = ratio_idx + 8'd1;
        end else if (state == VALIDATE) begin
            // Check if all rear_candidates are valid and unique
            rear_count = 8'd0;
            for (i = 0; i < 6; i = i + 1) begin
                unique_rears[i] = 8'd0;
            end

            // Collect unique rear sprockets
            for (i = 0; i < 12; i = i + 1) begin
                if (rear_candidates[i] != 8'd0) begin
                    found_valid = 1'b0;
                    for (j = 0; j < rear_count; j = j + 1) begin
                        if (unique_rears[j] == rear_candidates[i]) begin
                            found_valid = 1'b1;
                        end
                    end
                    if (!found_valid && rear_count < 6) begin
                        unique_rears[rear_count] = rear_candidates[i];
                        rear_count = rear_count + 8'd1;
                    end
                end
            end

            // Check if we have exactly 6 unique rears
            if (rear_count == 6) begin
                // Check if all ratios are covered
                found_valid = 1'b1;
                for (i = 0; i < 12; i = i + 1) begin
                    if (rear_candidates[i] == 8'd0) begin
                        found_valid = 1'b0;
                    end
                end

                if (found_valid && front_idx < 2) begin
                    front_candidates[front_idx] = current_front;
                    front_idx = front_idx + 8'd1;
                    if (front_idx == 2) begin
                        // Found valid solution
                        front0 = front_candidates[0];
                        front1 = front_candidates[1];
                        rear0 = unique_rears[0];
                        rear1 = unique_rears[1];
                        rear2 = unique_rears[2];
                        rear3 = unique_rears[3];
                        rear4 = unique_rears[4];
                        rear5 = unique_rears[5];
                        valid = 1'b1;
                        done = 1'b1;
                        next_state = IDLE;
                    end
                end
            end
        end
    end

    // Done signal handling
    always @(posedge clk) begin
        if (state == FINISH) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule