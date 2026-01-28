module FindLargestSymmetricSquare (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] matrix_in,
    input wire [4:0] R,
    input wire [4:0] C,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_SIZE = 3'd1;
    localparam [2:0] CHECK_ROW  = 3'd2;
    localparam [2:0] CHECK_COL  = 3'd3;
    localparam [2:0] CHECK_CELL = 3'd4;
    localparam [2:0] FOUND      = 3'd5;
    localparam [2:0] FINISHED   = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] current_S;
    reg [4:0] current_r;
    reg [4:0] current_c;
    reg [4:0] sub_r;
    reg [4:0] sub_c;
    reg [4:0] min_dim;
    
    // Helper signals for index calculation
    wire [7:0] idx1 = (current_r + sub_r) * C + (current_c + sub_c);
    wire [7:0] idx2 = (current_r + (current_S - 1 - sub_r)) * C + (current_c + (current_S - 1 - sub_c));
    wire bit1 = matrix_in[idx1];
    wire bit2 = matrix_in[idx2];
    wire mismatch = (bit1 != bit2);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_SIZE;
                else next_state = IDLE;
            end
            
            CHECK_SIZE: begin
                if (current_S < 4'd2) next_state = FINISHED;
                else next_state = CHECK_ROW;
            end
            
            CHECK_ROW: begin
                if (current_r > (R - current_S)) next_state = CHECK_SIZE;
                else next_state = CHECK_COL;
            end
            
            CHECK_COL: begin
                if (current_c > (C - current_S)) next_state = CHECK_ROW;
                else next_state = CHECK_CELL;
            end
            
            CHECK_CELL: begin
                if (mismatch) next_state = CHECK_COL;
                else if (sub_c >= (current_S - 1 - sub_c)) begin
                    // Checked all columns in current row
                    if (sub_r >= (current_S - 1)) next_state = FOUND;
                    else next_state = CHECK_CELL;
                end else begin
                    next_state = CHECK_CELL;
                end
            end
            
            FOUND: next_state = IDLE;
            FINISHED: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            current_S <= 5'd0;
            current_r <= 5'd0;
            current_c <= 5'd0;
            sub_r <= 5'd0;
            sub_c <= 5'd0;
            min_dim <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize min dimension
                        if (R < C) min_dim <= R;
                        else min_dim <= C;
                    end
                end
                
                CHECK_SIZE: begin
                    current_r <= 5'd0;
                    current_c <= 5'd0;
                    sub_r <= 5'd0;
                    sub_c <= 5'd0;
                    // Start from largest possible size down to 2
                    if (state != next_state) begin
                        if (current_S == 5'd0) current_S <= min_dim;
                        else current_S <= current_S - 5'd1;
                    end
                end
                
                CHECK_ROW: begin
                    current_c <= 5'd0;
                    sub_r <= 5'd0;
                    sub_c <= 5'd0;
                    if (state != next_state) begin
                        current_r <= current_r + 5'd1;
                    end
                end
                
                CHECK_COL: begin
                    sub_r <= 5'd0;
                    sub_c <= 5'd0;
                    if (state != next_state) begin
                        current_c <= current_c + 5'd1;
                    end
                end
                
                CHECK_CELL: begin
                    if (state != next_state) begin
                        if (mismatch) begin
                            // Mismatch found, move to next column
                            // Reset for next candidate
                            sub_r <= 5'd0;
                            sub_c <= 5'd0;
                        end else begin
                            // Check if we need to move to next cell
                            if (sub_c < (current_S - 1 - sub_c)) begin
                                // Move to next column in same row
                                sub_c <= sub_c + 5'd1;
                            end else if (sub_r < (current_S - 1)) begin
                                // Move to next row
                                sub_r <= sub_r + 5'd1;
                                sub_c <= 5'd0;
                            end
                        end
                    end
                end
                
                FOUND: begin
                    result <= current_S;
                    done <= 1'b1;
                end
                
                FINISHED: begin
                    result <= 5'd0; // No symmetric square found
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule