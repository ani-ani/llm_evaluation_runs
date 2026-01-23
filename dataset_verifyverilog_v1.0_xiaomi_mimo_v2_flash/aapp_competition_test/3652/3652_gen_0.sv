module min_deletions #(
    parameter N = 8,
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 3
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] row1 [0:N-1],
    input [DATA_WIDTH-1:0] row2 [0:N-1],
    input [DATA_WIDTH-1:0] row3 [0:N-1],
    output reg [DATA_WIDTH-1:0] deletions,
    output reg done
);
    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_POS = 3'd1;
    localparam [2:0] ITERATE_MASKS = 3'd2;
    localparam [2:0] CHECK_SUBSET = 3'd3;
    localparam [2:0] CHECK_ROW2 = 3'd4;
    localparam [2:0] CHECK_ROW3 = 3'd5;
    localparam [2:0] UPDATE_RESULT = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;
    
    reg [2:0] state;
    reg [DATA_WIDTH-1:0] pos [0:N-1];  // pos[value-1] = column index
    reg [N-1:0] mask;                  // current subset mask
    reg [DATA_WIDTH-1:0] i;            // loop variable
    reg [DATA_WIDTH-1:0] max_size;
    reg [DATA_WIDTH-1:0] current_size;
    reg valid;
    reg [DATA_WIDTH-1:0] val2;
    reg [DATA_WIDTH-1:0] val3;
    reg seen2 [0:N-1];                 // seen values in row2 (indexed by value-1)
    reg seen3 [0:N-1];                 // seen values in row3
    reg [DATA_WIDTH-1:0] total_masks;
    reg check_done;
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            deletions <= 0;
            max_size <= 0;
            mask <= 0;
            i <= 0;
            valid <= 1'b1;
            current_size <= 0;
            val2 <= 0;
            val3 <= 0;
            check_done <= 1'b0;
            total_masks <= 0;
            for (k = 0; k < N; k = k + 1) begin
                pos[k] <= 0;
                seen2[k] <= 1'b0;
                seen3[k] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_POS;
                        i <= 0;
                    end
                end
                
                COMPUTE_POS: begin
                    // Compute inverse mapping: for each column i, set pos[row1[i]-1] = i
                    if (i < N) begin
                        pos[row1[i]-1] <= i;
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        mask <= 0;
                        max_size <= 0;
                        total_masks <= 0;
                        state <= ITERATE_MASKS;
                    end
                end
                
                ITERATE_MASKS: begin
                    if (mask < (1 << N)) begin
                        // Initialize for checking this mask
                        i <= 0;
                        valid <= 1'b1;
                        current_size <= 0;
                        for (k = 0; k < N; k = k + 1) begin
                            seen2[k] <= 1'b0;
                            seen3[k] <= 1'b0;
                        end
                        state <= CHECK_SUBSET;
                    end else begin
                        deletions <= N - max_size;
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_SUBSET: begin
                    if (i < N) begin
                        if (mask[i]) begin
                            current_size <= current_size + 1;
                            val2 <= row2[i];
                            val3 <= row3[i];
                            state <= CHECK_ROW2;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        if (valid) begin
                            state <= UPDATE_RESULT;
                        end else begin
                            mask <= mask + 1;
                            total_masks <= total_masks + 1;
                            state <= ITERATE_MASKS;
                        end
                    end
                end
                
                CHECK_ROW2: begin
                    // Check closure: pos[val2-1] must be in mask
                    if (!mask[pos[val2-1]]) begin
                        valid <= 1'b0;
                    end
                    // Check distinctness in row2
                    if (seen2[val2-1]) begin
                        valid <= 1'b0;
                    end else begin
                        seen2[val2-1] <= 1'b1;
                    end
                    state <= CHECK_ROW3;
                end
                
                CHECK_ROW3: begin
                    // Check closure: pos[val3-1] must be in mask
                    if (!mask[pos[val3-1]]) begin
                        valid <= 1'b0;
                    end
                    // Check distinctness in row3
                    if (seen3[val3-1]) begin
                        valid <= 1'b0;
                    end else begin
                        seen3[val3-1] <= 1'b1;
                    end
                    i <= i + 1;
                    state <= CHECK_SUBSET;
                end
                
                UPDATE_RESULT: begin
                    if (current_size > max_size) begin
                        max_size <= current_size;
                    end
                    mask <= mask + 1;
                    total_masks <= total_masks + 1;
                    state <= ITERATE_MASKS;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule