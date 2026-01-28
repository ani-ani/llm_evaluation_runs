module interesting_problemset(
    input clk,
    input rst_n,
    input start,
    input [3:0] prob_type,
    input valid_in,
    input finish_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INPUT = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [15:0] exists;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;
    
    integer i;
    integer j;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                exists[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INPUT;
                    end
                end
                
                INPUT: begin
                    if (valid_in) begin
                        exists[prob_type] <= 1'b1;
                    end
                    if (finish_in) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    found = 1'b0;
                    
                    // Check for type 0000
                    if (exists[4'd0]) begin
                        found = 1'b1;
                    end
                    
                    // Check all pairs
                    for (i = 1; i < 16; i = i + 1) begin
                        if (exists[i]) begin
                            for (j = i + 1; j < 16; j = j + 1) begin
                                if (exists[j] && (i & j) == 4'd0) begin
                                    found = 1'b1;
                                end
                            end
                        end
                    end
                    
                    result <= found;
                    
                    if (found || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule