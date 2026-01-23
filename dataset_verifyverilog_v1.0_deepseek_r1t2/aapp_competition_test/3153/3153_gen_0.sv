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

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] SEARCH     = 3'd2;
    localparam [2:0] DECIDE     = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    localparam [2:0] UPDATE     = 3'd5;
    localparam [2:0] CHECK      = 3'd6;
    localparam [2:0] FINISHED   = 3'd7;
    
    reg [2:0] state, next_state;
    reg [DATA_WIDTH-1:0] current_counts [0:MAX_CHILDREN-1];
    reg [3:0] search_idx;
    reg [5:0] purchase_counter;
    
    wire [PAIR_WIDTH-1:0] curr_a, curr_b;
    wire [DATA_WIDTH-1:0] target_a, target_b, current_a, current_b;
    wire needs_a, needs_b;
    wire [DATA_WIDTH-1:0] needed_a, needed_b;
    wire all_targets_met;

    // Array element access
    assign curr_a = (search_idx < valid_pairs_count) ? pair_a[search_idx] : 4'd0;
    assign curr_b = (search_idx < valid_pairs_count) ? pair_b[search_idx] : 4'd0;
    
    // Child validation and target access
    assign target_a = (curr_a <= MAX_CHILDREN && curr_a != 0) ? target_counts[curr_a-1] : 4'd0;
    assign target_b = (curr_b <= MAX_CHILDREN && curr_b != 0) ? target_counts[curr_b-1] : 4'd0;
    assign current_a = (curr_a <= MAX_CHILDREN && curr_a != 0) ? current_counts[curr_a-1] : 4'd0;
    assign current_b = (curr_b <= MAX_CHILDREN && curr_b != 0) ? current_counts[curr_b-1] : 4'd0;
    
    assign needs_a = target_a > current_a;
    assign needs_b = target_b > current_b;
    assign needed_a = (target_a > current_a) ? (target_a - current_a) : 4'd0;
    assign needed_b = (target_b > current_b) ? (target_b - current_b) : 4'd0;
    
    // Target met check
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

    // FSM state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE:     next_state = start ? INIT : IDLE;
            INIT:     next_state = SEARCH;
            SEARCH:   next_state = (search_idx >= valid_pairs_count) ? FINISHED : 
                                  (needs_a || needs_b) ? DECIDE : SEARCH;
            DECIDE:   next_state = OUTPUT;
            OUTPUT:   next_state = UPDATE;
            UPDATE:   next_state = CHECK;
            CHECK:    next_state = (all_targets_met || (purchase_counter >= MAX_OUTPUT_PURCHASES-1)) ? FINISHED : SEARCH;
            FINISHED: next_state = FINISHED;
            default:  next_state = IDLE;
        endcase
    end

    // FSM output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_CHILDREN; i = i + 1) current_counts[i] <= 4'd0;
            search_idx <= 4'd0;
            purchase_counter <= 6'd0;
            out_child1 <= 4'd0;
            out_child2 <= 4'd0;
            out_outcome <= 2'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end
        else begin
            case (state)
                INIT: begin
                    for (i = 0; i < MAX_CHILDREN; i = i + 1) current_counts[i] <= 4'd0;
                    search_idx <= 4'd0;
                    purchase_counter <= 6'd0;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
                
                SEARCH: begin
                    out_valid <= 1'b0;
                    if (needs_a || needs_b) begin
                        // Hold search_idx for DECIDE state
                    end else if (search_idx < valid_pairs_count) begin
                        search_idx <= search_idx + 4'd1;
                    end
                end
                
                DECIDE: begin
                    out_child1 <= curr_a;
                    out_child2 <= curr_b;
                    if (needs_a && needs_b) begin
                        out_outcome <= 2'b01;  // Both get 1
                    end
                    else if (needs_a) begin
                        out_outcome <= (needed_a >= 2) ? 2'b10 : 2'b01;  // Child1 gets 2 or 1
                    end
                    else begin
                        out_outcome <= 2'b00;  // No assignment
                    end
                end
                
                OUTPUT: begin
                    out_valid <= 1'b1;
                end
                
                UPDATE: begin
                    out_valid <= 1'b0;
                    purchase_counter <= purchase_counter + 6'd1;
                    search_idx <= 4'd0;
                    
                    // Update counters
                    if (curr_a != 0 && curr_a <= MAX_CHILDREN) begin
                        current_counts[curr_a-1] <= current_counts[curr_a-1] + out_outcome;
                    end
                    if (curr_b != 0 && curr_b <= MAX_CHILDREN) begin
                        current_counts[curr_b-1] <= current_counts[curr_b-1] + (out_outcome[1] ? 2 : 0) - out_outcome;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule