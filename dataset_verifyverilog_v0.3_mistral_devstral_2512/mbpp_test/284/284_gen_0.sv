module ArrayMatchChecker(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] element,
    input [3:0] len,
    output reg result,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [7:0] i;
    reg all_match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 8'd0;
            all_match <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        i <= 8'd0;
                        all_match <= 1'b1;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i < len) begin
                        if (arr[i] != element) begin
                            all_match <= 1'b0;
                        end
                        i <= i + 8'd1;
                    end
                    
                    if (i >= len || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= all_match;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule