module check_array_match (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] element,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg match_flag;
    reg start_dly;
    
    // Combinational comparison logic for each element
    wire match_0, match_1, match_2, match_3;
    wire match_4, match_5, match_6, match_7;
    wire all_match;
    
    assign match_0 = (arr[0] == element) & (len > 4'd0);
    assign match_1 = (arr[1] == element) & (len > 4'd1);
    assign match_2 = (arr[2] == element) & (len > 4'd2);
    assign match_3 = (arr[3] == element) & (len > 4'd3);
    assign match_4 = (arr[4] == element) & (len > 4'd4);
    assign match_5 = (arr[5] == element) & (len > 4'd5);
    assign match_6 = (arr[6] == element) & (len > 4'd6);
    assign match_7 = (arr[7] == element) & (len > 4'd7);
    
    // OR tree for all matching
    assign all_match = match_0 & match_1 & match_2 & match_3 &
                      match_4 & match_5 & match_6 & match_7;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPARE : IDLE;
            COMPARE: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            match_flag <= 1'b0;
            start_dly <= 1'b0;
        end else begin
            state <= next_state;
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        match_flag <= all_match;
                    end
                end
                COMPARE: begin
                    // Just transition to finish
                end
                FINISH: begin
                    result <= match_flag;
                    done <= 1'b1;
                end
                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    match_flag <= 1'b0;
                end
            endcase
        end
    end

endmodule