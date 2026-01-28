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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_POS = 2'd1;
    localparam [1:0] ITERATE_MASKS = 2'd2;
    localparam [1:0] CHECK_SUBSET = 2'd3;
    
    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] i;
    reg [ADDR_WIDTH-1:0] j;
    reg [ADDR_WIDTH-1:0] k;
    reg [N-1:0] mask;
    reg [DATA_WIDTH-1:0] pos [0:N-1];
    reg [DATA_WIDTH-1:0] max_size;
    reg [DATA_WIDTH-1:0] current_size;
    reg valid;
    reg [1:0] check_stage;
    reg seen2 [0:N-1];
    reg seen3 [0:N-1];
    reg [DATA_WIDTH-1:0] val2;
    reg [DATA_WIDTH-1:0] val3;
    reg [DATA_WIDTH-1:0] pos_val2;
    reg [DATA_WIDTH-1:0] pos_val3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            deletions <= {DATA_WIDTH{1'b0}};
            max_size <= {DATA_WIDTH{1'b0}};
            mask <= {N{1'b0}};
            i <= {ADDR_WIDTH{1'b0}};
            j <= {ADDR_WIDTH{1'b0}};
            k <= {ADDR_WIDTH{1'b0}};
            current_size <= {DATA_WIDTH{1'b0}};
            valid <= 1'b1;
            check_stage <= 2'd0;
            for (k = 0; k < N; k = k + 1) begin
                pos[k] <= {DATA_WIDTH{1'b0}};
                seen2[k] <= 1'b0;
                seen3[k] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_POS;
                        i <= {ADDR_WIDTH{1'b0}};
                    end
                end
                
                COMPUTE_POS: begin
                    pos[row1[i]-1] <= i;
                    if (i < N-1) begin
                        i <= i + 1;
                    end else begin
                        i <= {ADDR_WIDTH{1'b0}};
                        mask <= {N{1'b0}};
                        max_size <= {DATA_WIDTH{1'b0}};
                        state <= ITERATE_MASKS;
                    end
                end
                
                ITERATE_MASKS: begin
                    if (mask < (1 << N)) begin
                        i <= {ADDR_WIDTH{1'b0}};
                        valid <= 1'b1;
                        current_size <= {DATA_WIDTH{1'b0}};
                        for (k = 0; k < N; k = k + 1) begin
                            seen2[k] <= 1'b0;
                            seen3[k] <= 1'b0;
                        end
                        check_stage <= 2'd0;
                        state <= CHECK_SUBSET;
                    end else begin
                        deletions <= N - max_size;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                CHECK_SUBSET: begin
                    case (check_stage)
                        2'd0: begin
                            if (i < N) begin
                                if (mask[i]) begin
                                    current_size <= current_size + 1;
                                    val2 <= row2[i];
                                    val3 <= row3[i];
                                    check_stage <= 2'd1;
                                end else begin
                                    i <= i + 1;
                                end
                            end else begin
                                if (valid && (current_size > max_size)) begin
                                    max_size <= current_size;
                                end
                                mask <= mask + 1;
                                state <= ITERATE_MASKS;
                            end
                        end
                        
                        2'd1: begin
                            pos_val2 <= pos[val2-1];
                            pos_val3 <= pos[val3-1];
                            if (!mask[pos_val2] || !mask[pos_val3]) begin
                                valid <= 1'b0;
                            end
                            if (seen2[val2-1]) begin
                                valid <= 1'b0;
                            end else begin
                                seen2[val2-1] <= 1'b1;
                            end
                            if (seen3[val3-1]) begin
                                valid <= 1'b0;
                            end else begin
                                seen3[val3-1] <= 1'b1;
                            end
                            i <= i + 1;
                            check_stage <= 2'd0;
                        end
                        
                        default: check_stage <= 2'd0;
                    endcase
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule