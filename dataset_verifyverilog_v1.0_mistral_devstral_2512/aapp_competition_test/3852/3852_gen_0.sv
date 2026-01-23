module non_decreasing_array #(
    parameter DATA_WIDTH = 24,
    parameter MAX_N = 50,
    parameter INDEX_WIDTH = 6
) (
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [DATA_WIDTH*MAX_N-1:0] array_in,
    output reg count_valid,
    output reg [7:0] count,
    output reg op_valid,
    output reg [INDEX_WIDTH-1:0] op_x,
    output reg [INDEX_WIDTH-1:0] op_y,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] FIND_MAX_MIN = 3'd1;
localparam [2:0] DECIDE = 3'd2;
localparam [2:0] OUTPUT_COUNT = 3'd3;
localparam [2:0] FIX = 3'd4;
localparam [2:0] PREFIX = 3'd5;
localparam [2:0] SUFFIX = 3'd6;
localparam [2:0] DONE_STATE = 3'd7;

reg [2:0] state, next_state;
reg [DATA_WIDTH-1:0] array_reg [0:MAX_N-1];
reg [DATA_WIDTH-1:0] max_val, min_val;
reg [INDEX_WIDTH-1:0] max_index, min_index;
reg [6:0] neg_count, pos_count;
reg [6:0] total_count;
reg [1:0] strategy;
reg [INDEX_WIDTH-1:0] i;

// State transition logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = FIND_MAX_MIN;
            else
                next_state = IDLE;
        end
        
        FIND_MAX_MIN: begin
            if (i == N)
                next_state = DECIDE;
            else
                next_state = FIND_MAX_MIN;
        end
        
        DECIDE: next_state = OUTPUT_COUNT;
        
        OUTPUT_COUNT: begin
            case (strategy)
                2'd0: next_state = PREFIX;
                2'd1: next_state = SUFFIX;
                2'd2, 2'd3: next_state = FIX;
                default: next_state = DONE_STATE;
            endcase
        end
        
        FIX: begin
            if (i == N)
                next_state = (strategy == 2'd2) ? PREFIX : SUFFIX;
            else
                next_state = FIX;
        end
        
        PREFIX: begin
            if (i == N-1)
                next_state = DONE_STATE;
            else
                next_state = PREFIX;
        end
        
        SUFFIX: begin
            if (i == N-1)
                next_state = DONE_STATE;
            else
                next_state = SUFFIX;
        end
        
        DONE_STATE: next_state = IDLE;
        
        default: next_state = IDLE;
    endcase
end

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count_valid <= 1'b0;
        count <= 8'd0;
        op_valid <= 1'b0;
        done <= 1'b0;
        i <= 6'd0;
        
        // Initialize array
        integer j;
        for (j = 0; j < MAX_N; j = j + 1) begin
            array_reg[j] <= {DATA_WIDTH{1'b0}};
        end
        
        max_val <= {1'b0, {DATA_WIDTH-1{1'b1}}};
        min_val <= {1'b1, {DATA_WIDTH-1{1'b0}}};
        max_index <= 6'd0;
        min_index <= 6'd0;
        neg_count <= 7'd0;
        pos_count <= 7'd0;
        total_count <= 7'd0;
        strategy <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                count_valid <= 1'b0;
                op_valid <= 1'b0;
            end
            
            FIND_MAX_MIN: begin
                if (i == 0) begin
                    // Load array
                    integer j;
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        array_reg[j] <= array_in[DATA_WIDTH*j +: DATA_WIDTH];
                    end
                    
                    if (N > 0) begin
                        max_val <= array_reg[0];
                        min_val <= array_reg[0];
                        if (array_reg[0][DATA_WIDTH-1])
                            neg_count <= 1;
                        else if (array_reg[0] != 0)
                            pos_count <= 1;
                    end
                    i <= 1;
                end else if (i < N) begin
                    // Update max/min
                    if (array_reg[i] > max_val) begin
                        max_val <= array_reg[i];
                        max_index <= i;
                    end
                    if (array_reg[i] < min_val) begin
                        min_val <= array_reg[i];
                        min_index <= i;
                    end
                    
                    // Count negative/positive
                    if (array_reg[i][DATA_WIDTH-1])
                        neg_count <= neg_count + 1;
                    else if (array_reg[i] != 0)
                        pos_count <= pos_count + 1;
                    
                    i <= i + 1;
                end
            end
            
            DECIDE: begin
                if (min_val[DATA_WIDTH-1]) begin
                    if (max_val[DATA_WIDTH-1]) begin
                        // All negative
                        strategy <= 2'd1;
                        total_count <= N - 1;
                    end else if (max_val >= -min_val) begin
                        // Strategy 2: flip negatives
                        strategy <= 2'd2;
                        total_count <= neg_count + (N - 1);
                    end else begin
                        // Strategy 3: flip positives
                        strategy <= 2'd3;
                        total_count <= pos_count + (N - 1);
                    end
                end else begin
                    // All non-negative
                    strategy <= 2'd0;
                    total_count <= N - 1;
                end
            end
            
            OUTPUT_COUNT: begin
                count_valid <= 1'b1;
                count <= total_count;
                i <= 0;
            end
            
            FIX: begin
                count_valid <= 1'b0;
                if (i < N) begin
                    if ((strategy == 2'd2 && array_reg[i][DATA_WIDTH-1]) || 
                        (strategy == 2'd3 && !array_reg[i][DATA_WIDTH-1] && array_reg[i] != 0)) begin
                        op_valid <= 1'b1;
                        if (strategy == 2'd2) begin
                            op_x <= max_index + 1;
                            op_y <= i + 1;
                        end else begin
                            op_x <= min_index + 1;
                            op_y <= i + 1;
                        end
                    end else begin
                        op_valid <= 1'b0;
                    end
                    i <= i + 1;
                end else begin
                    op_valid <= 1'b0;
                    i <= 0;
                end
            end
            
            PREFIX: begin
                count_valid <= 1'b0;
                op_valid <= 1'b1;
                op_x <= i + 1;
                op_y <= i + 2;
                i <= i + 1;
            end
            
            SUFFIX: begin
                count_valid <= 1'b0;
                op_valid <= 1'b1;
                op_x <= (N - 1 - i) + 1;
                op_y <= (N - 1 - i);
                i <= i + 1;
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                count_valid <= 1'b0;
                op_valid <= 1'b0;
            end
            
            default: begin
                count_valid <= 1'b0;
                op_valid <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule