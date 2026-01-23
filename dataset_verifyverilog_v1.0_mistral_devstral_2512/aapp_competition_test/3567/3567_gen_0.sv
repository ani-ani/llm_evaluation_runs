module character_creation(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [K-1:0] str0,
    input [K-1:0] str1,
    input [K-1:0] str2,
    input [K-1:0] str3,
    input [K-1:0] str4,
    input [K-1:0] str5,
    input [K-1:0] str6,
    input [K-1:0] str7,
    output reg [K-1:0] result,
    output reg done
)(
    parameter K = 20,
    parameter N = 8
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] LOOP_INNER = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [K-1:0] current_candidate;
    reg [K-1:0] best_candidate;
    reg [K-1:0] min_dist;
    reg [K-1:0] current_dist;
    reg [K-1:0] temp_str;
    reg [3:0] i, j;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Popcount function
    function [7:0] popcount;
        input [K-1:0] x;
        integer k;
        begin
            popcount = 8'd0;
            for (k = 0; k < K; k = k + 1) begin
                popcount = popcount + x[k];
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= {K{1'b0}};
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_candidate <= {K{1'b0}};
            best_candidate <= {K{1'b0}};
            min_dist <= {K{1'b0}};
            current_dist <= {K{1'b0}};
            temp_str <= {K{1'b0}};
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
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
                if (i == n) begin
                    next_state = LOOP_INNER;
                    i <= 4'd0;
                end
            end

            LOOP_INNER: begin
                if (j == n) begin
                    if (min_dist > current_dist) begin
                        best_candidate = current_candidate;
                    end
                    if (current_candidate == {K{1'b1}}) begin
                        next_state = DONE_STATE;
                    else begin
                        current_candidate = current_candidate + 1'b1;
                        min_dist = {K{1'b1}};
                        j <= 4'd0;
                    end
                else begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                next_state = LOOP_INNER;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(*) begin
        case (state)
            INIT: begin
                if (i < n) begin
                    // Store input strings in array (using individual registers)
                    case (i)
                        4'd0: temp_str = str0;
                        4'd1: temp_str = str1;
                        4'd2: temp_str = str2;
                        4'd3: temp_str = str3;
                        4'd4: temp_str = str4;
                        4'd5: temp_str = str5;
                        4'd6: temp_str = str6;
                        4'd7: temp_str = str7;
                        default: temp_str = {K{1'b0}};
                    endcase
                    i = i + 1'b1;
                end
            end

            LOOP_INNER: begin
                if (j < n) begin
                    // Compute Hamming distance to current string
                    case (j)
                        4'd0: current_dist = popcount(current_candidate ^ str0);
                        4'd1: current_dist = popcount(current_candidate ^ str1);
                        4'd2: current_dist = popcount(current_candidate ^ str2);
                        4'd3: current_dist = popcount(current_candidate ^ str3);
                        4'd4: current_dist = popcount(current_candidate ^ str4);
                        4'd5: current_dist = popcount(current_candidate ^ str5);
                        4'd6: current_dist = popcount(current_candidate ^ str6);
                        4'd7: current_dist = popcount(current_candidate ^ str7);
                        default: current_dist = {K{1'b0}};
                    endcase
                    j = j + 1'b1;
                    if (current_dist < min_dist) begin
                        min_dist = current_dist;
                    end
                end
            end

            DONE_STATE: begin
                result = best_candidate;
                done = 1'b1;
            end

            default: begin
                result = {K{1'b0}};
                done = 1'b0;
            end
        endcase
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
            result <= best_candidate;
        end
    end

endmodule