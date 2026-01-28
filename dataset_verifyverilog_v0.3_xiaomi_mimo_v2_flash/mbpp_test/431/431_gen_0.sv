module common_element_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] list1 [0:7],
    input wire [7:0] list2 [0:7],
    input wire [2:0] len1,
    input wire [2:0] len2,
    output reg has_common,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPARE = 2'b01;
    localparam [1:0] DONE = 2'b10;
    
    reg [1:0] state;
    
    // Combinational comparison logic
    wire [63:0] pair_matches;  // 8x8 grid of comparison results
    wire all_matches_or;
    
    integer i;
    integer j;
    
    // Generate comparison results for all pairs
    generate
        genvar gi, gj;
        for (gi = 0; gi < 8; gi = gi + 1) begin : compare_rows
            for (gj = 0; gj < 8; gj = gj + 1) begin : compare_cols
                assign pair_matches[gi*8 + gj] = (gi <= len1) && (gj <= len2) && 
                                                   (list1[gi] == list2[gj]);
            end
        end
    endgenerate
    
    // OR reduce all comparison results
    assign all_matches_or = |pair_matches;
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            has_common <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    has_common <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    has_common <= all_matches_or;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    has_common <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule