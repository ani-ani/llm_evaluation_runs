module lamp_assigner (
    input clk,
    input rst_n,
    input start,
    input [3:0] k,
    input [31:0] packed_lamp_rows,
    input [31:0] packed_lamp_cols,
    output reg result,
    output reg done
);

// States
localparam [3:0] 
    IDLE        = 4'd0,
    PRECOMPUTE  = 4'd1,
    INIT_ASSIGN = 4'd2,
    CHECK_ASSIGN= 4'd3,
    VERIFY_ROWS = 4'd4,
    VERIFY_COLS = 4'd5,
    VALID_ASSIGN= 4'd6,
    FINISHED    = 4'd7;

// Constants
parameter GRID_SIZE = 3'd4;
parameter MAX_REACH = 2'd2;

// Storage
reg [1:0] lamp_rows [0:15];
reg [1:0] lamp_cols [0:15];
reg [1:0] row_intervals [0:15][0:1]; // [start, end]
reg [1:0] col_intervals [0:15][0:1];

// FSM Registers
reg [3:0] state;
reg [15:0] assignment;
reg [15:0] max_assignment;
reg [2:0] loop_counter;
reg [3:0] row_group_count [0:3];
reg [3:0] col_group_count [0:3];
reg [1:0] row_spans [0:3][0:15][0:1]; // [row][entry][start/end]
reg [1:0] col_spans [0:3][0:15][0:1]; // [col][entry][start/end]
reg overlap_flag;

integer i, j, m;

// Initialize all registers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        assignment <= 16'd0;
        overlap_flag <= 1'b0;
        
        // Clear all array elements
        for (i = 0; i < 16; i = i + 1) begin
            lamp_rows[i] <= 2'd0;
            lamp_cols[i] <= 2'd0;
            row_intervals[i][0] <= 2'd0;
            row_intervals[i][1] <= 2'd0;
            col_intervals[i][0] <= 2'd0;
            col_intervals[i][1] <= 2'd0;
        end
        
        for (i = 0; i < 4; i = i + 1) begin
            row_group_count[i] <= 4'd0;
            col_group_count[i] <= 4'd0;
            for (j = 0; j < 16; j = j + 1) begin
                row_spans[i][j][0] <= 2'd0;
                row_spans[i][j][1] <= 2'd0;
                col_spans[i][j][0] <= 2'd0;
                col_spans[i][j][1] <= 2'd0;
            end
        end
    end
    else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Unpack inputs
                    for (i = 0; i < 16; i = i + 1) begin
                        lamp_rows[i] <= packed_lamp_rows[2*i +: 2];
                        lamp_cols[i] <= packed_lamp_cols[2*i +: 2];
                    end
                    max_assignment <= (16'd1 << k) - 16'd1;
                    state <= PRECOMPUTE;
                end
            end
            
            PRECOMPUTE: begin
                for (i = 0; i < 16; i = i + 1) begin
                    // Precompute row intervals (col axis)
                    row_intervals[i][0] <= (lamp_cols[i] > MAX_REACH) ? lamp_cols[i] - MAX_REACH : 2'd0;
                    row_intervals[i][1] <= (lamp_cols[i] + MAX_REACH < GRID_SIZE-1) ? 
                                           lamp_cols[i] + MAX_REACH : GRID_SIZE-1;
                    
                    // Precompute column intervals (row axis)
                    col_intervals[i][0] <= (lamp_rows[i] > MAX_REACH) ? lamp_rows[i] - MAX_REACH : 2'd0;
                    col_intervals[i][1] <= (lamp_rows[i] + MAX_REACH < GRID_SIZE-1) ? 
                                           lamp_rows[i] + MAX_REACH : GRID_SIZE-1;
                end
                state <= INIT_ASSIGN;
            end
            
            INIT_ASSIGN: begin
                assignment <= 16'd0;
                overlap_flag <= 1'b0;
                state <= CHECK_ASSIGN;
            end
            
            CHECK_ASSIGN: begin
                // Reset grouping counters
                for (i = 0; i < 4; i = i + 1) begin
                    row_group_count[i] <= 4'd0;
                    col_group_count[i] <= 4'd0;
                end
                
                // Assign lamps to groups
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < k) begin
                        if (~assignment[i]) begin // Row mode
                            j = lamp_rows[i];
                            row_spans[j][row_group_count[j]][0] <= row_intervals[i][0];
                            row_spans[j][row_group_count[j]][1] <= row_intervals[i][1];
                            row_group_count[j] <= row_group_count[j] + 4'd1;
                        end
                        else begin // Column mode
                            j = lamp_cols[i];
                            col_spans[j][col_group_count[j]][0] <= col_intervals[i][0];
                            col_spans[j][col_group_count[j]][1] <= col_intervals[i][1];
                            col_group_count[j] <= col_group_count[j] + 4'd1;
                        end
                    end
                end
                state <= VERIFY_ROWS;
                loop_counter <= 3'd0;
            end
            
            VERIFY_ROWS: begin
                if (loop_counter < 3'd4) begin
                    for (i = 0; i < row_group_count[loop_counter]; i = i + 1) begin
                        for (j = i + 1; j < row_group_count[loop_counter]; j = j + 1) begin
                            if (~overlap_flag) begin
                                if (~((row_spans[loop_counter][i][1] < row_spans[loop_counter][j][0]) || 
                                      (row_spans[loop_counter][j][1] < row_spans[loop_counter][i][0]))) begin
                                    overlap_flag <= 1'b1;
                                end
                            end
                        end
                    end
                    loop_counter <= loop_counter + 3'd1;
                end
                else begin
                    state <= VERIFY_COLS;
                    loop_counter <= 3'd0;
                end
            end
            
            VERIFY_COLS: begin
                if (loop_counter < 3'd4) begin
                    for (i = 0; i < col_group_count[loop_counter]; i = i + 1) begin
                        for (j = i + 1; j < col_group_count[loop_counter]; j = j + 1) begin
                            if (~overlap_flag) begin
                                if (~((col_spans[loop_counter][i][1] < col_spans[loop_counter][j][0]) || 
                                      (col_spans[loop_counter][j][1] < col_spans[loop_counter][i][0]))) begin
                                    overlap_flag <= 1'b1;
                                end
                            end
                        end
                    end
                    loop_counter <= loop_counter + 3'd1;
                end
                else begin
                    if (overlap_flag) begin
                        if (assignment == max_assignment) begin
                            result <= 1'b0;
                            done <= 1'b1;
                            state <= FINISHED;
                        end
                        else begin
                            assignment <= assignment + 16'd1;
                            state <= CHECK_ASSIGN;
                        end
                    end
                    else begin
                        result <= 1'b1;
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end
            end
            
            FINISHED: begin
                // Maintain done signal until reset
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule