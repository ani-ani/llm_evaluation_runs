module frog_tower(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] frog_pos [0:7],
    input wire [4:0] frog_dist [0:7],
    input wire [3:0] num_frogs,
    output reg [15:0] result_pos,
    output reg [3:0] result_size,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] CHECK_LIMIT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [9:0] pos;  // Position counter (0 to 511)
    reg [3:0] current_count;  // Count of frogs that can reach current pos
    reg [3:0] max_count;  // Maximum count found
    reg [15:0] best_pos;  // Position with maximum count
    reg [3:0] frog_index;  // Index for frog iteration
    reg [3:0] valid_frogs;  // Number of valid frogs for current pos

    // Maximum position limit
    localparam [9:0] MAX_POS = 10'd511;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 10'd0;
            current_count <= 4'd0;
            max_count <= 4'd0;
            best_pos <= 16'd0;
            frog_index <= 4'd0;
            valid_frogs <= 4'd0;
            result_pos <= 16'd0;
            result_size <= 4'd0;
            done <= 1'b0;
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
                    next_state = SCAN;
                end
            end
            SCAN: begin
                if (frog_index == num_frogs - 1) begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                next_state = CHECK_LIMIT;
            end
            CHECK_LIMIT: begin
                if (pos == MAX_POS) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SCAN;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Position counter and frog index logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos <= 10'd0;
            frog_index <= 4'd0;
            valid_frogs <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    pos <= 10'd0;
                    frog_index <= 4'd0;
                    valid_frogs <= 4'd0;
                end
                SCAN: begin
                    if (frog_index == num_frogs - 1) begin
                        frog_index <= 4'd0;
                    end else begin
                        frog_index <= frog_index + 4'd1;
                    end
                end
                COMPARE: begin
                    pos <= pos + 10'd1;
                    frog_index <= 4'd0;
                    valid_frogs <= 4'd0;
                end
                CHECK_LIMIT: begin
                    // No change
                end
                DONE_STATE: begin
                    // No change
                end
                default: begin
                    pos <= 10'd0;
                    frog_index <= 4'd0;
                    valid_frogs <= 4'd0;
                end
            endcase
        end
    end

    // Frog validation logic
    always @(*) begin
        case (state)
            SCAN: begin
                if (frog_index < num_frogs) begin
                    // Check if frog can reach current pos
                    if (pos >= frog_pos[frog_index] && 
                        (pos - frog_pos[frog_index]) % frog_dist[frog_index] == 0) begin
                        current_count = valid_frogs + 4'd1;
                    end else begin
                        current_count = valid_frogs;
                    end
                end else begin
                    current_count = valid_frogs;
                end
            end
            default: current_count = 4'd0;
        endcase
    end

    // Update valid frogs count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_frogs <= 4'd0;
        end else begin
            case (state)
                SCAN: begin
                    if (frog_index == num_frogs - 1) begin
                        valid_frogs <= current_count;
                    end else begin
                        valid_frogs <= current_count;
                    end
                end
                default: valid_frogs <= 4'd0;
            endcase
        end
    end

    // Compare logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_count <= 4'd0;
            best_pos <= 16'd0;
        end else begin
            case (state)
                COMPARE: begin
                    if (valid_frogs > max_count) begin
                        max_count <= valid_frogs;
                        best_pos <= pos;
                    end else if (valid_frogs == max_count && pos < best_pos) begin
                        best_pos <= pos;
                    end
                end
                default: begin
                    max_count <= max_count;
                    best_pos <= best_pos;
                end
            endcase
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_pos <= 16'd0;
            result_size <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                DONE_STATE: begin
                    result_pos <= best_pos;
                    result_size <= max_count;
                    done <= 1'b1;
                end
                default: begin
                    result_pos <= 16'd0;
                    result_size <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule