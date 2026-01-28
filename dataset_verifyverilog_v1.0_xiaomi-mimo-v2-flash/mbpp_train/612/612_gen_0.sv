module MatrixTranspose (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7][0:7],
    input [3:0] num_rows,
    input [3:0] num_cols,
    output reg [63:0] transposed_0,
    output reg [63:0] transposed_1,
    output reg [63:0] transposed_2,
    output reg [63:0] transposed_3,
    output reg [63:0] transposed_4,
    output reg [63:0] transposed_5,
    output reg [63:0] transposed_6,
    output reg [63:0] transposed_7,
    output reg valid,
    output reg [3:0] num_transposed_cols
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CAPTURE    = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] FINISH     = 3'd3;

    // Registers for state
    reg [2:0] state, next_state;
    
    // Memory to store input (8x8 array)
    reg [7:0] input_store [0:7][0:7];
    
    // Control registers
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] src_row;
    reg [3:0] src_col;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;
    
    // Temporary registers for building output rows
    reg [63:0] temp_row;
    
    // Integer for loops
    integer i, j;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            valid <= 1'b0;
            num_transposed_cols <= 4'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            src_row <= 4'd0;
            src_col <= 4'd0;
            cycle_count <= 6'd0;
            temp_row <= 64'd0;
            transposed_0 <= 64'd0;
            transposed_1 <= 64'd0;
            transposed_2 <= 64'd0;
            transposed_3 <= 64'd0;
            transposed_4 <= 64'd0;
            transposed_5 <= 64'd0;
            transposed_6 <= 64'd0;
            transposed_7 <= 64'd0;
            // Clear input storage
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    input_store[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    row_idx <= 4'd0;
                    col_idx <= 4'd0;
                    src_row <= 4'd0;
                    src_col <= 4'd0;
                    cycle_count <= 6'd0;
                    temp_row <= 64'd0;
                end
                
                CAPTURE: begin
                    // Store input array into internal memory
                    if (src_row < num_rows && src_col < num_cols) begin
                        input_store[src_row][src_col] <= arr[src_row][src_col];
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Build output row `row_idx` by reading column `row_idx` from input
                    // Each iteration adds one source row to the packed output
                    // col_idx tracks which element position we're building (0 to num_rows-1)
                    
                    if (col_idx < num_rows) begin
                        // Read input_store[col_idx][row_idx] and append to temp_row
                        // Shift existing temp_row left by 8 bits and add new element to LSB
                        temp_row <= {temp_row[55:0], input_store[col_idx][row_idx]};
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        // Finished building this row
                        col_idx <= 4'd0;
                        
                        // Assign to appropriate output
                        case (row_idx)
                            4'd0: transposed_0 <= temp_row;
                            4'd1: transposed_1 <= temp_row;
                            4'd2: transposed_2 <= temp_row;
                            4'd3: transposed_3 <= temp_row;
                            4'd4: transposed_4 <= temp_row;
                            4'd5: transposed_5 <= temp_row;
                            4'd6: transposed_6 <= temp_row;
                            4'd7: transposed_7 <= temp_row;
                            default: begin
                                transposed_0 <= transposed_0;
                                transposed_1 <= transposed_1;
                                transposed_2 <= transposed_2;
                                transposed_3 <= transposed_3;
                                transposed_4 <= transposed_4;
                                transposed_5 <= transposed_5;
                                transposed_6 <= transposed_6;
                                transposed_7 <= transposed_7;
                            end
                        endcase
                        
                        // Reset temp_row for next row build
                        temp_row <= 64'd0;
                        row_idx <= row_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    valid <= 1'b1;
                    num_transposed_cols <= num_cols;
                end
                
                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPTURE;
                end
            end
            
            CAPTURE: begin
                // Capture all input data
                if (src_row >= num_rows - 1 && src_col >= num_cols - 1) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Compute until all output rows are built
                // Output has num_cols rows (each output row is a column from input)
                if (row_idx >= num_cols && col_idx == 4'd0) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Address update logic for CAPTURE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_row <= 4'd0;
            src_col <= 4'd0;
        end else begin
            if (state == CAPTURE) begin
                if (src_col < num_cols - 1) begin
                    src_col <= src_col + 4'd1;
                end else begin
                    src_col <= 4'd0;
                    if (src_row < num_rows - 1) begin
                        src_row <= src_row + 4'd1;
                    end
                end
            end else if (state == IDLE && start) begin
                src_row <= 4'd0;
                src_col <= 4'd0;
            end
        end
    end

endmodule