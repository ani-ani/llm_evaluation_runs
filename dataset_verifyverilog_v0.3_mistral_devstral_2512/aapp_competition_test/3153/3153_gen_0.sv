module card_purchase_solver #(
    parameter MAX_CHILDREN = 8,
    parameter MAX_PURCHASES = 16,
    parameter MAX_OUTPUT_PURCHASES = 32,
    parameter DATA_WIDTH = 4,
    parameter PAIR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] target_counts [0:MAX_CHILDREN-1],
    input wire [PAIR_WIDTH-1:0] pair_a [0:MAX_PURCHASES-1],
    input wire [PAIR_WIDTH-1:0] pair_b [0:MAX_PURCHASES-1],
    input wire [3:0] valid_pairs_count,
    output reg [PAIR_WIDTH-1:0] out_child1,
    output reg [PAIR_WIDTH-1:0] out_child2,
    output reg [1:0] out_outcome,
    output reg out_valid,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] DECIDE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] UPDATE = 3'd5;
    localparam [2:0] CHECK = 3'd6;
    localparam [2:0] FINISHED = 3'd7;

    reg [2:0] state, next_state;
    reg [DATA_WIDTH-1:0] current_counts [0:MAX_CHILDREN-1];
    reg [3:0] search_idx;
    reg [5:0] purchase_counter;
    
    wire [PAIR_WIDTH-1:0] curr_a, curr_b;
    wire [DATA_WIDTH-1:0] target_a, target_b, current_a, current_b;
    wire needs_a, needs_b;
    wire [DATA_WIDTH-1:0] needed_a, needed_b;
    wire all_targets_met;

    assign curr_a = (search_idx < valid_pairs_count) ? pair_a[search_idx] : 4'd0;
    assign curr_b = (search_idx < valid_pairs_count) ? pair_b[search_idx] : 4'd0;
    assign target_a = (curr_a > 4'd0 && curr_a <= MAX_CHILDREN) ? target_counts[curr_a-1] : 4'd0;
    assign target_b = (curr_b > 4'd0 && curr_b <= MAX_CHILDREN) ? target_counts[curr_b-1] : 4'd0;
    assign current_a = (curr_a > 4'd0 && curr_a <= MAX_CHILDREN) ? current_counts[curr_a-1] : 4'd0;
    assign current_b = (curr_b > 4'd0 && curr_b <= MAX_CHILDREN) ? current_counts[curr_b-1] : 4'd0;
    assign needs_a = (current_a < target_a);
    assign needs_b = (current_b < target_b);
    assign needed_a = target_a - current_a;
    assign needed_b = target_b - current_b;

    integer i;
    reg met;
    always @(*) begin
        met = 1'b1;
        for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
            if (current_counts[i] != target_counts[i]) begin
                met = 1'b0;
            end
        end
    end
    assign all_targets_met = met;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            out_valid <= 1'b0;
            done <= 1'b0;
            purchase_counter <= 6'd0;
            search_idx <= 4'd0;
            out_child1 <= 4'd0;
            out_child2 <= 4'd0;
            out_outcome <= 2'd0;
            for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                current_counts[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = SEARCH;
            SEARCH: begin
                if (search_idx >= valid_pairs_count) begin
                    next_state = FINISHED;
                end else if (needs_a || needs_b) begin
                    next_state = DECIDE;
                end else begin
                    next_state = SEARCH;
                end
            end
            DECIDE: next_state = OUTPUT;
            OUTPUT: next_state = UPDATE;
            UPDATE: next_state = CHECK;
            CHECK: begin
                if (all_targets_met || purchase_counter >= MAX_OUTPUT_PURCHASES-1) begin
                    next_state = FINISHED;
                end else begin
                    next_state = SEARCH;
                end
            end
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            done <= 1'b0;
            purchase_counter <= 6'd0;
            search_idx <= 4'd0;
            out_child1 <= 4'd0;
            out_child2 <= 4'd0;
            out_outcome <= 2'd0;
            for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                current_counts[i] <= 4'd0;
            end
        end else begin
            case (state)
                INIT: begin
                    for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                        current_counts[i] <= 4'd0;
                    end
                    search_idx <= 4'd0;
                    purchase_counter <= 6'd0;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
                SEARCH: begin
                    if (!(needs_a || needs_b) && search_idx < valid_pairs_count) begin
                        search_idx <= search_idx + 4'd1;
                    end
                    out_valid <= 1'b0;
                end
                DECIDE: begin
                    out_child1 <= curr_a;
                    out_child2 <= curr_b;
                    if (needs_a && needs_b) begin
                        out_outcome <= 2'd1;
                    end else if (needs_a && !needs_b) begin
                        out_outcome <= (needed_a >= 2) ? 2'd2 : 2'd1;
                    end else if (!needs_a && needs_b) begin
                        out_outcome <= 2'd0;
                    end else begin
                        out_outcome <= 2'd0;
                    end
                end
                OUTPUT: out_valid <= 1'b1;
                UPDATE: begin
                    if (curr_a > 4'd0 && curr_a <= MAX_CHILDREN) begin
                        current_counts[curr_a-1] <= current_counts[curr_a-1] + out_outcome;
                    end
                    if (curr_b > 4'd0 && curr_b <= MAX_CHILDREN) begin
                        current_counts[curr_b-1] <= current_counts[curr_b-1] + (2'd2 - out_outcome);
                    end
                    purchase_counter <= purchase_counter + 6'd1;
                    search_idx <= 4'd0;
                    out_valid <= 1'b0;
                end
                FINISHED: done <= 1'b1;
            endcase
        end
    end
endmodule