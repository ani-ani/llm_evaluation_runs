module ParityReconstruction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] row_parity,
    input wire [15:0] col_parity,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg [255:0] matrix_out,
    output reg valid,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] ROW_PROC  = 3'd2;
    localparam [2:0] COL_PROC  = 3'd3;
    localparam [2:0] VALIDATE  = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Counter variables
    reg [3:0] i;  // row counter
    reg [3:0] j;  // column counter
    reg [3:0] bit_pos;
    
    // Temporary storage for computation
    reg [15:0] temp_row_parity;
    reg [15:0] temp_col_parity;
    reg [15:0] computed_col_parity;
    reg [15:0] computed_row_parity;
    
    // Validity flags
    reg parity_valid;
    
    // Cycle counter for timeout prevention
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    // FSM State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            matrix_out <= 256'd0;
            valid <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            bit_pos <= 4'd0;
            temp_row_parity <= 16'd0;
            temp_col_parity <= 16'd0;
            computed_col_parity <= 16'd0;
            computed_row_parity <= 16'd0;
            parity_valid <= 1'b0;
            cycle_count <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 9'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    if (start) begin
                        state <= INIT;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Initialize matrix to all zeros
                    matrix_out <= 256'd0;
                    temp_row_parity <= row_parity;
                    temp_col_parity <= col_parity;
                    computed_col_parity <= 16'd0;
                    computed_row_parity <= 16'd0;
                    parity_valid <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    bit_pos <= 4'd0;
                    state <= ROW_PROC;
                end
                
                ROW_PROC: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Process each row
                    if (i < n) begin
                        // Check if row needs parity bit (row_parity[i] == 1)
                        if (temp_row_parity[i]) begin
                            // Set the last column bit to 1
                            // Calculate bit position: for row i, col (m-1)
                            // Bit position = (15-i)*16 + 15
                            // But we need to map to 16x16 grid
                            bit_pos <= (15 - i) * 4'd16 + (m - 4'd1);
                        end
                        i <= i + 4'd1;
                        if (i == n - 4'd1) begin
                            state <= COL_PROC;
                            i <= 4'd0;
                        end
                    end else begin
                        state <= COL_PROC;
                        i <= 4'd0;
                    end
                end
                
                COL_PROC: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Process each column
                    if (j < m) begin
                        // Calculate current column parity
                        // For column j, check all rows i < n
                        if (i < n) begin
                            // Check bit at position (15-i)*16 + j
                            // Use a combination of shift and mask
                            if (matrix_out[(15 - i) * 16 + j]) begin
                                computed_col_parity[j] <= ~computed_col_parity[j];
                            end
                            i <= i + 4'd1;
                        end else begin
                            // Done checking all rows for this column
                            // Check if parity matches
                            if (computed_col_parity[j] != temp_col_parity[j]) begin
                                // Set last row bit to 1 for this column
                                // Bit position = (15-(n-1))*16 + j = (16-n)*16 + j
                                bit_pos <= (16 - n) * 4'd16 + j;
                            end
                            computed_col_parity[j] <= 1'b0;
                            j <= j + 4'd1;
                            i <= 4'd0;
                        end
                        if (j == m - 4'd1 && i == n) begin
                            state <= VALIDATE;
                            j <= 4'd0;
                            i <= 4'd0;
                        end
                    end else begin
                        state <= VALIDATE;
                        j <= 4'd0;
                        i <= 4'd0;
                    end
                end
                
                VALIDATE: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Validate row parities
                    if (i < n) begin
                        // Calculate row i parity
                        // Check bits in row i
                        if (j < m) begin
                            if (matrix_out[(15 - i) * 16 + j]) begin
                                computed_row_parity[i] <= ~computed_row_parity[i];
                            end
                            j <= j + 4'd1;
                        end else begin
                            if (computed_row_parity[i] != temp_row_parity[i]) begin
                                parity_valid <= 1'b0;
                            end else if (i == 4'd0) begin
                                parity_valid <= 1'b1;
                            end
                            computed_row_parity[i] <= 1'b0;
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end
                    end else begin
                        // Validate column parities
                        if (j < m) begin
                            // Calculate column j parity
                            if (i < n) begin
                                if (matrix_out[(15 - i) * 16 + j]) begin
                                    computed_col_parity[j] <= ~computed_col_parity[j];
                                end
                                i <= i + 4'd1;
                            end else begin
                                if (computed_col_parity[j] != temp_col_parity[j]) begin
                                    parity_valid <= 1'b0;
                                end else if (j == 4'd0 && !parity_valid) begin
                                    parity_valid <= 1'b1;
                                end
                                computed_col_parity[j] <= 1'b0;
                                j <= j + 4'd1;
                                i <= 4'd0;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (parity_valid) begin
                        valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        valid <= 1'b0;
                        impossible <= 1'b1;
                        matrix_out <= 256'd0;
                    end
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                end
            endcase
        end
    end

endmodule