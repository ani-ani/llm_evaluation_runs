module matrix_transpose(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] [0:7] input_buffer;
    reg [3:0] row_count;
    reg [3:0] col_count;
    reg [3:0] output_row;
    reg [63:0] current_row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            row_count <= 4'd0;
            col_count <= 4'd0;
            output_row <= 4'd0;
            current_row <= 64'd0;
            valid <= 1'b0;
            num_transposed_cols <= 4'd0;
            transposed_0 <= 64'd0;
            transposed_1 <= 64'd0;
            transposed_2 <= 64'd0;
            transposed_3 <= 64'd0;
            transposed_4 <= 64'd0;
            transposed_5 <= 64'd0;
            transposed_6 <= 64'd0;
            transposed_7 <= 64'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (col_count == num_cols) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_count <= 4'd0;
            col_count <= 4'd0;
            output_row <= 4'd0;
            current_row <= 64'd0;
        end else begin
            case (state)
                LOAD: begin
                    // Store input array
                    for (row_count = 0; row_count < 8; row_count = row_count + 1) begin
                        input_buffer[row_count] = arr[row_count];
                    end
                    row_count <= 4'd0;
                    col_count <= 4'd0;
                    output_row <= 4'd0;
                    current_row <= 64'd0;
                end

                COMPUTE: begin
                    // Build transposed row
                    if (col_count < num_cols) begin
                        current_row = 64'd0;
                        for (row_count = 0; row_count < num_rows; row_count = row_count + 1) begin
                            current_row[(row_count+1)*8-1 : row_count*8] = input_buffer[row_count][col_count*8 +: 8];
                        end
                        col_count <= col_count + 4'd1;
                    end
                end

                OUTPUT: begin
                    // Output results
                    valid <= 1'b1;
                    num_transposed_cols <= num_rows;
                    transposed_0 <= (output_row == 4'd0) ? current_row : transposed_0;
                    transposed_1 <= (output_row == 4'd1) ? current_row : transposed_1;
                    transposed_2 <= (output_row == 4'd2) ? current_row : transposed_2;
                    transposed_3 <= (output_row == 4'd3) ? current_row : transposed_3;
                    transposed_4 <= (output_row == 4'd4) ? current_row : transposed_4;
                    transposed_5 <= (output_row == 4'd5) ? current_row : transposed_5;
                    transposed_6 <= (output_row == 4'd6) ? current_row : transposed_6;
                    transposed_7 <= (output_row == 4'd7) ? current_row : transposed_7;
                    valid <= 1'b0;
                end

                default: begin
                    row_count <= 4'd0;
                    col_count <= 4'd0;
                    output_row <= 4'd0;
                    current_row <= 64'd0;
                end
            endcase
        end
    end

endmodule