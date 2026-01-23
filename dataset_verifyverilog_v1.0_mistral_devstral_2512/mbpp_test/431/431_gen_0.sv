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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Combinational comparison logic
    wire [63:0] pair_matches;
    wire all_matches_or;
    
    integer i, j;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                pair_matches[i*8 + j] = (i <= len1) && (j <= len2) && (list1[i] == list2[j]);
            end
        end
        all_matches_or = |pair_matches;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            has_common <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result_reg <= all_matches_or;
                    
                    if (cycle_count >= 8'd1 || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    has_common <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    has_common <= 1'b0;
                end
            endcase
        end
    end

endmodule