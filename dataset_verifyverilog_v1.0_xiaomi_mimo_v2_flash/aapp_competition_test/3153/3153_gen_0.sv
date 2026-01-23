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

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] SEARCH = 4'd2;
    localparam [3:0] DECIDE = 4'd3;
    localparam [3:0] OUTPUT = 4'd4;
    localparam [3:0] UPDATE = 4'd5;
    localparam [3:0] CHECK = 4'd6;
    localparam [3:0] FINISHED = 4'd7;

    reg [3:0] state, next_state;
    reg [DATA_WIDTH-1:0] current_counts [0:MAX_CHILDREN-1];
    reg [3:0] search_idx;
    reg [5:0] purchase_counter;
    reg [3:0] i;
    reg found_pair;
    
    // Intermediate signals
    reg [PAIR_WIDTH-1:0] curr_a_reg;
    reg [PAIR_WIDTH-1:0] curr_b_reg;
    reg [DATA_WIDTH-1:0] target_a_reg;
    reg [DATA_WIDTH-1:0] target_b_reg;
    reg [DATA_WIDTH-1:0] current_a_reg;
    reg [DATA_WIDTH-1:0] current_b_reg;
    reg needs_a_reg;
    reg needs_b_reg;
    reg [DATA_WIDTH-1:0] needed_a_reg;
    reg [DATA_WIDTH-1:0] needed_b_reg;
    reg all_targets_met_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_valid <= 1'b0;
            done <= 1'b0;
            purchase_counter <= 6'd0;
            search_idx <= 4'd0;
            out_child1 <= {PAIR_WIDTH{1'b0}};
            out_child2 <= {PAIR_WIDTH{1'b0}};
            out_outcome <= 2'd0;
            for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                current_counts[i] <= {DATA_WIDTH{1'b0}};
            end
            curr_a_reg <= {PAIR_WIDTH{1'b0}};
            curr_b_reg <= {PAIR_WIDTH{1'b0}};
            target_a_reg <= {DATA_WIDTH{1'b0}};
            target_b_reg <= {DATA_WIDTH{1'b0}};
            current_a_reg <= {DATA_WIDTH{1'b0}};
            current_b_reg <= {DATA_WIDTH{1'b0}};
            needs_a_reg <= 1'b0;
            needs_b_reg <= 1'b0;
            needed_a_reg <= {DATA_WIDTH{1'b0}};
            needed_b_reg <= {DATA_WIDTH{1'b0}};
            all_targets_met_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
                INIT: begin
                    for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                        current_counts[i] <= target_counts[i];
                    end
                    search_idx <= 4'd0;
                    purchase_counter <= 6'd0;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
                SEARCH: begin
                    out_valid <= 1'b0;
                    if (search_idx < valid_pairs_count) begin
                        curr_a_reg <= pair_a[search_idx];
                        curr_b_reg <= pair_b[search_idx];
                        
                        if (pair_a[search_idx] <= MAX_CHILDREN && pair_a[search_idx] != 4'd0) begin
                            target_a_reg <= target_counts[pair_a[search_idx] - 1];
                            current_a_reg <= current_counts[pair_a[search_idx] - 1];
                        end else begin
                            target_a_reg <= {DATA_WIDTH{1'b0}};
                            current_a_reg <= {DATA_WIDTH{1'b0}};
                        end
                        
                        if (pair_b[search_idx] <= MAX_CHILDREN && pair_b[search_idx] != 4'd0) begin
                            target_b_reg <= target_counts[pair_b[search_idx] - 1];
                            current_b_reg <= current_counts[pair_b[search_idx] - 1];
                        end else begin
                            target_b_reg <= {DATA_WIDTH{1'b0}};
                            current_b_reg <= {DATA_WIDTH{1'b0}};
                        end
                    end
                end
                DECIDE: begin
                    needs_a_reg <= (current_a_reg < target_a_reg);
                    needs_b_reg <= (current_b_reg < target_b_reg);
                    needed_a_reg <= target_a_reg - current_a_reg;
                    needed_b_reg <= target_b_reg - current_b_reg;
                end
                OUTPUT: begin
                    out_child1 <= curr_a_reg;
                    out_child2 <= curr_b_reg;
                    if (needs_a_reg && needs_b_reg) begin
                        out_outcome <= 2'd1;
                    end else if (needs_a_reg && !needs_b_reg) begin
                        if (needed_a_reg >= 2'd2) begin
                            out_outcome <= 2'd2;
                        end else begin
                            out_outcome <= 2'd1;
                        end
                    end else if (!needs_a_reg && needs_b_reg) begin
                        out_outcome <= 2'd0;
                    end else begin
                        out_outcome <= 2'd0;
                    end
                    out_valid <= 1'b1;
                end
                UPDATE: begin
                    out_valid <= 1'b0;
                    if (curr_a_reg != 4'd0 && curr_a_reg <= MAX_CHILDREN) begin
                        if (curr_a_reg == 4'd1) current_counts[0] <= current_counts[0] + out_outcome;
                        else if (curr_a_reg == 4'd2) current_counts[1] <= current_counts[1] + out_outcome;
                        else if (curr_a_reg == 4'd3) current_counts[2] <= current_counts[2] + out_outcome;
                        else if (curr_a_reg == 4'd4) current_counts[3] <= current_counts[3] + out_outcome;
                        else if (curr_a_reg == 4'd5) current_counts[4] <= current_counts[4] + out_outcome;
                        else if (curr_a_reg == 4'd6) current_counts[5] <= current_counts[5] + out_outcome;
                        else if (curr_a_reg == 4'd7) current_counts[6] <= current_counts[6] + out_outcome;
                        else if (curr_a_reg == 4'd8) current_counts[7] <= current_counts[7] + out_outcome;
                    end
                    if (curr_b_reg != 4'd0 && curr_b_reg <= MAX_CHILDREN) begin
                        reg [DATA_WIDTH-1:0] delta_b;
                        delta_b = 2'd2 - out_outcome;
                        if (curr_b_reg == 4'd1) current_counts[0] <= current_counts[0] + delta_b;
                        else if (curr_b_reg == 4'd2) current_counts[1] <= current_counts[1] + delta_b;
                        else if (curr_b_reg == 4'd3) current_counts[2] <= current_counts[2] + delta_b;
                        else if (curr_b_reg == 4'd4) current_counts[3] <= current_counts[3] + delta_b;
                        else if (curr_b_reg == 4'd5) current_counts[4] <= current_counts[4] + delta_b;
                        else if (curr_b_reg == 4'd6) current_counts[5] <= current_counts[5] + delta_b;
                        else if (curr_b_reg == 4'd7) current_counts[6] <= current_counts[6] + delta_b;
                        else if (curr_b_reg == 4'd8) current_counts[7] <= current_counts[7] + delta_b;
                    end
                    purchase_counter <= purchase_counter + 6'd1;
                    search_idx <= 4'd0;
                end
                CHECK: begin
                    all_targets_met_reg <= 1'b1;
                    for (i = 0; i < MAX_CHILDREN; i = i + 1) begin
                        if (current_counts[i] != {DATA_WIDTH{1'b0}}) begin
                            all_targets_met_reg <= 1'b0;
                        end
                    end
                end
                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: next_state = SEARCH;
            SEARCH: begin
                if (search_idx >= valid_pairs_count) begin
                    next_state = FINISHED;
                end else begin
                    if (needs_a_reg || needs_b_reg) begin
                        next_state = DECIDE;
                    end else begin
                        next_state = SEARCH;
                    end
                end
            end
            DECIDE: next_state = OUTPUT;
            OUTPUT: next_state = UPDATE;
            UPDATE: next_state = CHECK;
            CHECK: begin
                if (all_targets_met_reg) begin
                    next_state = FINISHED;
                end else if (purchase_counter >= MAX_OUTPUT_PURCHASES - 1) begin
                    next_state = FINISHED;
                end else begin
                    next_state = SEARCH;
                end
            end
            FINISHED: begin
                if (start) next_state = INIT;
                else next_state = FINISHED;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule